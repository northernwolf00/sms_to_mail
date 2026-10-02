import 'package:another_telephony/telephony.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/sms_log_entry.dart';
import 'email_service.dart';
import 'log_service.dart';
import 'queue_service.dart';

/// Core SMS -> email pipeline, written so it can run from ANY isolate:
///   * the UI isolate (not typical),
///   * the `another_telephony` background isolate (incoming SMS while closed),
///   * the `flutter_foreground_task` isolate (periodic queue retry).
class SmsProcessor {
  static Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    // connectivity_plus 6.x returns a List<ConnectivityResult>.
    return !result.contains(ConnectivityResult.none) && result.isNotEmpty;
  }

  /// Process a freshly received SMS: try to email it now, otherwise queue it.
  /// Always records the outcome in the log.
  static Future<void> handleIncoming({
    required String sender,
    required String body,
    required int timestampMs,
  }) async {
    final id = '${timestampMs}_${sender}_${body.hashCode}';
    final entry = SmsLogEntry(
      id: id,
      sender: sender,
      body: body,
      timestamp: timestampMs,
      status: DeliveryStatus.queued,
    );

    final settings = await AppSettings.load();

    if (!settings.isValid) {
      entry.status = DeliveryStatus.failed;
      entry.error = 'SMTP not configured (open Settings)';
      await LogService.add(entry);
      return;
    }

    final online = await _isOnline();
    if (!online) {
      entry.status = DeliveryStatus.queued;
      entry.error = 'Offline — queued for retry';
      await LogService.add(entry);
      await QueueService.enqueue(entry);
      return;
    }

    try {
      await EmailService.sendSms(
        settings,
        sender: sender,
        body: body,
        timestampMs: timestampMs,
      );
      entry.status = DeliveryStatus.sent;
      entry.error = null;
      await LogService.add(entry);
    } catch (e) {
      // SMTP error — keep it for retry.
      entry.status = DeliveryStatus.queued;
      entry.error = 'Send failed, queued: $e';
      await LogService.add(entry);
      await QueueService.enqueue(entry);
    }
  }

  /// Retry everything in the queue. Called periodically by the foreground
  /// service and once when connectivity returns. Safe to call often.
  static Future<void> flushQueue() async {
    final pending = await QueueService.getAll();
    if (pending.isEmpty) return;

    if (!await _isOnline()) return;

    final settings = await AppSettings.load();
    if (!settings.isValid) return;

    for (final entry in pending) {
      try {
        await EmailService.sendSms(
          settings,
          sender: entry.sender,
          body: entry.body,
          timestampMs: entry.timestamp,
        );
        await QueueService.remove(entry.id);
        await LogService.update(entry.id, status: DeliveryStatus.sent);
      } catch (e) {
        // Still failing — leave in queue, try again next tick.
        await LogService.update(
          entry.id,
          status: DeliveryStatus.queued,
          error: 'Retry failed: $e',
        );
      }
    }
  }
}

/// ===========================================================================
/// TOP-LEVEL background message handler for `another_telephony`.
///
/// This MUST be a top-level (or static) function annotated with
/// `@pragma('vm:entry-point')` so the Android broadcast receiver can spin up a
/// background Dart isolate and invoke it even when the app is closed/swiped.
/// ===========================================================================
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  try {
    await SmsProcessor.handleIncoming(
      sender: message.address ?? 'unknown',
      body: message.body ?? '',
      // message.date is epoch millis; fall back to "now" if absent.
      timestampMs: message.date ?? DateTime.now().millisecondsSinceEpoch,
    );
  } catch (e) {
    debugPrint('backgroundMessageHandler error: $e');
  }
}
