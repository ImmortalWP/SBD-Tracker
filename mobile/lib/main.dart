import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/offline_queue.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load SharedPreferences and init ApiService cache
  await ApiService.init();

  // Fire-and-forget: sync any queued offline actions
  unawaited(OfflineQueue.syncAll().catchError((_) {}));

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
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.loading) {
            return const Scaffold(
              backgroundColor: AppTheme.bg950,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.accentRed),
              ),
            );
          }
          return auth.isAuthenticated ? const DashboardScreen() : const LoginScreen();
        },
      ),
    );
  }
}
