import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/daily_log.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../services/diet_service.dart';
import '../services/log_service.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_chip.dart';
import 'generate_plan_screen.dart';

/// Dashboard tab — greeting, today's stats, weight input, plan status.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final LogService _logService = LogService();
  final DietService _dietService = DietService();
  final _weightCtrl = TextEditingController();

  DailyLog? _todayLog;
  Map<String, dynamic> _weeklyStats = {};
  bool _hasActivePlan = false;
  int? _activePlanDays;
  double _waterTarget = 0;
  bool _isLoadingLog = true;
  bool _isSavingWeight = false;
  bool _isLoadingPlan = true;
  bool _isAddingWater = false;

  String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadTodayLog(),
      _loadActivePlan(),
      _loadWeeklyStats(),
    ]);
  }

  Future<void> _loadTodayLog() async {
    try {
      final log = await _logService.getTodayLog();
      if (mounted) {
        setState(() {
          _todayLog = log;
          if (log?.weightKg != null) {
            _weightCtrl.text = log!.weightKg!.toStringAsFixed(1);
          }
          _isLoadingLog = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLog = false);
    }
  }

  Future<void> _loadActivePlan() async {
    try {
      final plan = await _dietService.getActivePlan();
      if (mounted) {
        setState(() {
          _hasActivePlan = plan != null && plan.isReady;
          _activePlanDays = plan?.durationDays;
          _waterTarget = plan?.waterLitersPerDay ?? 0;
          _isLoadingPlan = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPlan = false);
    }
  }

  Future<void> _loadWeeklyStats() async {
    try {
      final stats = await _dietService.getWeeklyStats();
      if (mounted) setState(() => _weeklyStats = stats);
    } catch (_) {}
  }

  Future<void> _saveWeight() async {
    final weightStr = _weightCtrl.text.trim();
    if (weightStr.isEmpty) return;
    final weight = double.tryParse(weightStr);
    if (weight == null || weight < 30 || weight > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Noto\'g\'ri vazn qiymati')),
      );
      return;
    }

    setState(() => _isSavingWeight = true);
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final log = (_todayLog ?? DailyLog(date: dateStr)).copyWith(
        date: dateStr,
        weightKg: weight,
      );
      final saved = await _logService.upsertLog(log);
      if (mounted) {
        setState(() => _todayLog = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vazn saqlandi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xato: ${e.toString().replaceFirst(RegExp(r'^ApiException\(\d+\): '), '')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingWeight = false);
    }
  }

  /// Adds water with an optimistic UI update so the counter advances instantly,
  /// then persists and reverts on failure.
  Future<void> _addWater(double liters) async {
    final current = _todayLog?.waterLiters ?? 0;
    final next = double.parse((current + liters).toStringAsFixed(2));
    final met = _waterTarget > 0 && next >= _waterTarget;

    setState(() {
      _isAddingWater = true;
      _todayLog = (_todayLog ?? DailyLog(date: _todayStr())).copyWith(
        date: _todayStr(),
        waterLiters: next,
        waterTargetMet: met,
      );
    });

    try {
      final saved = await _logService.upsertLog(DailyLog(
        date: _todayStr(),
        waterLiters: next,
        waterTargetMet: met,
      ));
      if (mounted) setState(() => _todayLog = saved);
    } catch (e) {
      // Revert optimistic change on failure.
      if (mounted) {
        setState(() => _todayLog = _todayLog?.copyWith(waterLiters: current));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst(
              RegExp(r'^ApiException\(\d+\): '), ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingWater = false);
    }
  }

  Widget _buildWaterCard(ColorScheme scheme) {
    final water = _todayLog?.waterLiters ?? 0;
    final progress = _waterTarget > 0 ? (water / _waterTarget).clamp(0.0, 1.0) : 0.0;
    final met = water >= _waterTarget && _waterTarget > 0;
    final remaining = (_waterTarget - water).clamp(0.0, _waterTarget);

    return SectionCard(
      title: 'Suv ichish',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.water_drop, color: Colors.blue.shade400, size: 28),
              const SizedBox(width: 8),
              Text(
                '${water.toStringAsFixed(2)} ',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Text(
                '/ ${_waterTarget.toStringAsFixed(1)} L',
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (met)
                const Text('✅ Bajarildi',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: scheme.surfaceContainerHighest,
              color: Colors.blue.shade400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            met
                ? 'Bugungi suv normangizni bajardingiz! 💪'
                : 'Yana ${remaining.toStringAsFixed(2)} L qoldi — bir stakan iching.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: (_isAddingWater || met) ? null : () => _addWater(0.25),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('250 ml'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: (_isAddingWater || met) ? null : () => _addWater(0.5),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('500 ml'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>().profile;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Xayrli tong'
        : now.hour < 17
            ? 'Xayrli kun'
            : 'Xayrli kech';
    final displayName = profile?.fullName ??
        auth.currentUser?.displayName ??
        'foydalanuvchi';

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Salomatlik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yangilash',
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Greeting
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),

            // Today's stats card
            SectionCard(
              title: 'Bugungi ko\'rsatkichlar',
              child: _isLoadingLog
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        StatChip(
                          label: 'Kaloriya',
                          value: _todayLog?.caloriesConsumed?.toString() ?? '—',
                          unit: 'kal',
                          icon: Icons.local_fire_department_outlined,
                        ),
                        StatChip(
                          label: 'Suv',
                          value: _todayLog?.waterLiters?.toStringAsFixed(1) ?? '—',
                          unit: 'l',
                          icon: Icons.water_drop_outlined,
                          color: scheme.secondaryContainer,
                        ),
                        StatChip(
                          label: 'Uyqu',
                          value: _todayLog?.sleepHours?.toStringAsFixed(1) ?? '—',
                          unit: 'soat',
                          icon: Icons.bedtime_outlined,
                          color: scheme.tertiaryContainer,
                        ),
                        StatChip(
                          label: 'Vazn',
                          value: _todayLog?.weightKg?.toStringAsFixed(1) ?? '—',
                          unit: 'kg',
                          icon: Icons.monitor_weight_outlined,
                        ),
                      ],
                    ),
            ),

            // Water tracker card
            if (_waterTarget > 0) _buildWaterCard(scheme),

            // Weight input card
            SectionCard(
              title: 'Bugungi vazn',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      decoration: const InputDecoration(
                        hintText: '70.0',
                        suffixText: 'kg',
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveWeight(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSavingWeight ? null : _saveWeight,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(80, 52),
                    ),
                    child: _isSavingWeight
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Saqlash'),
                  ),
                ],
              ),
            ),

            // Plan status card
            SectionCard(
              title: 'Parhez rejasi',
              child: _isLoadingPlan
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _hasActivePlan
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.check_circle_outline,
                                  color: scheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Faol reja: $_activePlanDays kun',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Reja faol holatda',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Text(
                              'Hali parhez rejangiz yo\'q',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const GeneratePlanScreen(),
                                ),
                              ),
                              child: const Text('Reja yaratish'),
                            ),
                          ],
                        ),
            ),

            // Weekly stats card
            if (_weeklyStats.isNotEmpty) ...[
              SectionCard(
                title: 'Haftalik statistika',
                child: Column(
                  children: [
                    if (_weeklyStats['avg_weight'] != null)
                      _StatRow(
                        label: 'O\'rtacha vazn',
                        value: '${_weeklyStats['avg_weight']} kg',
                      ),
                    if (_weeklyStats['avg_calories'] != null)
                      _StatRow(
                        label: 'O\'rtacha kaloriya',
                        value: '${_weeklyStats['avg_calories']} kal',
                      ),
                    if (_weeklyStats['workouts_done'] != null)
                      _StatRow(
                        label: 'Mashg\'ulot',
                        value: '${_weeklyStats['workouts_done']} kun',
                      ),
                    if (_weeklyStats['meals_followed_days'] != null)
                      _StatRow(
                        label: 'Rejaga rioya',
                        value: '${_weeklyStats['meals_followed_days']} kun',
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
