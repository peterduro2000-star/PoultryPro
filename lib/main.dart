import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/flock_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/daily_record_provider.dart';
import 'providers/stock_provider.dart';
import 'providers/health_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'services/database_service.dart';
import 'services/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  // Initialize local sqflite
  await DatabaseService().initialize();

  runApp(const PoultryProApp());
}

class PoultryProApp extends StatelessWidget {
  const PoultryProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FlockProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => DailyRecordProvider()),
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => HealthProvider()),
      ],
      child: MaterialApp(
        title: 'Poultry Pro',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor),
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: const MainNavigationScreen(), // Straight to app, no login
      ),
    );
  }
}
