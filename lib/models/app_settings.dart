import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys. Kept in one place so the UI isolate, the SMS
/// background isolate, and the foreground-service isolate all agree.
class PrefKeys {
  static const gmailAddress = 'gmail_address';
  static const appPassword = 'app_password';
  static const recipient = 'recipient_email';
  static const serviceEnabled = 'service_enabled';
  static const forwardSms = 'forward_sms';
  static const forwardCalls = 'forward_calls';
  static const logEntries = 'log_entries';
  static const queueEntries = 'queue_entries';

  /// Pointer: epoch-ms of the newest call already forwarded. Managed by
  /// CallService so we only email calls that happen after forwarding is on.
  static const lastCallTimestamp = 'last_call_timestamp';
}

/// User-entered configuration. Stored in SharedPreferences (NOT hardcoded).
///
/// SECURITY NOTE: the Gmail App Password is stored in plain SharedPreferences
/// on this device only. That is acceptable ONLY for a personal, self-built,
/// sideloaded app that you install on your own phone. Do not ship this to
/// other people or to the Play Store with credentials handled this way.
class AppSettings {
  final String gmailAddress;
  final String appPassword;
  final String recipient;
  final bool serviceEnabled;

  /// Forward incoming SMS to email.
  final bool forwardSms;

  /// Forward incoming/missed calls to email.
  final bool forwardCalls;

  const AppSettings({
    required this.gmailAddress,
    required this.appPassword,
    required this.recipient,
    required this.serviceEnabled,
    this.forwardSms = true,
    this.forwardCalls = true,
  });

  /// Everything needed to actually send mail is present.
  bool get isValid =>
      gmailAddress.trim().isNotEmpty &&
      appPassword.trim().isNotEmpty &&
      recipient.trim().isNotEmpty;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    // reload() is important: another isolate may have written newer values.
    await prefs.reload();
    return AppSettings.fromPrefs(prefs);
  }

  factory AppSettings.fromPrefs(SharedPreferences prefs) {
    return AppSettings(
      gmailAddress: prefs.getString(PrefKeys.gmailAddress) ?? '',
      appPassword: prefs.getString(PrefKeys.appPassword) ?? '',
      recipient: prefs.getString(PrefKeys.recipient) ?? '',
      serviceEnabled: prefs.getBool(PrefKeys.serviceEnabled) ?? false,
      forwardSms: prefs.getBool(PrefKeys.forwardSms) ?? true,
      forwardCalls: prefs.getBool(PrefKeys.forwardCalls) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.gmailAddress, gmailAddress.trim());
    await prefs.setString(PrefKeys.appPassword, appPassword.trim());
    await prefs.setString(PrefKeys.recipient, recipient.trim());
    await prefs.setBool(PrefKeys.serviceEnabled, serviceEnabled);
    await prefs.setBool(PrefKeys.forwardSms, forwardSms);
    await prefs.setBool(PrefKeys.forwardCalls, forwardCalls);
  }

  AppSettings copyWith({
    String? gmailAddress,
    String? appPassword,
    String? recipient,
    bool? serviceEnabled,
    bool? forwardSms,
    bool? forwardCalls,
  }) {
    return AppSettings(
      gmailAddress: gmailAddress ?? this.gmailAddress,
      appPassword: appPassword ?? this.appPassword,
      recipient: recipient ?? this.recipient,
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
      forwardSms: forwardSms ?? this.forwardSms,
      forwardCalls: forwardCalls ?? this.forwardCalls,
    );
  }
}
