import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../models/app_settings.dart';
import '../models/sms_log_entry.dart';

/// Sends email directly to Gmail's SMTP server — no backend involved.
///
/// ============================================================================
/// HOW TO CREATE A GMAIL APP PASSWORD (required — your normal password won't
/// work for SMTP once 2FA is on):
///   1. Enable 2-Step Verification:
///        Google Account > Security > 2-Step Verification  (turn it ON)
///   2. Create an App Password:
///        Google Account > Security > 2-Step Verification > App passwords
///        (or visit https://myaccount.google.com/apppasswords)
///   3. Pick "Mail" / "Other (Custom name)", name it e.g. "SMS Forwarder".
///   4. Google shows a 16-character password (like: abcd efgh ijkl mnop).
///   5. Enter it in this app's Settings screen (spaces are fine/optional).
///
/// SECURITY NOTE: this App Password is stored on-device (SharedPreferences) and
/// sent straight to smtp.gmail.com. That is acceptable ONLY for a personal,
/// sideloaded build on your own phone. Never distribute the app with this
/// design. Revoke the App Password any time from the same Google page.
/// ============================================================================
class EmailService {
  /// Builds the Gmail SMTP server config: smtp.gmail.com:587 over STARTTLS.
  static SmtpServer _server(AppSettings s) {
    return SmtpServer(
      'smtp.gmail.com',
      port: 587, // STARTTLS submission port
      username: s.gmailAddress.trim(),
      password: s.appPassword.replaceAll(' ', ''), // strip display spaces
      ssl: false, // port 587 upgrades via STARTTLS, not implicit SSL
      allowInsecure: false,
    );
  }

  static final _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  /// Human-readable label for a raw call-type string.
  static String callTypeLabel(String? type) => switch (type) {
        'missed' => 'Missed',
        'incoming' => 'Incoming (answered)',
        'rejected' => 'Rejected',
        'outgoing' => 'Outgoing',
        'blocked' => 'Blocked',
        'voiceMail' => 'Voicemail',
        'wifiIncoming' => 'Incoming (Wi-Fi)',
        'wifiOutgoing' => 'Outgoing (Wi-Fi)',
        _ => 'Unknown',
      };

  /// Composes the subject + body for a log entry (SMS or call).
  static ({String subject, String text}) _compose(SmsLogEntry e) {
    final time = _fmt.format(e.receivedAt);

    if (e.isCall) {
      final who = (e.contactName != null && e.contactName!.isNotEmpty)
          ? '${e.contactName} (${e.sender})'
          : e.sender;
      final typeLabel = callTypeLabel(e.callType);
      final subject = switch (e.callType) {
        'missed' => 'Missed call from $who',
        'rejected' => 'Rejected call from $who',
        'incoming' => 'Incoming call from $who',
        _ => '$typeLabel call from $who',
      };
      final lines = <String>[
        'Number: ${e.sender}',
        if (e.contactName != null && e.contactName!.isNotEmpty)
          'Name: ${e.contactName}',
        'Time: $time',
        'Type: $typeLabel',
        'Duration: ${_formatDuration(e.durationSec ?? 0)}',
      ];
      return (subject: subject, text: lines.join('\n'));
    }

    // SMS
    return (
      subject: 'New SMS from ${e.sender}',
      text: 'From: ${e.sender}\n'
          'Time: $time\n'
          'Message:\n'
          '${e.body}',
    );
  }

  /// Sends the email for a log entry (SMS or call).
  /// Throws [MailerException] on failure.
  static Future<void> sendEntry(AppSettings settings, SmsLogEntry entry) async {
    final c = _compose(entry);
    final message = Message()
      ..from = Address(settings.gmailAddress.trim(), 'SMS Forwarder')
      ..recipients.add(settings.recipient.trim())
      ..subject = c.subject
      ..text = c.text;
    await send(message, _server(settings));
  }

  /// Sends a quick test email to verify SMTP config from the Settings screen.
  static Future<void> sendTest(AppSettings settings) async {
    final now = _fmt.format(DateTime.now());
    final message = Message()
      ..from = Address(settings.gmailAddress.trim(), 'SMS Forwarder')
      ..recipients.add(settings.recipient.trim())
      ..subject = 'SMS Forwarder — test email'
      ..text = 'This is a test email from your SMS Forwarder app.\n'
          'If you can read this, SMTP is configured correctly.\n\n'
          'Sent: $now';
    await send(message, _server(settings));
  }
}
