/// Daily enforcement status returned by GET /daily-status/.
/// Drives the "hard-forcing" gate: when [locked] is true the user must
/// complete [actionsRequired] before they can use the app freely.
class DailyStatus {
  final bool hasPlan;
  final bool planConfirmed;
  final bool locked;
  final List<String> actionsRequired;
  final int streak;
  final double targetCalories;
  final double targetWaterLiters;
  final int caloriesConsumed;
  final int caloriesRemaining;
  final double waterLiters;
  final double waterRemainingLiters;
  final bool mealsFollowed;
  final bool workoutDone;
  final String message;

  const DailyStatus({
    required this.hasPlan,
    required this.planConfirmed,
    required this.locked,
    this.actionsRequired = const [],
    this.streak = 0,
    this.targetCalories = 0,
    this.targetWaterLiters = 0,
    this.caloriesConsumed = 0,
    this.caloriesRemaining = 0,
    this.waterLiters = 0,
    this.waterRemainingLiters = 0,
    this.mealsFollowed = false,
    this.workoutDone = false,
    this.message = '',
  });

  bool get needsConfirm => actionsRequired.contains('confirm_plan');
  bool get needsFood => actionsRequired.contains('log_food');
  bool get needsWater => actionsRequired.contains('drink_water');
  bool get needsWorkout => actionsRequired.contains('workout');

  factory DailyStatus.fromJson(Map<String, dynamic> json) {
    final targets = (json['targets'] as Map<String, dynamic>?) ?? const {};
    final today = (json['today'] as Map<String, dynamic>?) ?? const {};
    return DailyStatus(
      hasPlan: json['has_plan'] as bool? ?? false,
      planConfirmed: json['plan_confirmed'] as bool? ?? false,
      locked: json['locked'] as bool? ?? false,
      actionsRequired: (json['actions_required'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      streak: _parseInt(json['streak']) ?? 0,
      targetCalories: _parseDouble(targets['calories']) ?? 0,
      targetWaterLiters: _parseDouble(targets['water_liters']) ?? 0,
      caloriesConsumed: _parseInt(today['calories_consumed']) ?? 0,
      caloriesRemaining: _parseInt(today['calories_remaining']) ?? 0,
      waterLiters: _parseDouble(today['water_liters']) ?? 0,
      waterRemainingLiters: _parseDouble(today['water_remaining_liters']) ?? 0,
      mealsFollowed: today['meals_followed'] as bool? ?? false,
      workoutDone: today['workout_done'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}
