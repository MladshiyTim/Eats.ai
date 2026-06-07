import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/diet_service.dart';
import '../widgets/primary_button.dart';

/// Screen for configuring and triggering AI diet plan generation.
/// Allows the user to pick duration (10/14/21/30 days or custom).
/// Shows a progress/loading state since AI generation can take 10–30 seconds.
class GeneratePlanScreen extends StatefulWidget {
  const GeneratePlanScreen({super.key});

  @override
  State<GeneratePlanScreen> createState() => _GeneratePlanScreenState();
}

class _GeneratePlanScreenState extends State<GeneratePlanScreen>
    with TickerProviderStateMixin {
  final DietService _dietService = DietService();
  final _customDaysCtrl = TextEditingController();

  int? _selectedDays = 14; // Default to 14 days
  bool _useCustom = false;
  bool _isGenerating = false;
  String? _progressMessage;
  late AnimationController _dotAnimCtrl;
  late Animation<int> _dotAnim;

  static const _presetDurations = [10, 14, 21, 30];

  @override
  void initState() {
    super.initState();
    // Animated dots for "generating" state
    _dotAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _dotAnim = IntTween(begin: 0, end: 3).animate(_dotAnimCtrl);
  }

  @override
  void dispose() {
    _customDaysCtrl.dispose();
    _dotAnimCtrl.dispose();
    super.dispose();
  }

  int? get _effectiveDays {
    if (_useCustom) {
      return int.tryParse(_customDaysCtrl.text.trim());
    }
    return _selectedDays;
  }

  Future<void> _generate() async {
    final days = _effectiveDays;
    if (days == null || days < 3 || days > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Davomiylik 3 dan 90 kungacha bo\'lishi kerak'),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _progressMessage = 'AI reja tayyorlamoqda';
    });

    // Update progress message periodically to keep user informed
    final messages = [
      'AI reja tayyorlamoqda',
      'Profilingiz tahlil qilinmoqda',
      'Ovqat dasturi tuzilmoqda',
      'Sport tavsiyalari yaratilmoqda',
      'Reja yakunlanmoqda',
    ];
    int msgIdx = 0;
    final msgTimer = Stream.periodic(const Duration(seconds: 4)).listen((_) {
      if (mounted && _isGenerating) {
        msgIdx = (msgIdx + 1) % messages.length;
        setState(() => _progressMessage = messages[msgIdx]);
      }
    });

    try {
      await _dietService.generatePlan(days);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reja muvaffaqiyatli yaratildi!'),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      String msg = e.message;
      // Common: profile not complete
      if (e.statusCode == 400 || e.statusCode == 422) {
        msg = 'Avval profilingizni to\'ldiring: $msg';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xato: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      msgTimer.cancel();
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reja yaratish'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illustration
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 52,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'AI Parhez Rejasi',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Profilingiz asosida shaxsiy parhez va sport rejangiz tayyorlanadi. '
              'Bu jarayon 10–30 soniya vaqt olishi mumkin.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            // Duration selector
            Text(
              'Davomiylik',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._presetDurations.map(
                  (d) => _DurationChip(
                    label: '$d kun',
                    isSelected: !_useCustom && _selectedDays == d,
                    onTap: () => setState(() {
                      _selectedDays = d;
                      _useCustom = false;
                    }),
                  ),
                ),
                _DurationChip(
                  label: 'Boshqa',
                  isSelected: _useCustom,
                  onTap: () => setState(() => _useCustom = true),
                ),
              ],
            ),

            if (_useCustom) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customDaysCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Kunlar soni (3–90)',
                  hintText: '14',
                  suffixText: 'kun',
                ),
                autofocus: true,
              ),
            ],

            const SizedBox(height: 32),

            // Generate button or progress indicator
            if (_isGenerating) ...[
              _buildGeneratingWidget(),
            ] else ...[
              PrimaryButton(
                label: 'Yaratish',
                icon: Icons.auto_awesome,
                onPressed: _generate,
              ),
              const SizedBox(height: 12),
              Text(
                'Reja yaratilgandan keyin "Reja" bo\'limida ko\'rinadi.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingWidget() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(
              height: 56,
              width: 56,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _dotAnim,
              builder: (_, __) {
                final dots = '.' * (_dotAnim.value + 1);
                return Text(
                  '${_progressMessage ?? "AI reja tayyorlamoqda"}$dots',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: scheme.primary,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Iltimos kuting — bu 10–30 soniya vaqt olishi mumkin',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? scheme.onPrimary : scheme.onSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
