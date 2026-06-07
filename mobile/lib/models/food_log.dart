/// A single food item the user logged (recognized from a photo via AI,
/// or entered manually). Field names match the Django backend (snake_case).
class FoodLog {
  final int id;
  final String date; // ISO 8601: 'YYYY-MM-DD'
  final String mealType; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String portionNote;
  final bool recognized;
  final double? confidence;
  final DateTime? createdAt;

  const FoodLog({
    required this.id,
    required this.date,
    required this.mealType,
    required this.name,
    required this.calories,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.portionNote = '',
    this.recognized = true,
    this.confidence,
    this.createdAt,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) => FoodLog(
        id: _parseInt(json['id']) ?? 0,
        date: json['date'] as String? ?? '',
        mealType: json['meal_type'] as String? ?? 'snack',
        name: json['name'] as String? ?? '',
        calories: _parseInt(json['calories']) ?? 0,
        proteinG: _parseDouble(json['protein_g']) ?? 0,
        carbsG: _parseDouble(json['carbs_g']) ?? 0,
        fatG: _parseDouble(json['fat_g']) ?? 0,
        portionNote: json['portion_note'] as String? ?? '',
        recognized: json['recognized'] as bool? ?? true,
        confidence: _parseDouble(json['confidence']),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

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
