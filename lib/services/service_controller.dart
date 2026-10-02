import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../foreground/foreground_task_handler.dart';
import 'sms_handler.dart';

/// Starts/stops the foreground service and wires up the SMS listener.
class ServiceController {
  static final Telephony _telephony = Telephony.instance;

  /// Call once at app startup (after permissions) to register the incoming-SMS
  /// listener with its background handler. Registering `onBackgroundMessage`
  /// is what lets SMS be processed while the app is closed.
  static void registerSmsListener() {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        // Foreground path (app is open). Reuse the same pipeline.
        SmsProcessor.handleIncoming(
          sender: message.address ?? 'unknown',
          body: message.body ?? '',
          timestampMs: message.date ?? DateTime.now().millisecondsSinceEpoch,
        );
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
  }

  /// Configure the foreground task. Call once before starting the service.
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sms_forwarder_service',
        channelName: 'SMS Forwarder Service',
        channelDescription: 'Keeps SMS forwarding alive in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Flush the retry queue once a minute.
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true, // restart service after device reboot
        autoRunOnMyPackageReplaced: true, // restart after app update
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> get isRunning =>
      FlutterForegroundTask.isRunningService;

  static Future<void> start() async {
    if (await isRunning) return;
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'SMS to Gmail — running',
      notificationText: 'Forwarding incoming SMS',
      callback: startCallback,
    );
    debugPrint('Service start requested');
  }

  static Future<void> stop() async {
    if (!await isRunning) return;
    await FlutterForegroundTask.stopService();
    debugPrint('Service stop requested');
  }
}
