import 'package:flutter/material.dart';

import '../models/daily_log.dart';
import '../models/daily_status.dart';
import '../services/diet_service.dart';
import '../services/log_service.dart';
import 'food_camera_screen.dart';

/// Full-screen blocking gate that enforces daily plan adherence.
///
/// While the backend reports `locked == true` the user cannot leave this
/// screen — they must confirm the plan, log their food, drink their water,
/// and mark their workout. As soon as nothing is outstanding it pops itself.
///
/// Fails open: if the status can't be loaded (e.g. no network) the gate
/// closes rather than bricking the app.
class DailyGateScreen extends StatefulWidget {
  const DailyGateScreen({super.key, required this.initialStatus});

  final DailyStatus initialStatus;

  @override
  State<DailyGateScreen> createState() => _DailyGateScreenState();
}

class _DailyGateScreenState extends State<DailyGateScreen> {
  final DietService _dietService = DietService();
  final LogService _logService = LogService();

  late DailyStatus _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  String get _todayStr {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _refresh() async {
    try {
      final status = await _dietService.getDailyStatus();
      if (!mounted) return;
      setState(() => _status = status);
      if (!status.locked) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      // Fail open — don't trap the user behind a network error.
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst(
              RegExp(r'^ApiException\(\d+\): '), ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPlan() => _run(() => _dietService.confirmPlan());

  Future<void> _drinkWater() => _run(() async {
        final next = _status.waterLiters + 0.25;
        await _logService.upsertLog(DailyLog(
          date: _todayStr,
          waterLiters: double.parse(next.toStringAsFixed(2)),
          waterTargetMet: next >= _status.targetWaterLiters,
        ));
      });

  Future<void> _markWorkout() => _run(() async {
        await _logService.upsertLog(DailyLog(
          date: _todayStr,
          workoutDone: true,
        ));
      });

  Future<void> _logFood() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FoodCameraScreen()),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _status;

    return PopScope(
      canPop: false, // hard-forcing: cannot dismiss while locked
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_fire_department,
                      size: 48, color: scheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  s.streak > 0 ? '${s.streak} kunlik seriya 🔥' : 'Bugungi vazifalar',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Davom etish uchun bugungi barcha vazifalarni bajaring.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 24),

              if (s.needsConfirm)
                _ActionCard(
                  icon: Icons.verified_outlined,
                  title: 'Rejani tasdiqlang',
                  subtitle: 'Parhez rejangizni qabul qiling va boshlang.',
                  buttonLabel: 'Tasdiqlash',
                  busy: _busy,
                  onPressed: _confirmPlan,
                ),

              if (s.needsFood)
                _ActionCard(
                  icon: Icons.camera_alt_outlined,
                  title: 'Ovqatni belgilang',
                  subtitle:
                      'Bugun yegan taomingizni rasmga oling — kaloriyasi avtomatik hisoblanadi.',
                  buttonLabel: 'Rasmga olish',
                  busy: _busy,
                  onPressed: _logFood,
                ),

              if (s.needsWater)
                _ActionCard(
                  icon: Icons.water_drop_outlined,
                  title: 'Suv iching',
                  subtitle:
                      '${s.waterLiters.toStringAsFixed(2)} / ${s.targetWaterLiters.toStringAsFixed(1)} L. '
                      'Yana ${s.waterRemainingLiters.toStringAsFixed(2)} L qoldi.',
                  buttonLabel: '+250 ml',
                  busy: _busy,
                  onPressed: _drinkWater,
                ),

              if (s.needsWorkout)
                _ActionCard(
                  icon: Icons.fitness_center_outlined,
                  title: 'Mashg\'ulot',
                  subtitle: 'Bugungi mashqni bajardingizmi?',
                  buttonLabel: 'Bajardim',
                  busy: _busy,
                  onPressed: _markWorkout,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Icon(icon, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: busy ? null : onPressed,
                    child: Text(buttonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
