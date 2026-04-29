import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/offline_queue.dart';
import 'services/draft_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/sessions_screen.dart';
import 'screens/add_session_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/profile_screen.dart';

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
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  void switchTab(int index) {
    if (mounted) {
      setState(() => _currentIndex = index);
    }
  }
  int _pendingSync = 0;
  bool _hasDraft = false;
  Timer? _syncTimer;

  final _screens = const [
    DashboardScreen(),
    SessionsScreen(),
    SizedBox(), // placeholder for add
    AnalyticsScreen(),
    LeaderboardScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkQueue();
    _checkDraft();
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
      _checkDraft();
    }
  }

  Future<void> _checkDraft() async {
    final has = await DraftService.hasDraft();
    if (mounted) setState(() => _hasDraft = has);
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

  // Map bottom nav index to IndexedStack index (skip index 2 = Log button)
  int _mapIndex(int navIndex) {
    if (navIndex < 2) return navIndex;    // 0=Dashboard, 1=Sessions
    if (navIndex == 2) return 0;           // Log opens modal, show Dashboard
    return navIndex - 1;                   // 3->2=Analytics, 4->3=Leaderboard, 5->4=Profile
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
                index: _mapIndex(_currentIndex),
                children: [
                  _screens[0], // Dashboard
                  _screens[1], // Sessions
                  _screens[3], // Analytics
                  _screens[4], // Leaderboard
                  _screens[5], // Profile
                ],
              ),
            ),
            // Draft-in-progress banner
            if (_hasDraft)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddSessionScreen()),
                  ).then((result) {
                    _checkDraft();
                    if (result == true) {
                      _checkQueue();
                      setState(() {});
                    }
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppTheme.accentAmber.withValues(alpha: 0.15),
                      AppTheme.accentRed.withValues(alpha: 0.10),
                    ]),
                    border: const Border(top: BorderSide(color: AppTheme.bg800, width: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentAmber),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Draft in progress',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentAmber),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '— tap to resume',
                        style: TextStyle(fontSize: 12, color: AppTheme.text500),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.accentAmber),
                    ],
                  ),
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
                _checkDraft();
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
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
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
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
