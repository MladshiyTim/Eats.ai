import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/diet_service.dart';
import '../services/push_service.dart';
import 'daily_gate_screen.dart';
import 'dashboard_tab.dart';
import 'food_camera_screen.dart';
import 'log_tab.dart';
import 'plan_tab.dart';
import 'profile_tab.dart';

/// Main app shell with a bottom navigation bar and 4 tabs.
/// Uses [IndexedStack] to preserve tab state when switching.
///
/// On open and on every resume it checks the daily enforcement status and,
/// if the user still owes actions, presents a blocking [DailyGateScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final DietService _dietService = DietService();
  bool _gateOpen = false;

  static const _tabs = [
    DashboardTab(),
    PlanTab(),
    LogTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
      _checkGate();
      // Register for push reminders now that we're authenticated.
      PushService.instance.init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkGate();
    }
  }

  /// Fetches today's status; if the user is locked out, shows the gate.
  /// Fails open on any error so the app is never bricked.
  Future<void> _checkGate() async {
    if (_gateOpen) return;
    try {
      final status = await _dietService.getDailyStatus();
      if (!mounted || !status.locked) return;
      _gateOpen = true;
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => DailyGateScreen(initialStatus: status),
        ),
      );
      _gateOpen = false;
    } catch (_) {
      // ignore — never block the app on a status fetch failure
    }
  }

  Future<void> _openCamera() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FoodCameraScreen()),
    );
    _checkGate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCamera,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Ovqat'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Bosh sahifa',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Reja',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_calendar_outlined),
            selectedIcon: Icon(Icons.edit_calendar),
            label: 'Kunlik',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
