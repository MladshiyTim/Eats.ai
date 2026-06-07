/// Daily health log entry — recorded by the user each day.
/// Field names match backend snake_case exactly.
class DailyLog {
  final int? id;
  final String date; // ISO 8601: 'YYYY-MM-DD'
  final double? weightKg;
  final double? waterLiters;
  final double? sleepHours;
  final int? caloriesConsumed;
  final bool? mealsFollowed;
  final bool? workoutDone;
  final bool? waterTargetMet;
  final String? notes;

  const DailyLog({
    this.id,
    required this.date,
    this.weightKg,
    this.waterLiters,
    this.sleepHours,
    this.caloriesConsumed,
    this.mealsFollowed,
    this.workoutDone,
    this.waterTargetMet,
    this.notes,
  });

  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog(
        id: json['id'] as int?,
        date: json['date'] as String,
        weightKg: _parseDouble(json['weight_kg']),
        waterLiters: _parseDouble(json['water_liters']),
        sleepHours: _parseDouble(json['sleep_hours']),
        caloriesConsumed: _parseInt(json['calories_consumed']),
        mealsFollowed: json['meals_followed'] as bool?,
        workoutDone: json['workout_done'] as bool?,
        waterTargetMet: json['water_target_met'] as bool?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'date': date};
    if (id != null) map['id'] = id;
    if (weightKg != null) map['weight_kg'] = weightKg;
    if (waterLiters != null) map['water_liters'] = waterLiters;
    if (sleepHours != null) map['sleep_hours'] = sleepHours;
    if (caloriesConsumed != null) map['calories_consumed'] = caloriesConsumed;
    if (mealsFollowed != null) map['meals_followed'] = mealsFollowed;
    if (workoutDone != null) map['workout_done'] = workoutDone;
    if (waterTargetMet != null) map['water_target_met'] = waterTargetMet;
    if (notes != null) map['notes'] = notes;
    return map;
  }

  DailyLog copyWith({
    int? id,
    String? date,
    double? weightKg,
    double? waterLiters,
    double? sleepHours,
    int? caloriesConsumed,
    bool? mealsFollowed,
    bool? workoutDone,
    bool? waterTargetMet,
    String? notes,
  }) {
    return DailyLog(
      id: id ?? this.id,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      waterLiters: waterLiters ?? this.waterLiters,
      sleepHours: sleepHours ?? this.sleepHours,
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      mealsFollowed: mealsFollowed ?? this.mealsFollowed,
      workoutDone: workoutDone ?? this.workoutDone,
      waterTargetMet: waterTargetMet ?? this.waterTargetMet,
      notes: notes ?? this.notes,
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

/// Safely parses an int that the backend may serialize as a double or string.
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}
