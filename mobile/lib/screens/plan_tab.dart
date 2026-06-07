import 'package:flutter/material.dart';

import '../models/diet_plan.dart';
import '../services/diet_service.dart';
import '../widgets/section_card.dart';
import 'generate_plan_screen.dart';

/// Plan tab — shows the active AI-generated diet plan.
/// If no plan exists, prompts the user to generate one.
class PlanTab extends StatefulWidget {
  const PlanTab({super.key});

  @override
  State<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<PlanTab> {
  final DietService _dietService = DietService();
  DietPlan? _plan;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  bool _confirming = false;

  Future<void> _loadPlan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final plan = await _dietService.getActivePlan();
      if (mounted) setState(() => _plan = plan);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst(
            RegExp(r'^ApiException\(\d+\): '), ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmPlan() async {
    setState(() => _confirming = true);
    try {
      await _dietService.confirmPlan();
      await _loadPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reja tasdiqlandi! Endi har kuni rioya qiling 💪')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst(
              RegExp(r'^ApiException\(\d+\): '), ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parhez rejasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadPlan,
            tooltip: 'Yangilash',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadPlan,
                child: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    if (_plan == null || !_plan!.isReady) {
      return _buildEmptyState();
    }

    return _buildPlanContent(_plan!);
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_menu_outlined,
                  size: 48, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Hali reja yo\'q',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI yordamida shaxsiy parhez rejangizni yarating',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GeneratePlanScreen(),
                  ),
                );
                _loadPlan(); // Reload after returning
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Reja yaratish'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanContent(DietPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _loadPlan,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Confirmation banner — shown until the user accepts the plan
          if (!plan.confirmed)
            Card(
              color: scheme.primaryContainer,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_outlined, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rejani tasdiqlang',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tasdiqlagach, ilova sizni har kuni rejaga rioya qilishga '
                      'undaydi: ovqat, suv va mashg\'ulotni belgilang.',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _confirming ? null : _confirmPlan,
                        icon: _confirming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Tasdiqlash va boshlash'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Macros summary card
          SectionCard(
            title: 'Kunlik norma',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroItem(
                  label: 'Kaloriya',
                  value: plan.caloriesPerDay?.toString() ?? '—',
                  unit: 'kal',
                  color: scheme.primaryContainer,
                ),
                _MacroItem(
                  label: 'Oqsil',
                  value: plan.proteinG?.toStringAsFixed(0) ?? '—',
                  unit: 'g',
                  color: scheme.secondaryContainer,
                ),
                _MacroItem(
                  label: 'Uglevodlar',
                  value: plan.carbsG?.toStringAsFixed(0) ?? '—',
                  unit: 'g',
                  color: scheme.tertiaryContainer,
                ),
                _MacroItem(
                  label: 'Yog\'',
                  value: plan.fatG?.toStringAsFixed(0) ?? '—',
                  unit: 'g',
                  color: const Color(0xFFFFE0B2),
                ),
              ],
            ),
          ),

          // Sport recommendation
          if (plan.sportRecommendation != null &&
              plan.sportRecommendation!.isNotEmpty)
            SectionCard(
              title: 'Sport tavsiyasi',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fitness_center_outlined,
                      color: scheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(plan.sportRecommendation!)),
                ],
              ),
            ),

          // General advice
          if (plan.generalAdvice != null && plan.generalAdvice!.isNotEmpty)
            SectionCard(
              title: 'Umumiy maslahat',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outlined,
                      color: scheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(plan.generalAdvice!)),
                ],
              ),
            ),

          // Day-by-day meal cards
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Kunlar bo\'yicha menyu',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          if (plan.days.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Kunlik menyu yuklanmoqda...',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            ...plan.days.map((day) => _DayPlanCard(day: day)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Macro nutrient display widget.
class _MacroItem extends StatelessWidget {
  const _MacroItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(unit, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Expandable card for a single day's meals.
class _DayPlanCard extends StatefulWidget {
  const _DayPlanCard({required this.day});
  final DayPlan day;

  @override
  State<_DayPlanCard> createState() => _DayPlanCardState();
}

class _DayPlanCardState extends State<_DayPlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.day.dayNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.day.dayNumber}-kun',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${widget.day.meals.length} ovqat',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.day.meals.map(
                    (meal) => _MealTile(meal: meal),
                  ),
                  if (widget.day.notes != null &&
                      widget.day.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.notes_outlined,
                            size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.day.notes!,
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Single meal entry within a day card.
class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              meal.mealTypeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.name,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (meal.description != null && meal.description!.isNotEmpty)
                  Text(
                    meal.description!,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                if (meal.calories != null)
                  Text(
                    '${meal.calories} kal${meal.proteinG != null ? " · ${meal.proteinG!.toStringAsFixed(0)}g oqsil" : ""}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.primary),
                  ),
                if (meal.ingredients != null && meal.ingredients!.isNotEmpty)
                  Text(
                    meal.ingredients!,
                    style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
