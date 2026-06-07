import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/section_card.dart';
import 'login_screen.dart';
import 'questionnaire_screen.dart';

/// Profile tab — shows user info, edit profile, and logout.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final user = auth.currentUser;
    final profile = profileProvider.profile;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profileProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Avatar + name
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          _initials(profile?.fullName ?? user?.displayName ?? '?'),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile?.fullName ??
                            user?.displayName ??
                            'Foydalanuvchi',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (user?.email != null && user!.email.isNotEmpty)
                        Text(
                          user.email,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Profile details card
                if (profile != null)
                  SectionCard(
                    title: 'Shaxsiy ma\'lumotlar',
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Yosh',
                          value: profile.age != null
                              ? '${profile.age} yosh'
                              : null,
                        ),
                        _InfoRow(
                          label: 'Jins',
                          value: _genderLabel(profile.gender),
                        ),
                        _InfoRow(
                          label: 'Bo\'y',
                          value: profile.heightCm != null
                              ? '${profile.heightCm!.toStringAsFixed(0)} sm'
                              : null,
                        ),
                        _InfoRow(
                          label: 'Hozirgi vazn',
                          value: profile.weightKg != null
                              ? '${profile.weightKg!.toStringAsFixed(1)} kg'
                              : null,
                        ),
                        _InfoRow(
                          label: 'Maqsad vazn',
                          value: profile.targetWeightKg != null
                              ? '${profile.targetWeightKg!.toStringAsFixed(1)} kg'
                              : null,
                        ),
                        _InfoRow(
                          label: 'Maqsad',
                          value: _goalLabel(profile.goal),
                        ),
                        _InfoRow(
                          label: 'Faollik',
                          value: _activityLabel(profile.activityLevel),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SectionCard(
                    child: Column(
                      children: [
                        Icon(Icons.person_add_outlined,
                            size: 40, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Profilingiz to\'ldirilmagan',
                          style:
                              TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Edit profile button
                FilledButton.tonal(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuestionnaireScreen(
                          existingProfile: profile,
                        ),
                      ),
                    );
                    if (context.mounted) {
                      context.read<ProfileProvider>().loadProfile();
                    }
                  },
                  child: const Text('Profilni tahrirlash'),
                ),
                const SizedBox(height: 8),

                // Logout button
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Chiqish'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String? _genderLabel(String? gender) {
    switch (gender) {
      case 'M':
        return 'Erkak';
      case 'F':
        return 'Ayol';
      default:
        return null;
    }
  }

  String? _goalLabel(String? goal) {
    switch (goal) {
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

  String? _activityLabel(String? level) {
    switch (level) {
      case 'sedentary':
        return 'Harakatsiz';
      case 'light':
        return 'Yengil';
      case 'moderate':
        return 'O\'rtacha';
      case 'active':
        return 'Faol';
      case 'very_active':
        return 'Juda faol';
      default:
        return null;
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chiqish'),
        content: const Text('Hisobingizdan chiqmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              context.read<ProfileProvider>().clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
