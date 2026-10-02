import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../services/queue_service.dart';
import '../services/sms_handler.dart';

/// Entry point for the foreground-service isolate. Must be top-level and
/// annotated `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SmsForegroundTaskHandler());
}

/// The long-lived task. Its main job is to KEEP THE PROCESS ALIVE so OEM
/// task-killers don't stop SMS reception. On each repeat tick it also flushes
/// the retry queue (covers the "connectivity came back" case).
class SmsForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Foreground service started ($starter)');
    // Attempt an immediate flush in case we booted with a backlog.
    await SmsProcessor.flushQueue();
  }

  /// Fires on the repeat interval configured in main.dart (every 60s).
  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    await SmsProcessor.flushQueue();
    final pending = await QueueService.count();
    FlutterForegroundTask.updateService(
      notificationTitle: 'SMS to Gmail — running',
      notificationText: pending == 0
          ? 'Forwarding incoming SMS'
          : '$pending message(s) queued for retry',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('Foreground service destroyed');
  }

  /// Tapping the notification brings the app to the foreground.
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }
}
