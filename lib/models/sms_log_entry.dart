import 'dart:convert';

/// Delivery status of a forwarded item.
enum DeliveryStatus { sent, queued, failed }

extension DeliveryStatusLabel on DeliveryStatus {
  String get label => switch (this) {
        DeliveryStatus.sent => 'sent',
        DeliveryStatus.queued => 'queued',
        DeliveryStatus.failed => 'failed',
      };
}

/// What kind of event a log entry represents.
enum LogKind { sms, call }

/// One forwarded event (SMS or call) and its delivery outcome. Serialised to
/// JSON and kept in SharedPreferences so the UI, the SMS background isolate,
/// and the foreground-service isolate can all read/write the same history.
class SmsLogEntry {
  /// Stable id used to correlate a log entry with its retry-queue copy.
  final String id;

  /// SMS sender or caller phone number.
  final String sender;

  /// For SMS: the message text. For calls: a human-readable summary line.
  final String body;

  /// Epoch milliseconds the event occurred.
  final int timestamp;

  /// Whether this is an SMS or a call. Defaults to sms for backward-compat.
  final LogKind kind;

  /// Call-only: 'missed' | 'incoming' | 'rejected' | 'outgoing' | ... (null for SMS).
  final String? callType;

  /// Call-only: duration in seconds (0 for missed/rejected). Null for SMS.
  final int? durationSec;

  /// Call-only: contact name if the number is in contacts.
  final String? contactName;

  DeliveryStatus status;

  /// Last error message, if sending failed.
  String? error;

  SmsLogEntry({
    required this.id,
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.status,
    this.kind = LogKind.sms,
    this.callType,
    this.durationSec,
    this.contactName,
    this.error,
  });

  DateTime get receivedAt => DateTime.fromMillisecondsSinceEpoch(timestamp);

  bool get isCall => kind == LogKind.call;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'body': body,
        'timestamp': timestamp,
        'status': status.name,
        'kind': kind.name,
        'callType': callType,
        'durationSec': durationSec,
        'contactName': contactName,
        'error': error,
      };

  factory SmsLogEntry.fromJson(Map<String, dynamic> json) => SmsLogEntry(
        id: json['id'] as String,
        sender: (json['sender'] as String?) ?? 'unknown',
        body: (json['body'] as String?) ?? '',
        timestamp: (json['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        status: DeliveryStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => DeliveryStatus.failed,
        ),
        kind: LogKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => LogKind.sms,
        ),
        callType: json['callType'] as String?,
        durationSec: (json['durationSec'] as num?)?.toInt(),
        contactName: json['contactName'] as String?,
        error: json['error'] as String?,
      );

  static String encodeList(List<SmsLogEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<SmsLogEntry> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SmsLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
