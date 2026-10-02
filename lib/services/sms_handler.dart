import 'dart:ui';

import 'package:another_telephony/telephony.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../models/app_settings.dart';
import '../models/sms_log_entry.dart';
import 'email_service.dart';
import 'log_service.dart';
import 'queue_service.dart';

/// Core event -> email pipeline, written so it can run from ANY isolate:
///   * the UI isolate,
///   * the `another_telephony` background isolate (incoming SMS while closed),
///   * the `flutter_foreground_task` isolate (periodic call sync + queue retry).
class SmsProcessor {
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    // connectivity_plus 6.x returns a List<ConnectivityResult>.
    return result.isNotEmpty && !result.contains(ConnectivityResult.none);
  }

  /// Shared delivery for any entry (SMS or call): try to email it now,
  /// otherwise queue it. Always records the outcome in the log.
  ///
  /// The entry is expected to already be fully populated (kind, body, etc.).
  static Future<void> deliver(SmsLogEntry entry) async {
    final settings = await AppSettings.load();

    if (!settings.isValid) {
      entry.status = DeliveryStatus.failed;
      entry.error = 'SMTP not configured (open Settings)';
      await LogService.add(entry);
      return;
    }

    if (!await isOnline()) {
      entry.status = DeliveryStatus.queued;
      entry.error = 'Offline — queued for retry';
      await LogService.add(entry);
      await QueueService.enqueue(entry);
      return;
    }

    try {
      await EmailService.sendEntry(settings, entry);
      entry.status = DeliveryStatus.sent;
      entry.error = null;
      await LogService.add(entry);
    } catch (e) {
      entry.status = DeliveryStatus.queued;
      entry.error = 'Send failed, queued: $e';
      await LogService.add(entry);
      await QueueService.enqueue(entry);
    }
  }

  /// Process a freshly received SMS (respecting the forward-SMS toggle).
  static Future<void> handleIncoming({
    required String sender,
    required String body,
    required int timestampMs,
  }) async {
    final settings = await AppSettings.load();
    if (!settings.forwardSms) return; // SMS forwarding disabled

    final entry = SmsLogEntry(
      id: '${timestampMs}_${sender}_${body.hashCode}',
      sender: sender,
      body: body,
      timestamp: timestampMs,
      status: DeliveryStatus.queued,
      kind: LogKind.sms,
    );
    await deliver(entry);
  }

  /// Retry everything in the queue (SMS and calls alike). Called periodically
  /// by the foreground service and once when connectivity returns.
  static Future<void> flushQueue() async {
    final pending = await QueueService.getAll();
    if (pending.isEmpty) return;
    if (!await isOnline()) return;

    final settings = await AppSettings.load();
    if (!settings.isValid) return;

    for (final entry in pending) {
      try {
        await EmailService.sendEntry(settings, entry);
        await QueueService.remove(entry.id);
        await LogService.update(entry.id, status: DeliveryStatus.sent);
      } catch (e) {
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
  // CRITICAL: another_telephony starts this isolate with a bare FlutterEngine
  // that has NO plugins registered. Without these two calls, shared_preferences
  // and connectivity_plus throw MissingPluginException here and the SMS is
  // silently dropped whenever the app is closed/swiped. These register the
  // Dart-side plugins for this background isolate.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    await SmsProcessor.handleIncoming(
      sender: message.address ?? 'unknown',
      body: message.body ?? '',
      timestampMs: message.date ?? DateTime.now().millisecondsSinceEpoch,
    );
  } catch (e) {
    debugPrint('backgroundMessageHandler error: $e');
  }
}
