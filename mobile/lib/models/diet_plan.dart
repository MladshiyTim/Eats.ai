/// Represents an AI-generated diet & fitness plan.
/// Field names match backend snake_case exactly.
class DietPlan {
  final int id;
  final int userId;
  final String status; // 'pending' | 'ready' | 'failed'
  final int durationDays;
  final int? caloriesPerDay;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? waterLitersPerDay;
  final String? sportRecommendation;
  final String? generalAdvice;
  final bool confirmed;
  final List<DayPlan> days;
  final DateTime? createdAt;

  const DietPlan({
    required this.id,
    required this.userId,
    required this.status,
    required this.durationDays,
    this.caloriesPerDay,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.waterLitersPerDay,
    this.sportRecommendation,
    this.generalAdvice,
    this.confirmed = false,
    this.days = const [],
    this.createdAt,
  });

  bool get isReady => status == 'ready';

  factory DietPlan.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>?;
    final rawMealPlan = json['meal_plan'] as List<dynamic>?;
    final days = rawDays != null
        ? rawDays.map((d) => DayPlan.fromJson(d as Map<String, dynamic>)).toList()
        : _parseBackendMealPlan(rawMealPlan);

    return DietPlan(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user']) ?? _parseInt(json['user_id']) ?? 0,
      status: json['status'] as String? ?? 'ready',
      durationDays: json['duration_days'] as int? ?? 0,
      caloriesPerDay: _parseInt(json['calories_per_day'] ?? json['daily_calories']),
      proteinG: _parseDouble(json['protein_g'] ?? json['daily_protein_g']),
      carbsG: _parseDouble(json['carbs_g'] ?? json['daily_carbs_g']),
      fatG: _parseDouble(json['fat_g'] ?? json['daily_fat_g']),
      waterLitersPerDay:
          _parseDouble(json['water_liters_per_day'] ?? json['daily_water_liters']),
      sportRecommendation: json['sport_recommendation'] as String?,
      generalAdvice: json['general_advice'] as String?,
      confirmed: json['confirmed'] as bool? ?? false,
      days: days,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'status': status,
        'duration_days': durationDays,
        'calories_per_day': caloriesPerDay,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'sport_recommendation': sportRecommendation,
        'general_advice': generalAdvice,
        'days': days.map((d) => d.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
      };
}

/// A single day within a DietPlan.
class DayPlan {
  final int id;
  final int dayNumber;
  final List<Meal> meals;
  final String? notes;

  const DayPlan({
    required this.id,
    required this.dayNumber,
    this.meals = const [],
    this.notes,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as List<dynamic>? ?? [];
    return DayPlan(
      id: _parseInt(json['id']) ?? 0,
      dayNumber: _parseInt(json['day_number']) ?? 0,
      meals: rawMeals.map((m) => Meal.fromJson(m as Map<String, dynamic>)).toList(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'day_number': dayNumber,
        'meals': meals.map((m) => m.toJson()).toList(),
        'notes': notes,
      };
}

List<DayPlan> _parseBackendMealPlan(List<dynamic>? rawMealPlan) {
  if (rawMealPlan == null) return const [];
  return rawMealPlan
      .whereType<Map<String, dynamic>>()
      .map((dayJson) {
        final dayNumber = _parseInt(dayJson['day']) ?? 0;
        final meals = <Meal>[];

        void addMeal(String type, dynamic rawMeal) {
          if (rawMeal is! Map<String, dynamic>) return;
          meals.add(Meal.fromBackendMeal(type, rawMeal, meals.length + 1));
        }

        addMeal('breakfast', dayJson['breakfast']);
        addMeal('lunch', dayJson['lunch']);
        addMeal('dinner', dayJson['dinner']);

        final snacks = dayJson['snacks'];
        if (snacks is List) {
          for (final snack in snacks) {
            addMeal('snack', snack);
          }
        }

        return DayPlan(
          id: dayNumber,
          dayNumber: dayNumber,
          meals: meals,
          notes: dayJson['notes'] as String?,
        );
      })
      .toList();
}

/// A meal entry within a DayPlan.
class Meal {
  final int id;
  final String mealType; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final String name;
  final String? description;
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String? ingredients;

  const Meal({
    required this.id,
    required this.mealType,
    required this.name,
    this.description,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.ingredients,
  });

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        id: _parseInt(json['id']) ?? 0,
        mealType: json['meal_type'] as String? ?? 'lunch',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        calories: _parseInt(json['calories']),
        proteinG: _parseDouble(json['protein_g']),
        carbsG: _parseDouble(json['carbs_g']),
        fatG: _parseDouble(json['fat_g']),
        ingredients: json['ingredients'] as String?,
      );

  factory Meal.fromBackendMeal(
    String mealType,
    Map<String, dynamic> json,
    int fallbackId,
  ) {
    final ingredients = json['ingredients'];
    return Meal(
      id: _parseInt(json['id']) ?? fallbackId,
      mealType: mealType,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      calories: _parseInt(json['calories']),
      proteinG: _parseDouble(json['protein_g']),
      carbsG: _parseDouble(json['carbs_g']),
      fatG: _parseDouble(json['fat_g']),
      ingredients: ingredients is List
          ? ingredients.join(', ')
          : ingredients is String
              ? ingredients
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'meal_type': mealType,
        'name': name,
        'description': description,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'ingredients': ingredients,
      };

  /// Uzbek display label for meal type.
  String get mealTypeLabel {
    switch (mealType) {
      case 'breakfast':
        return 'Nonushta';
      case 'lunch':
        return 'Tushlik';
      case 'dinner':
        return 'Kechki ovqat';
      case 'snack':
        return 'Gazak';
      default:
        return mealType;
    }
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
