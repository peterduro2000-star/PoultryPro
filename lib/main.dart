import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/alerts_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/daily_record_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/flock_provider.dart';
import 'providers/license_provider.dart';
import 'providers/health_provider.dart';
import 'providers/stock_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/database_service.dart';
import 'services/supabase_config.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase init — network failure must never kill the app
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase init failed (non-fatal): $e');
  }

  // DB init
  try {
    await DatabaseService().initialize();
  } catch (e) {
    debugPrint('DB init failed: $e');
  }

  runApp(const PoultryProApp());
}

class PoultryProApp extends StatelessWidget {
  const PoultryProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LicenseProvider()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => FlockProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => DailyRecordProvider()),
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => HealthProvider()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()),
      ],
      child: MaterialApp(
        title: 'Poultry Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor),
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: const _AppBootstrap(),
      ),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _bootComplete = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final auth = context.read<AuthProvider>();
      final sync = context.read<SyncService>();
      final license = context.read<LicenseProvider>();

      await auth.checkFirstLaunch();

      await auth.initSession().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Auth init timed out — continuing offline');
        },
      );

      if (auth.isAuthenticated) {
        await license.loadCachedEntitlement();
        sync.startPeriodicSync();
        unawaited(sync.syncNow());
        await license.loadEntitlement();
      } else {
        await license.clearEntitlement();
      }
    } catch (e) {
      debugPrint('Boot error (non-fatal): $e');
    } finally {
      if (mounted) setState(() => _bootComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still booting — show splash instead of white screen
    if (!_bootComplete) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.egg_alt,
                  size: 64,
                  color: AppTheme.primaryColor.withValues(alpha: 0.8)),
              const SizedBox(height: 16),
              Text('Poultry Pro',
                  style: AppTheme.headingMedium
                      .copyWith(color: AppTheme.primaryColor)),
              const SizedBox(height: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isFirstLaunch) {
          return OnboardingScreen(
            onComplete: () => setState(() {}),
          );
        }
        return const MainNavigationScreen();
      },
    );
  }
}

void unawaited(Future<void> future) {}
