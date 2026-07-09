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
        ChangeNotifierProxyProvider<AuthProvider, LicenseProvider>(
          create: (_) => LicenseProvider(),
          update: (_, auth, license) {
            final effectiveLicense = license ?? LicenseProvider();
            // Anonymous sessions have no entitlement — pass null so the
            // license provider clears to Free instead of loading (and
            // potentially erroring on) an entitlement for an anonymous user.
            final userId = auth.isAnonymous
                ? null
                : Supabase.instance.client.auth.currentUser?.id;
            unawaited(effectiveLicense.refreshForAuth(userId));
            return effectiveLicense;
          },
        ),
        ChangeNotifierProxyProvider<LicenseProvider, SyncService>(
          create: (_) => SyncService(),
          update: (_, license, sync) {
            final effectiveSync = sync ?? SyncService();
            effectiveSync.setLicense(license);
            // Start/stop cloud sync based on the (now loaded) entitlement.
            // Sync only runs for non-anonymous accounts with cloud access.
            effectiveSync.onEntitlementChanged();
            return effectiveSync;
          },
        ),
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
  String? _lastUserId;
  bool _authListenerAttached = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// Resets every data provider and reloads it for the newly authenticated
  /// user. Guarantees that no flock/selection/data from a previous account is
  /// carried into the next one, regardless of how the switch was triggered.
  Future<void> _resetAndReloadForUser() async {
    final flockProvider = context.read<FlockProvider>();
    final financeProvider = context.read<FinanceProvider>();
    final recordProvider = context.read<DailyRecordProvider>();
    final stockProvider = context.read<StockProvider>();
    final healthProvider = context.read<HealthProvider>();
    final alertsProvider = context.read<AlertsProvider>();

    flockProvider.reset();
    financeProvider.reset();
    recordProvider.reset();
    stockProvider.reset();
    healthProvider.reset();
    alertsProvider.reset();

    await flockProvider.loadFlocks();
    if (!mounted) return;
    await financeProvider.loadFarmFinanceData();
    if (!mounted) return;

    final flocks = flockProvider.flocks;
    if (flocks.isNotEmpty) {
      final flockIds = flocks.map((f) => f.id).toList();
      await recordProvider.loadLatestRecords(flockIds);
      await recordProvider.loadMortalityTotals(flockIds);
    }
  }

  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    final newUserId = auth.userId;
    if (newUserId == _lastUserId) return;
    _lastUserId = newUserId;
    if (!mounted) return;
    // Stop and clear sync immediately on any user change. The license graph
    // will re-initialise it (via onEntitlementChanged) only once the new
    // account's entitlement has loaded.
    context.read<SyncService>().stopAndClear();
    // Kicks off a full reset + reload for the new user.
    unawaited(_resetAndReloadForUser());
  }

  Future<void> _boot() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final auth = context.read<AuthProvider>();

      await auth.checkFirstLaunch();

      await auth.initSession().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Auth init timed out — continuing offline');
        },
      );

      debugPrint('Authenticated: ${auth.isAuthenticated}');
      debugPrint('UserId: ${auth.userId}');
      debugPrint(
        'Supabase user: ${Supabase.instance.client.auth.currentUser?.email}',
      );

      // Cloud sync is no longer started here. It is driven by the provider
      // graph (LicenseProvider → SyncService.onEntitlementChanged) so it only
      // initialises after authentication is established and the account's
      // entitlement has been loaded. Anonymous sessions never sync.

      debugPrint("MAIN user after init = ${Supabase.instance.client.auth.currentUser?.id}");
      debugPrint("MAIN email after init = ${Supabase.instance.client.auth.currentUser?.email}");
    } catch (e) {
      debugPrint('Boot error (non-fatal): $e');
    } finally {
      if (mounted) {
        // Record the initial user so the first auth notification (which fires
        // during boot) doesn't trigger a spurious reset/reload.
        final auth = context.read<AuthProvider>();
        _lastUserId = auth.userId;
        if (!_authListenerAttached) {
          auth.addListener(_onAuthChanged);
          _authListenerAttached = true;
        }
        setState(() => _bootComplete = true);
      }
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
