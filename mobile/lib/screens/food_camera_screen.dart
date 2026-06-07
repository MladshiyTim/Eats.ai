import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../services/food_service.dart';

/// Photo → calories screen. The user takes/picks a photo of their meal;
/// Gemini Vision (on the backend) recognizes it and logs the calories.
class FoodCameraScreen extends StatefulWidget {
  const FoodCameraScreen({super.key, this.initialMealType});

  /// Pre-selected meal type ('breakfast' | 'lunch' | 'dinner' | 'snack').
  final String? initialMealType;

  @override
  State<FoodCameraScreen> createState() => _FoodCameraScreenState();
}

class _FoodCameraScreenState extends State<FoodCameraScreen> {
  final FoodService _foodService = FoodService();
  final ImagePicker _picker = ImagePicker();

  late String _mealType;
  File? _image;
  bool _isAnalyzing = false;
  String? _error;
  FoodAnalysisResult? _result;
  bool _logged = false;

  static const _mealTypes = {
    'breakfast': 'Nonushta',
    'lunch': 'Tushlik',
    'dinner': 'Kechki ovqat',
    'snack': 'Gazak',
  };

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType ?? _defaultMealType();
  }

  String _defaultMealType() {
    final h = DateTime.now().hour;
    if (h < 11) return 'breakfast';
    if (h < 16) return 'lunch';
    if (h < 21) return 'dinner';
    return 'snack';
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _result = null;
        _error = null;
        _logged = false;
      });
      await _analyze();
    } catch (e) {
      setState(() => _error = 'Rasm tanlab bo\'lmadi: $e');
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });
    try {
      final result =
          await _foodService.analyzePhoto(_image!.path, mealType: _mealType);
      if (!mounted) return;
      setState(() {
        _result = result;
        _logged = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Xatolik: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _undo() async {
    final result = _result;
    if (result == null) return;
    try {
      await _foodService.deleteFoodLog(result.foodLog.id);
      if (!mounted) return;
      setState(() {
        _result = null;
        _logged = false;
        _image = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bekor qilindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bekor qilib bo\'lmadi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ovqatni rasmga olish'),
        actions: [
          if (_logged)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tayyor'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Meal type selector
          Text('Qaysi ovqat?',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _mealTypes.entries.map((e) {
              final selected = e.key == _mealType;
              return ChoiceChip(
                label: Text(e.value),
                selected: selected,
                onSelected: (_) => setState(() => _mealType = e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Image preview
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                image: _image != null
                    ? DecorationImage(
                        image: FileImage(_image!), fit: BoxFit.cover)
                    : null,
              ),
              child: _image == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant,
                              size: 56, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('Taom rasmini oling',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Capture buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isAnalyzing ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed:
                      _isAnalyzing ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galereya'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isAnalyzing)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('AI taomni tahlil qilmoqda...'),
              ],
            ),

          if (_error != null)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(color: scheme.onErrorContainer)),
                    ),
                  ],
                ),
              ),
            ),

          if (_result != null) _ResultCard(result: _result!, onUndo: _undo),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onUndo});
  final FoodAnalysisResult result;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final food = result.foodLog;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(food.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (food.portionNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(food.portionNote,
                  style: TextStyle(color: scheme.onPrimaryContainer)),
            ],
            const SizedBox(height: 12),
            Text('${food.calories} kkal',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800, color: scheme.primary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                _Macro(label: 'Oqsil', value: '${food.proteinG.toStringAsFixed(0)} g'),
                _Macro(label: 'Uglevod', value: '${food.carbsG.toStringAsFixed(0)} g'),
                _Macro(label: 'Yog\'', value: '${food.fatG.toStringAsFixed(0)} g'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Bugungi jami: ${result.caloriesConsumedToday} kkal',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onUndo,
                icon: const Icon(Icons.undo),
                label: const Text('Bekor qilish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
