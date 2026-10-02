import 'dart:async';

import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:phone_state/phone_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/sms_log_entry.dart';
import 'sms_handler.dart';

/// Detects incoming/missed calls and forwards them to email.
///
/// Strategy (robust across OEM background limits):
///   * The foreground service polls the call log every ~60s (reliable).
///   * `phone_state` fires a near-instant sync right after a call ends,
///     for low latency while the app/service process is alive.
///
/// We read the device call log (READ_CALL_LOG) which gives the full picture:
/// number, contact name, type (missed / answered / rejected / ...), duration
/// and timestamp. A stored "last forwarded" pointer ensures each call is
/// emailed exactly once and that we never blast the entire history.
class CallProcessor {
  /// Call types we do NOT forward (you initiated these yourself).
  static const _skip = {'outgoing', 'wifiOutgoing'};

  /// Map call_log's CallType enum to a stable string stored in the log/email.
  static String _typeName(CallType? t) => switch (t) {
        CallType.incoming => 'incoming',
        CallType.outgoing => 'outgoing',
        CallType.missed => 'missed',
        CallType.rejected => 'rejected',
        CallType.blocked => 'blocked',
        CallType.voiceMail => 'voiceMail',
        CallType.wifiIncoming => 'wifiIncoming',
        CallType.wifiOutgoing => 'wifiOutgoing',
        _ => 'unknown',
      };

  /// Seed the pointer to "now" the first time call forwarding is enabled, so we
  /// only forward calls that happen from this moment on (not the whole history).
  static Future<void> initPointerIfUnset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!prefs.containsKey(PrefKeys.lastCallTimestamp)) {
      await prefs.setInt(
          PrefKeys.lastCallTimestamp, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Read the call log for entries newer than the pointer and forward them.
  static Future<void> syncNewCalls() async {
    final settings = await AppSettings.load();
    if (!settings.forwardCalls) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // If the pointer isn't set yet, seed it and bail (nothing to forward).
    if (!prefs.containsKey(PrefKeys.lastCallTimestamp)) {
      await prefs.setInt(
          PrefKeys.lastCallTimestamp, DateTime.now().millisecondsSinceEpoch);
      return;
    }
    final lastTs = prefs.getInt(PrefKeys.lastCallTimestamp)!;

    Iterable<CallLogEntry> entries;
    try {
      // dateFrom is inclusive; +1ms so we don't re-read the boundary call.
      entries = await CallLog.query(dateFrom: lastTs + 1);
    } catch (e) {
      debugPrint('CallLog.query failed (missing READ_CALL_LOG?): $e');
      return;
    }

    // Oldest-first so emails arrive in chronological order.
    final sorted = entries
        .where((e) => e.timestamp != null)
        .toList()
      ..sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
    if (sorted.isEmpty) return;

    var maxTs = lastTs;
    for (final c in sorted) {
      final ts = c.timestamp!;
      if (ts > maxTs) maxTs = ts;

      final type = _typeName(c.callType);
      if (_skip.contains(type)) continue; // skip your own outgoing calls

      final number = (c.number == null || c.number!.isEmpty)
          ? 'Unknown'
          : c.number!;
      final duration = c.duration ?? 0;
      final label = switch (type) {
        'missed' => 'Missed call',
        'rejected' => 'Rejected call',
        'incoming' => 'Answered call · ${_fmtDur(duration)}',
        'voiceMail' => 'Voicemail',
        'blocked' => 'Blocked call',
        _ => 'Call',
      };

      final entry = SmsLogEntry(
        id: 'call_${ts}_$number',
        sender: number,
        body: label,
        timestamp: ts,
        status: DeliveryStatus.queued,
        kind: LogKind.call,
        callType: type,
        durationSec: duration,
        contactName: c.name,
      );
      await SmsProcessor.deliver(entry);
    }

    // Advance the pointer past everything we scanned (incl. skipped outgoing).
    await prefs.setInt(PrefKeys.lastCallTimestamp, maxTs);
  }

  static String _fmtDur(int seconds) =>
      '${seconds ~/ 60}m ${(seconds % 60).toString().padLeft(2, '0')}s';

  // --- phone_state: trigger an immediate sync shortly after a call ends ---
  static StreamSubscription<PhoneState>? _sub;

  /// Subscribe to call-state changes. On CALL_ENDED we wait briefly (the OS
  /// needs a moment to write the call-log row) then sync. Safe to call twice.
  static void startListening() {
    _sub ??= PhoneState.stream.listen((state) async {
      if (state.status == PhoneStateStatus.CALL_ENDED) {
        await Future<void>.delayed(const Duration(seconds: 2));
        await syncNewCalls();
      }
    }, onError: (e) => debugPrint('phone_state error: $e'));
  }

  static Future<void> stopListening() async {
    await _sub?.cancel();
    _sub = null;
  }
}
