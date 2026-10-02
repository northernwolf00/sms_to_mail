import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/sms_log_entry.dart';

/// Holds SMS that could not be emailed yet (offline / SMTP error) so they can
/// be retried later. Backed by SharedPreferences; safe across isolates.
class QueueService {
  static Future<List<SmsLogEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return SmsLogEntry.decodeList(prefs.getString(PrefKeys.queueEntries));
  }

  static Future<void> enqueue(SmsLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final entries =
        SmsLogEntry.decodeList(prefs.getString(PrefKeys.queueEntries));
    // De-dupe by id in case of a retry that re-queues.
    entries.removeWhere((e) => e.id == entry.id);
    entries.add(entry);
    await prefs.setString(
        PrefKeys.queueEntries, SmsLogEntry.encodeList(entries));
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final entries =
        SmsLogEntry.decodeList(prefs.getString(PrefKeys.queueEntries));
    entries.removeWhere((e) => e.id == id);
    await prefs.setString(
        PrefKeys.queueEntries, SmsLogEntry.encodeList(entries));
  }

  static Future<int> count() async => (await getAll()).length;
}
