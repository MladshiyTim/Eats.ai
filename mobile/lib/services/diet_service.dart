import '../models/diet_plan.dart';
import '../models/daily_status.dart';
import 'api_client.dart';

/// Manages diet plan retrieval and AI generation.
class DietService {
  final ApiClient _client = ApiClient.instance;

  /// Returns the active (most recent ready) diet plan, or null if none exists.
  Future<DietPlan?> getActivePlan() async {
    try {
      final data = await _client.get('/diet-plan/active/');
      if (data == null) return null;
      return DietPlan.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Returns a list of all diet plans for the current user.
  Future<List<DietPlan>> listPlans() async {
    final data = await _client.get('/diet-plan/history/') as List<dynamic>;
    return data
        .map((item) => DietPlan.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Triggers AI plan generation.
  /// [durationDays] — number of days (10, 14, 21, 30, or custom).
  Future<DietPlan> generatePlan(int durationDays) async {
    final data = await _client.post('/diet-plan/generate/', {
      'duration_days': durationDays,
    }) as Map<String, dynamic>;
    return DietPlan.fromJson(data);
  }

  /// Fetches a specific plan by id.
  Future<DietPlan> getPlan(int id) async {
    final plans = await listPlans();
    return plans.firstWhere((plan) => plan.id == id);
  }

  /// Confirms (accepts) the active plan; strict daily enforcement begins.
  Future<DietPlan> confirmPlan({int? wakeHour, int? sleepHour}) async {
    final body = <String, dynamic>{};
    if (wakeHour != null) body['wake_hour'] = wakeHour;
    if (sleepHour != null) body['sleep_hour'] = sleepHour;
    final data = await _client.post('/diet-plan/confirm/', body)
        as Map<String, dynamic>;
    return DietPlan.fromJson(data);
  }

  /// Fetches today's enforcement status (drives the hard-forcing gate).
  Future<DailyStatus> getDailyStatus() async {
    final data = await _client.get('/daily-status/') as Map<String, dynamic>;
    return DailyStatus.fromJson(data);
  }

  /// Fetches weekly stats summary from the backend.
  Future<Map<String, dynamic>> getWeeklyStats() async {
    try {
      final data = await _client.get('/stats/');
      if (data == null) return {};
      return data as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return {};
      rethrow;
    }
  }
}
