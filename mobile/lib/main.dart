import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_colors.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/offline_queue.dart';
import 'services/local_db.dart';
import 'services/sync_engine.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database (Hive)
  await LocalDB.init();

  // Pre-load SharedPreferences and init ApiService cache
  await ApiService.init();

  // Fire-and-forget: sync any queued offline actions (legacy)
  unawaited(OfflineQueue.syncAll().catchError((_) {}));

  // Start the background sync engine
  SyncEngine.start();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: const SBDApp(),
    ),
  );
}

class SBDApp extends StatelessWidget {
  const SBDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SBD Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.accentBlue,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentBlue,
          secondary: AppColors.accentGreen,
          surface: AppColors.cardBg,
          error: AppColors.accentRed,
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
          iconTheme: IconThemeData(color: AppColors.textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.bg,
          selectedItemColor: AppColors.accentBlue,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.6)),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.borderColor),
          ),
          margin: EdgeInsets.zero,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.loading) {
            return const Scaffold(
              backgroundColor: AppColors.bg,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),
            );
          }
          return auth.isAuthenticated ? const DashboardScreen() : const LoginScreen();
        },
      ),
    );
  }
}

