import '../models/food_log.dart';
import 'api_client.dart';

/// Result of analyzing a food photo.
class FoodAnalysisResult {
  final FoodLog foodLog;
  final int caloriesConsumedToday;

  const FoodAnalysisResult({
    required this.foodLog,
    required this.caloriesConsumedToday,
  });
}

/// Handles food-photo calorie logging.
class FoodService {
  final ApiClient _client = ApiClient.instance;

  /// Uploads a food photo; the backend recognizes it via Gemini Vision,
  /// stores a [FoodLog], and rolls its calories into today's total.
  /// Throws [ApiException] (with a friendly message) if no food is detected.
  Future<FoodAnalysisResult> analyzePhoto(
    String filePath, {
    String mealType = 'snack',
  }) async {
    final data = await _client.postMultipartFile(
      '/food-log/analyze/',
      filePath: filePath,
      fileField: 'image',
      fields: {'meal_type': mealType},
    ) as Map<String, dynamic>;

    return FoodAnalysisResult(
      foodLog: FoodLog.fromJson(data['food_log'] as Map<String, dynamic>),
      caloriesConsumedToday: (data['calories_consumed_today'] as num?)?.toInt() ?? 0,
    );
  }

  /// Lists food logs, optionally for a specific date (YYYY-MM-DD).
  Future<List<FoodLog>> listFoodLogs({String? date}) async {
    final path = date != null ? '/food-log/?date=$date' : '/food-log/';
    final data = await _client.get(path) as List<dynamic>;
    return data
        .map((e) => FoodLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Deletes a food log entry (subtracts its calories from the day total).
  Future<void> deleteFoodLog(int id) async {
    await _client.delete('/food-log/$id/');
  }
}
