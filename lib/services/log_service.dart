import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/sms_log_entry.dart';

/// Persists the rolling log of forwarded SMS in SharedPreferences.
///
/// Every method calls `prefs.reload()` first because these entries are written
/// from multiple isolates (UI, SMS background handler, foreground service).
class LogService {
  static const int maxEntries = 50;

  static Future<List<SmsLogEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return SmsLogEntry.decodeList(prefs.getString(PrefKeys.logEntries));
  }

  /// Insert a new entry at the top, trimmed to [maxEntries].
  static Future<void> add(SmsLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final entries = SmsLogEntry.decodeList(prefs.getString(PrefKeys.logEntries));
    entries.insert(0, entry);
    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }
    await prefs.setString(PrefKeys.logEntries, SmsLogEntry.encodeList(entries));
  }

  /// Update the status/error of an existing entry (matched by id).
  static Future<void> update(
    String id, {
    required DeliveryStatus status,
    String? error,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final entries = SmsLogEntry.decodeList(prefs.getString(PrefKeys.logEntries));
    for (final e in entries) {
      if (e.id == id) {
        e.status = status;
        e.error = error;
        break;
      }
    }
    await prefs.setString(PrefKeys.logEntries, SmsLogEntry.encodeList(entries));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefKeys.logEntries);
  }
}
