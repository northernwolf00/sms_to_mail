import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../services/call_service.dart';
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
    // Low-latency call detection while this isolate is alive.
    CallProcessor.startListening();
    // Catch up on any calls missed while we were down, then flush backlog.
    await CallProcessor.syncNewCalls();
    await SmsProcessor.flushQueue();
  }

  /// Fires on the repeat interval configured in main.dart (every 60s).
  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Reliable fallback: poll the call log every tick in case phone_state
    // didn't fire in the background.
    await CallProcessor.syncNewCalls();
    await SmsProcessor.flushQueue();
    final pending = await QueueService.count();
    FlutterForegroundTask.updateService(
      notificationTitle: 'SMS to Gmail — running',
      notificationText: pending == 0
          ? 'Forwarding incoming SMS & calls'
          : '$pending item(s) queued for retry',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await CallProcessor.stopListening();
    debugPrint('Foreground service destroyed');
  }

  /// Tapping the notification brings the app to the foreground.
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }
}
