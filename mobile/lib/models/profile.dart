/// User health profile — filled in during QuestionnaireScreen.
/// Field names match the Django backend (snake_case).
class Profile {
  final int? id;
  final String? fullName;
  final int? age;
  final String? gender; // 'M' | 'F'
  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;
  final String? workType; // 'sedentary' | 'standing' | 'physical' | 'mixed'
  final int? workHoursPerDay;
  final double? sleepHoursPerDay;
  final String? activityLevel; // 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active'
  final bool? doesSport;
  final String? sportType;
  final double? waterLitersPerDay;
  final String? goal; // 'lose_weight' | 'maintain' | 'gain_weight' | 'build_muscle'
  final String? medicalConditions;
  final String? foodAllergies;

  const Profile({
    this.id,
    this.fullName,
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    this.workType,
    this.workHoursPerDay,
    this.sleepHoursPerDay,
    this.activityLevel,
    this.doesSport,
    this.sportType,
    this.waterLitersPerDay,
    this.goal,
    this.medicalConditions,
    this.foodAllergies,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as int?,
      fullName: json['full_name'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      heightCm: _parseDouble(json['height_cm']),
      weightKg: _parseDouble(json['weight_kg']),
      targetWeightKg: _parseDouble(json['target_weight_kg']),
      workType: json['work_type'] as String?,
      workHoursPerDay: json['work_hours_per_day'] as int?,
      sleepHoursPerDay: _parseDouble(json['sleep_hours_per_day']),
      activityLevel: json['activity_level'] as String?,
      doesSport: json['does_sport'] as bool?,
      sportType: json['sport_type'] as String?,
      waterLitersPerDay: _parseDouble(json['water_liters_per_day']),
      goal: json['goal'] as String?,
      medicalConditions: json['medical_conditions'] as String?,
      foodAllergies: json['food_allergies'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (fullName != null) map['full_name'] = fullName;
    if (age != null) map['age'] = age;
    if (gender != null) map['gender'] = gender;
    if (heightCm != null) map['height_cm'] = heightCm;
    if (weightKg != null) map['weight_kg'] = weightKg;
    if (targetWeightKg != null) map['target_weight_kg'] = targetWeightKg;
    if (workType != null) map['work_type'] = workType;
    if (workHoursPerDay != null) map['work_hours_per_day'] = workHoursPerDay;
    if (sleepHoursPerDay != null) map['sleep_hours_per_day'] = sleepHoursPerDay;
    if (activityLevel != null) map['activity_level'] = activityLevel;
    if (doesSport != null) map['does_sport'] = doesSport;
    if (sportType != null) map['sport_type'] = sportType;
    if (waterLitersPerDay != null) map['water_liters_per_day'] = waterLitersPerDay;
    if (goal != null) map['goal'] = goal;
    if (medicalConditions != null) map['medical_conditions'] = medicalConditions;
    if (foodAllergies != null) map['food_allergies'] = foodAllergies;
    return map;
  }

  /// Creates a copy of this profile with the given fields updated.
  Profile copyWith({
    int? id,
    String? fullName,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    String? workType,
    int? workHoursPerDay,
    double? sleepHoursPerDay,
    String? activityLevel,
    bool? doesSport,
    String? sportType,
    double? waterLitersPerDay,
    String? goal,
    String? medicalConditions,
    String? foodAllergies,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      workType: workType ?? this.workType,
      workHoursPerDay: workHoursPerDay ?? this.workHoursPerDay,
      sleepHoursPerDay: sleepHoursPerDay ?? this.sleepHoursPerDay,
      activityLevel: activityLevel ?? this.activityLevel,
      doesSport: doesSport ?? this.doesSport,
      sportType: sportType ?? this.sportType,
      waterLitersPerDay: waterLitersPerDay ?? this.waterLitersPerDay,
      goal: goal ?? this.goal,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      foodAllergies: foodAllergies ?? this.foodAllergies,
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
