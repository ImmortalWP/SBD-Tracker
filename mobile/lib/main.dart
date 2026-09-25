import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Set system UI overlay style for immersive dark theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

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
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
          iconTheme: IconThemeData(color: AppColors.textSecondary, size: 20),
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
            borderRadius: BorderRadius.circular(Radii.md),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            borderSide: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.6)),
          ),
          labelStyle: AppTypography.label,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            elevation: 0,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            side: const BorderSide(color: AppColors.borderColor, width: 0.5),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderColor,
          thickness: 0.5,
          space: 0,
        ),
        splashColor: AppColors.accentBlue.withValues(alpha: 0.08),
        highlightColor: AppColors.accentBlue.withValues(alpha: 0.04),
      ),
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.loading) {
            return const Scaffold(
              backgroundColor: AppColors.bg,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue, strokeWidth: 2),
              ),
            );
          }
          return auth.isAuthenticated ? const DashboardScreen() : const LoginScreen();
        },
      ),
    );
  }
}
