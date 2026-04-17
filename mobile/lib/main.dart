import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/offline_queue.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/sessions_screen.dart';
import 'screens/add_session_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/leaderboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _pendingSync = 0;
  Timer? _syncTimer;

  final _screens = const [
    DashboardScreen(),
    SessionsScreen(),
    SizedBox(), // placeholder for add
    AnalyticsScreen(),
    LeaderboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkQueue();
    // Periodically try to sync
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _trySync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _trySync();
    }
  }

  Future<void> _checkQueue() async {
    final len = await OfflineQueue.getLength();
    if (mounted) setState(() => _pendingSync = len);
  }

  Future<void> _trySync() async {
    final len = await OfflineQueue.getLength();
    if (len > 0) {
      await OfflineQueue.syncAll();
      await _checkQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Offline sync banner
            if (_pendingSync > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.accentAmber.withValues(alpha: 0.15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sync, size: 16, color: AppTheme.accentAmber),
                    const SizedBox(width: 8),
                    Text(
                      '$_pendingSync change${_pendingSync != 1 ? 's' : ''} pending sync',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentAmber),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _trySync,
                      child: const Text('Sync now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentAmber, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex >= 3 ? _currentIndex - 1 : (_currentIndex == 2 ? 0 : _currentIndex),
                children: [
                  _screens[0], // Dashboard
                  _screens[1], // Sessions
                  _screens[3], // Analytics (index 3 in _screens, but 2 in IndexedStack)
                  _screens[4], // Leaderboard (index 4 in _screens, but 3 in IndexedStack)
                ],
              ),
            ),
          ],
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSessionScreen()),
              ).then((result) {
                if (result == true) {
                  _checkQueue();
                  setState(() {});
                }
              });
            } else {
              setState(() => _currentIndex = idx);
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Sessions'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline, size: 30), activeIcon: Icon(Icons.add_circle, size: 30), label: 'Log'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), activeIcon: Icon(Icons.emoji_events), label: 'Board'),
          ],
        ),
      ),
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
