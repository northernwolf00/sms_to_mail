import 'dart:convert';

/// Delivery status of a forwarded SMS.
enum DeliveryStatus { sent, queued, failed }

extension DeliveryStatusLabel on DeliveryStatus {
  String get label => switch (this) {
        DeliveryStatus.sent => 'sent',
        DeliveryStatus.queued => 'queued',
        DeliveryStatus.failed => 'failed',
      };
}

/// One forwarded SMS and its delivery outcome. Serialised to JSON and kept
/// in SharedPreferences so the UI, the SMS background isolate, and the
/// foreground-service isolate can all read/write the same history.
class SmsLogEntry {
  /// Stable id used to correlate a log entry with its retry-queue copy.
  final String id;
  final String sender;
  final String body;

  /// Epoch milliseconds the SMS was received.
  final int timestamp;

  DeliveryStatus status;

  /// Last error message, if sending failed.
  String? error;

  SmsLogEntry({
    required this.id,
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.status,
    this.error,
  });

  DateTime get receivedAt => DateTime.fromMillisecondsSinceEpoch(timestamp);

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'body': body,
        'timestamp': timestamp,
        'status': status.name,
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
