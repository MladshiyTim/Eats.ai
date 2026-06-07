import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/daily_log.dart';
import '../services/log_service.dart';
import '../widgets/labeled_field.dart';
import '../widgets/primary_button.dart';

/// Log tab — shows the last 30 days of health logs in a scrollable list.
/// Each row shows the date and dot indicators.
/// Tapping a row opens an edit dialog.
class LogTab extends StatefulWidget {
  const LogTab({super.key});

  @override
  State<LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<LogTab> {
  final LogService _logService = LogService();
  List<DailyLog> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await _logService.listLogs();
      if (mounted) setState(() => _logs = logs);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e
            .toString()
            .replaceFirst(RegExp(r'^ApiException\(\d+\): '), ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Builds a list of dates for the last 30 days and matches with logs.
  List<_LogRow> _buildRows() {
    final now = DateTime.now();
    final rows = <_LogRow>[];
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final log = _logs.cast<DailyLog?>().firstWhere(
            (l) => l?.date == dateStr,
            orElse: () => null,
          );
      rows.add(_LogRow(date: date, dateStr: dateStr, log: log));
    }
    return rows;
  }

  void _openEditDialog(DailyLog? existing, String dateStr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LogEditSheet(
        existingLog: existing,
        dateStr: dateStr,
        onSaved: (_) => _loadLogs(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kunlik qaydlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadLogs,
            tooltip: 'Yangilash',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadLogs)
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: Builder(
                    builder: (context) {
                      final rows = _buildRows();
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return _LogListTile(
                            row: row,
                            onTap: () =>
                                _openEditDialog(row.log, row.dateStr),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _LogRow {
  final DateTime date;
  final String dateStr;
  final DailyLog? log;
  const _LogRow({required this.date, required this.dateStr, this.log});
}

class _LogListTile extends StatelessWidget {
  const _LogListTile({required this.row, required this.onTap});
  final _LogRow row;
  final VoidCallback onTap;

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Bugun';
    if (d == today.subtract(const Duration(days: 1))) return 'Kecha';
    return DateFormat('d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final log = row.log;
    final hasData = log != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Date column
              SizedBox(
                width: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd').format(row.date),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: hasData ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _dayLabel(row.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Indicator dots
              Expanded(
                child: hasData
                    ? Wrap(
                        spacing: 8,
                        children: [
                          if (log.weightKg != null)
                            _Dot(
                              icon: Icons.monitor_weight_outlined,
                              label: '${log.weightKg!.toStringAsFixed(1)} kg',
                              color: scheme.primary,
                            ),
                          if (log.mealsFollowed == true)
                            const _Dot(
                              icon: Icons.restaurant_outlined,
                              label: 'Taom',
                              color: Colors.green,
                            ),
                          if (log.workoutDone == true)
                            const _Dot(
                              icon: Icons.fitness_center_outlined,
                              label: 'Sport',
                              color: Colors.orange,
                            ),
                          if (log.waterTargetMet == true)
                            const _Dot(
                              icon: Icons.water_drop_outlined,
                              label: 'Suv',
                              color: Colors.blue,
                            ),
                        ],
                      )
                    : Text(
                        'Yozilmagan',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
              ),
              // Edit icon
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

/// Bottom sheet for creating/editing a daily log entry.
class _LogEditSheet extends StatefulWidget {
  const _LogEditSheet({
    this.existingLog,
    required this.dateStr,
    required this.onSaved,
  });
  final DailyLog? existingLog;
  final String dateStr;
  final ValueChanged<DailyLog> onSaved;

  @override
  State<_LogEditSheet> createState() => _LogEditSheetState();
}

class _LogEditSheetState extends State<_LogEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final LogService _logService = LogService();

  final _weightCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _sleepCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _mealsFollowed = false;
  bool _workoutDone = false;
  bool _waterTargetMet = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final log = widget.existingLog;
    if (log != null) {
      _weightCtrl.text = log.weightKg?.toString() ?? '';
      _waterCtrl.text = log.waterLiters?.toString() ?? '';
      _sleepCtrl.text = log.sleepHours?.toString() ?? '';
      _caloriesCtrl.text = log.caloriesConsumed?.toString() ?? '';
      _notesCtrl.text = log.notes ?? '';
      _mealsFollowed = log.mealsFollowed ?? false;
      _workoutDone = log.workoutDone ?? false;
      _waterTargetMet = log.waterTargetMet ?? false;
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _waterCtrl.dispose();
    _sleepCtrl.dispose();
    _caloriesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final log = DailyLog(
        id: widget.existingLog?.id,
        date: widget.dateStr,
        weightKg: _weightCtrl.text.isNotEmpty
            ? double.tryParse(_weightCtrl.text)
            : null,
        waterLiters: _waterCtrl.text.isNotEmpty
            ? double.tryParse(_waterCtrl.text)
            : null,
        sleepHours: _sleepCtrl.text.isNotEmpty
            ? double.tryParse(_sleepCtrl.text)
            : null,
        caloriesConsumed: _caloriesCtrl.text.isNotEmpty
            ? int.tryParse(_caloriesCtrl.text)
            : null,
        mealsFollowed: _mealsFollowed,
        workoutDone: _workoutDone,
        waterTargetMet: _waterTargetMet,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      final saved = await _logService.upsertLog(log);
      if (!mounted) return;
      widget.onSaved(saved);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qayd saqlandi!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst(
              RegExp(r'^ApiException\(\d+\): '), '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.dateStr,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Vazn (kg)',
                      hint: '70.0',
                      controller: _weightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LabeledField(
                      label: 'Suv (litr)',
                      hint: '2.0',
                      controller: _waterCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Uyqu (soat)',
                      hint: '7.5',
                      controller: _sleepCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LabeledField(
                      label: 'Kaloriya',
                      hint: '1800',
                      controller: _caloriesCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Checkboxes
              CheckboxListTile(
                title: const Text('Taom rejasiga rioya qildim'),
                value: _mealsFollowed,
                onChanged: (v) => setState(() => _mealsFollowed = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('Mashg\'ulot bajarildim'),
                value: _workoutDone,
                onChanged: (v) => setState(() => _workoutDone = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('Suv normasiga yetdim'),
                value: _waterTargetMet,
                onChanged: (v) => setState(() => _waterTargetMet = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 12),
              LabeledField(
                label: 'Izoh (ixtiyoriy)',
                hint: 'Bugungi his-tuyg\'ular, yog\'ilar...',
                controller: _notesCtrl,
                maxLines: 2,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 20),

              PrimaryButton(
                label: 'Saqlash',
                onPressed: _isSaving ? null : _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }
}
