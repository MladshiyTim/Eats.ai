import '../models/daily_log.dart';
import 'api_client.dart';

/// Manages daily health log entries via /daily-log/.
class LogService {
  final ApiClient _client = ApiClient.instance;

  /// Returns all daily logs (sorted by date descending, last 30 days).
  Future<List<DailyLog>> listLogs() async {
    final data = await _client.get('/daily-log/') as List<dynamic>;
    return data
        .map((item) => DailyLog.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Returns the log for a specific date string ('YYYY-MM-DD'), or null.
  Future<DailyLog?> getLogForDate(String date) async {
    try {
      final data = await _client.get('/daily-log/$date/') as Map<String, dynamic>;
      return DailyLog.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Creates a new daily log entry.
  Future<DailyLog> createLog(DailyLog log) async {
    final data =
        await _client.post('/daily-log/', log.toJson()) as Map<String, dynamic>;
    return DailyLog.fromJson(data);
  }

  /// Updates an existing log by id.
  Future<DailyLog> updateLog(int id, DailyLog log) async {
    final data =
        await _client.patch('/daily-log/$id/', log.toJson()) as Map<String, dynamic>;
    return DailyLog.fromJson(data);
  }

  /// Creates a log entry or updates it if it already exists for that date.
  Future<DailyLog> upsertLog(DailyLog log) async {
    final existing = await getLogForDate(log.date);
    if (existing != null && existing.id != null) {
      return updateLog(existing.id!, log);
    }
    return createLog(log);
  }

  /// Deletes a log entry.
  Future<void> deleteLog(int id) async {
    await _client.delete('/daily-log/$id/');
  }

  /// Returns today's log, or null if not yet recorded.
  Future<DailyLog?> getTodayLog() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return getLogForDate(dateStr);
  }
}
