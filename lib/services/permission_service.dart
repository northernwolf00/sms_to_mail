import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests all runtime permissions the app needs. Call from a rationale
/// dialog on first launch.
class PermissionService {
  /// Returns true if SMS reception permissions are granted.
  static Future<bool> requestAll() async {
    // 1) SMS (RECEIVE_SMS + READ_SMS).
    final sms = await [
      Permission.sms,
    ].request();

    // 2) Notifications (Android 13+) — required so the foreground-service
    //    notification can show. Use the plugin's helper which handles the
    //    platform-channel plumbing.
    await FlutterForegroundTask.requestNotificationPermission();

    // 3) Ask the OS to exempt us from battery optimization. On many OEMs this
    //    is the single most important setting for background reliability.
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    return sms[Permission.sms]?.isGranted ?? false;
  }

  static Future<bool> get smsGranted async =>
      await Permission.sms.isGranted;
}
