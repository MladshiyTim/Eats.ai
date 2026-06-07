import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/labeled_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import 'home_screen.dart';

/// Multi-step questionnaire for collecting the user's health profile.
/// 5 pages with a progress indicator and Prev/Next navigation.
/// Can be opened from ProfileTab (prefilled) or fresh after registration.
class QuestionnaireScreen extends StatefulWidget {
  /// If [existingProfile] is provided, fields are pre-filled.
  const QuestionnaireScreen({super.key, this.existingProfile});
  final Profile? existingProfile;

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;
  bool _isSaving = false;

  // ── Form keys per page ────────────────────────────────────────────────────────
  final _formKeys = List.generate(_totalPages, (_) => GlobalKey<FormState>());

  // ── Page 1: Basic info ────────────────────────────────────────────────────────
  final _fullNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  String? _gender; // 'M' | 'F'

  // ── Page 2: Work & routine ────────────────────────────────────────────────────
  String? _workType;
  final _workHoursCtrl = TextEditingController();
  final _sleepHoursCtrl = TextEditingController();

  // ── Page 3: Activity & sport ──────────────────────────────────────────────────
  String? _activityLevel;
  bool _doesSport = false;
  final _sportTypeCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();

  // ── Page 4: Goals & health ────────────────────────────────────────────────────
  String? _goal;
  final _medicalCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefill(widget.existingProfile);
  }

  void _prefill(Profile? p) {
    if (p == null) return;
    _fullNameCtrl.text = p.fullName ?? '';
    _ageCtrl.text = p.age?.toString() ?? '';
    _heightCtrl.text = p.heightCm?.toString() ?? '';
    _weightCtrl.text = p.weightKg?.toString() ?? '';
    _targetWeightCtrl.text = p.targetWeightKg?.toString() ?? '';
    _gender = p.gender;
    _workType = p.workType;
    _workHoursCtrl.text = p.workHoursPerDay?.toString() ?? '';
    _sleepHoursCtrl.text = p.sleepHoursPerDay?.toString() ?? '';
    _activityLevel = p.activityLevel;
    _doesSport = p.doesSport ?? false;
    _sportTypeCtrl.text = p.sportType ?? '';
    _waterCtrl.text = p.waterLitersPerDay?.toString() ?? '';
    _goal = p.goal;
    _medicalCtrl.text = p.medicalConditions ?? '';
    _allergiesCtrl.text = p.foodAllergies ?? '';
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fullNameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _workHoursCtrl.dispose();
    _sleepHoursCtrl.dispose();
    _sportTypeCtrl.dispose();
    _waterCtrl.dispose();
    _medicalCtrl.dispose();
    _allergiesCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────────

  void _nextPage() {
    if (!_formKeys[_currentPage].currentState!.validate()) return;
    _formKeys[_currentPage].currentState!.save();

    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Save profile ──────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final fields = <String, dynamic>{};

    // Gather all fields
    if (_fullNameCtrl.text.isNotEmpty) fields['full_name'] = _fullNameCtrl.text.trim();
    if (_ageCtrl.text.isNotEmpty) fields['age'] = int.parse(_ageCtrl.text.trim());
    if (_gender != null) fields['gender'] = _gender;
    if (_heightCtrl.text.isNotEmpty) {
      fields['height_cm'] = double.parse(_heightCtrl.text.trim());
    }
    if (_weightCtrl.text.isNotEmpty) {
      fields['weight_kg'] = double.parse(_weightCtrl.text.trim());
    }
    if (_targetWeightCtrl.text.isNotEmpty) {
      fields['target_weight_kg'] = double.parse(_targetWeightCtrl.text.trim());
    }
    if (_workType != null) fields['work_type'] = _workType;
    if (_workHoursCtrl.text.isNotEmpty) {
      fields['work_hours_per_day'] = int.parse(_workHoursCtrl.text.trim());
    }
    if (_sleepHoursCtrl.text.isNotEmpty) {
      fields['sleep_hours_per_day'] = double.parse(_sleepHoursCtrl.text.trim());
    }
    if (_activityLevel != null) fields['activity_level'] = _activityLevel;
    fields['does_sport'] = _doesSport;
    if (_doesSport && _sportTypeCtrl.text.isNotEmpty) {
      fields['sport_type'] = _sportTypeCtrl.text.trim();
    }
    if (_waterCtrl.text.isNotEmpty) {
      fields['water_liters_per_day'] = double.parse(_waterCtrl.text.trim());
    }
    if (_goal != null) fields['goal'] = _goal;
    if (_medicalCtrl.text.isNotEmpty) {
      fields['medical_conditions'] = _medicalCtrl.text.trim();
    }
    if (_allergiesCtrl.text.isNotEmpty) {
      fields['food_allergies'] = _allergiesCtrl.text.trim();
    }

    setState(() => _isSaving = true);
    try {
      await context.read<ProfileProvider>().saveProfile(fields);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil muvaffaqiyatli saqlandi!')),
      );

      // Navigate to HomeScreen, clearing the entire back stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst(RegExp(r'^ApiException\(\d+\): '), '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Page titles ───────────────────────────────────────────────────────────────

  static const _pageTitles = [
    'Asosiy ma\'lumotlar',
    'Ish va kun tartibi',
    'Faollik va sport',
    'Maqsad va sog\'liq',
    'Yakuniy',
  ];

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEditMode = widget.existingProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Profilni tahrirlash' : 'Profilni to\'ldirish'),
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevPage,
              )
            : (isEditMode ? const BackButton() : null),
        automaticallyImplyLeading: isEditMode,
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _pageTitles[_currentPage],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${_currentPage + 1} / $_totalPages',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentPage + 1) / _totalPages,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildPage1(),
                _buildPage2(),
                _buildPage3(),
                _buildPage4(),
                _buildPage5(),
              ],
            ),
          ),

          // Bottom navigation buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                if (_currentPage > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prevPage,
                      child: const Text('Orqaga'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: _currentPage < _totalPages - 1
                      ? PrimaryButton(
                          label: 'Davom etish',
                          onPressed: _nextPage,
                        )
                      : PrimaryButton(
                          label: 'Saqlash',
                          onPressed: _isSaving ? null : _saveProfile,
                          isLoading: _isSaving,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 1: Basic info ────────────────────────────────────────────────────────
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _formKeys[0],
        child: Column(
          children: [
            LabeledField(
              label: 'To\'liq ism',
              hint: 'Familiya va ism',
              controller: _fullNameCtrl,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ismingizni kiriting' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Yosh',
                    hint: '25',
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Kiriting';
                      final age = int.tryParse(v);
                      if (age == null || age < 10 || age > 100) {
                        return '10–100';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledField(
                    label: 'Bo\'y (sm)',
                    hint: '170',
                    controller: _heightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Kiriting';
                      final h = double.tryParse(v);
                      if (h == null || h < 100 || h > 250) return '100–250';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Hozirgi vazn (kg)',
                    hint: '70',
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Kiriting';
                      final w = double.tryParse(v);
                      if (w == null || w < 30 || w > 300) return '30–300 kg';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledField(
                    label: 'Maqsad vazn (kg)',
                    hint: '65',
                    controller: _targetWeightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Kiriting';
                      final w = double.tryParse(v);
                      if (w == null || w < 30 || w > 300) return '30–300 kg';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Gender radio
            SectionCard(
              title: 'Jins',
              child: Column(
                children: [
                  _buildRadio('Erkak', 'M'),
                  _buildRadio('Ayol', 'F'),
                  if (_gender == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Jinsni tanlang',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(String label, String value) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      // ignore: deprecated_member_use
      groupValue: _gender,
      contentPadding: EdgeInsets.zero,
      dense: true,
      // ignore: deprecated_member_use
      onChanged: (v) => setState(() => _gender = v),
    );
  }

  // ── Page 2: Work & routine ────────────────────────────────────────────────────
  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _formKeys[1],
        child: Column(
          children: [
            LabeledDropdown<String>(
              label: 'Ish turi',
              hint: 'Tanlang...',
              value: _workType,
              items: const [
                DropdownMenuItem(value: 'sedentary', child: Text('O\'tirgan holda (ofis)')),
                DropdownMenuItem(value: 'standing', child: Text('Tik turgan holda')),
                DropdownMenuItem(value: 'physical', child: Text('Jismoniy ish')),
                DropdownMenuItem(value: 'mixed', child: Text('Aralash')),
              ],
              onChanged: (v) => setState(() => _workType = v),
              validator: (v) => v == null ? 'Ish turini tanlang' : null,
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Kunlik ish soati',
              hint: '8',
              controller: _workHoursCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Kiriting';
                final h = int.tryParse(v);
                if (h == null || h < 1 || h > 24) return '1–24 soat';
                return null;
              },
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Kunlik uyqu soati',
              hint: '7.5',
              controller: _sleepHoursCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Kiriting';
                final h = double.tryParse(v);
                if (h == null || h < 1 || h > 24) return '1–24 soat';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 3: Activity & sport ──────────────────────────────────────────────────
  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _formKeys[2],
        child: Column(
          children: [
            LabeledDropdown<String>(
              label: 'Faollik darajasi',
              hint: 'Tanlang...',
              value: _activityLevel,
              items: const [
                DropdownMenuItem(value: 'sedentary', child: Text('Harakatsiz')),
                DropdownMenuItem(value: 'light', child: Text('Yengil (haftada 1-3 kun)')),
                DropdownMenuItem(value: 'moderate', child: Text("O'rtacha (haftada 3-5 kun)")),
                DropdownMenuItem(value: 'active', child: Text('Faol (haftada 6-7 kun)')),
                DropdownMenuItem(value: 'very_active', child: Text('Juda faol')),
              ],
              onChanged: (v) => setState(() => _activityLevel = v),
              validator: (v) => v == null ? 'Faollik darajasini tanlang' : null,
            ),
            const SizedBox(height: 16),

            // Does sport switch
            SectionCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sport bilan shug\'ullanasizmi?',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          _doesSport ? 'Ha' : 'Yo\'q',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _doesSport,
                    onChanged: (v) => setState(() => _doesSport = v),
                  ),
                ],
              ),
            ),

            if (_doesSport) ...[
              const SizedBox(height: 16),
              LabeledField(
                label: 'Sport turi',
                hint: 'Masalan: yugurish, futbol, yoga...',
                controller: _sportTypeCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Sport turini kiriting'
                    : null,
              ),
            ],
            const SizedBox(height: 16),

            LabeledField(
              label: 'Kunlik suv iste\'moli (litr)',
              hint: '2.0',
              controller: _waterCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Kiriting';
                final w = double.tryParse(v);
                if (w == null || w < 0.5 || w > 10) return '0.5–10 litr';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 4: Goals & health ────────────────────────────────────────────────────
  Widget _buildPage4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _formKeys[3],
        child: Column(
          children: [
            LabeledDropdown<String>(
              label: 'Asosiy maqsad',
              hint: 'Tanlang...',
              value: _goal,
              items: const [
                DropdownMenuItem(value: 'lose_weight', child: Text("Vazn yo'qotish")),
                DropdownMenuItem(value: 'maintain', child: Text('Vaznni saqlash')),
                DropdownMenuItem(value: 'gain_weight', child: Text('Vazn olish')),
                DropdownMenuItem(value: 'build_muscle', child: Text('Mushak qurish')),
              ],
              onChanged: (v) => setState(() => _goal = v),
              validator: (v) => v == null ? 'Maqsadni tanlang' : null,
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Tibbiy holatlar (ixtiyoriy)',
              hint: 'Masalan: diabet, gipertoniya...',
              controller: _medicalCtrl,
              maxLines: 3,
              minLines: 2,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Oziq-ovqat allergiyasi (ixtiyoriy)',
              hint: 'Masalan: yong\'oq, süt mahsulotlari...',
              controller: _allergiesCtrl,
              maxLines: 3,
              minLines: 2,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 5: Summary review ────────────────────────────────────────────────────
  Widget _buildPage5() {
    final scheme = Theme.of(context).colorScheme;

    Widget row(String label, String? value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Text(
                  value?.isNotEmpty == true ? value! : '—',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );

    String? genderLabel() {
      switch (_gender) {
        case 'M':
          return 'Erkak';
        case 'F':
          return 'Ayol';
        default:
          return null;
      }
    }

    String? goalLabel() {
      switch (_goal) {
        case 'lose_weight':
          return 'Vazn yo\'qotish';
        case 'maintain':
          return 'Vaznni saqlash';
        case 'gain_weight':
          return 'Vazn olish';
        case 'build_muscle':
          return 'Mushak qurish';
        default:
          return null;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _formKeys[4],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ma\'lumotlaringizni tekshiring',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Asosiy ma\'lumotlar',
              child: Column(
                children: [
                  row('To\'liq ism', _fullNameCtrl.text),
                  row('Yosh', _ageCtrl.text.isNotEmpty ? '${_ageCtrl.text} yosh' : null),
                  row('Jins', genderLabel()),
                  row('Bo\'y', _heightCtrl.text.isNotEmpty ? '${_heightCtrl.text} sm' : null),
                  row('Hozirgi vazn', _weightCtrl.text.isNotEmpty ? '${_weightCtrl.text} kg' : null),
                  row('Maqsad vazn', _targetWeightCtrl.text.isNotEmpty ? '${_targetWeightCtrl.text} kg' : null),
                ],
              ),
            ),
            SectionCard(
              title: 'Ish va hayot tarzi',
              child: Column(
                children: [
                  row('Ish turi', _workType),
                  row('Ish soati', _workHoursCtrl.text.isNotEmpty ? '${_workHoursCtrl.text} soat' : null),
                  row('Uyqu', _sleepHoursCtrl.text.isNotEmpty ? '${_sleepHoursCtrl.text} soat' : null),
                  row('Suv', _waterCtrl.text.isNotEmpty ? '${_waterCtrl.text} litr' : null),
                ],
              ),
            ),
            SectionCard(
              title: 'Faollik',
              child: Column(
                children: [
                  row('Faollik darajasi', _activityLevel),
                  row('Sport', _doesSport ? 'Ha${_sportTypeCtrl.text.isNotEmpty ? ": ${_sportTypeCtrl.text}" : ""}' : 'Yo\'q'),
                ],
              ),
            ),
            SectionCard(
              title: 'Maqsad va sog\'liq',
              child: Column(
                children: [
                  row('Maqsad', goalLabel()),
                  if (_medicalCtrl.text.isNotEmpty)
                    row('Tibbiy holatlar', _medicalCtrl.text),
                  if (_allergiesCtrl.text.isNotEmpty)
                    row('Allergiya', _allergiesCtrl.text),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
