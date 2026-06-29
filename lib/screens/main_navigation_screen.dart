import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/sync_service.dart';
import '../screens/backup_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/sync_status_banner.dart';
import 'finance_screen.dart';
import 'health_screen.dart';
import 'home_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    RecordsScreen(),
    FinanceScreen(),
    HealthScreen(),
    StockScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for auth to become ready then show nudge
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleBackupNudge();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<SyncService>().syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleBackupNudge() {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _scheduleBackupNudge();
      });
      return;
    }
    // Show if not yet verified (still anonymous)
    // We show once per app session — banner auto-dismisses if user
    // navigates away, and reappears on next launch until verified.
    if (!auth.isVerified && auth.userId != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _showBackupNudge();
      });
    }
  }

  void _showBackupNudge() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor:
            AppTheme.primaryColor.withValues(alpha: 0.06),
        content: Text(
          'Your data is only on this device — back it up now.',
          style:
              AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
        ),
        leading: Icon(Icons.cloud_off_outlined,
            color: AppTheme.primaryColor, size: 22),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context)
                    .hideCurrentMaterialBanner(),
            child: Text('Later',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .hideCurrentMaterialBanner();
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BackupScreen()),
              );
            },
            child: Text(
              'Secure now',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments),
            label: 'Finance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}