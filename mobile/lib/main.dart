import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/sessions_screen.dart';
import 'screens/add_session_screen.dart';
import 'screens/leaderboard_screen.dart';

void main() {
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
          return auth.isAuthenticated ? const MainShell() : const LoginScreen();
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    SessionsScreen(),
    SizedBox(), // placeholder for add
    LeaderboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex == 2 ? 0 : _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.bg800, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) {
            if (idx == 2) {
              // Add session
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSessionScreen()),
              ).then((result) {
                if (result == true) setState(() {});
              });
            } else {
              setState(() => _currentIndex = idx);
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Sessions'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline, size: 30), activeIcon: Icon(Icons.add_circle, size: 30), label: 'Log'),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), activeIcon: Icon(Icons.emoji_events), label: 'Leaderboard'),
          ],
        ),
      ),
      // App bar with user info
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.fitness_center, color: AppTheme.accentRed, size: 16),
            ),
            const SizedBox(width: 10),
            const Text('SBD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        actions: [
          if (auth.username != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.bg800.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(auth.username!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text400)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: AppTheme.text500),
            onPressed: () => auth.logout(),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}
