import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/draft_service.dart';
import '../services/offline_queue.dart';
import '../screens/add_session_screen.dart';
import '../screens/sessions_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/profile_screen.dart';
import '../services/analytics_processor.dart';
import '../theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _sessions = [];
  Map<String, dynamic> _prs = {'Squat': 0, 'Bench': 0, 'Deadlift': 0};

  bool _hasDraft = false;
  String _draftWorkoutName = '';
  int _draftExerciseCount = 0;
  int _draftCompletedSets = 0;
  int _draftTotalSets = 0;
  int _accumulatedSeconds = 0;
  DateTime? _timerStartTime;
  bool _timerRunning = false;
  Timer? _timerTick;

  int _navIndex = 0;
  final Set<int> _visitedTabs = {0};
  int _offlineCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadData();
    _checkDraft();
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    super.dispose();
  }

  Future<void> _checkDraft() async {
    final draft = await DraftService.loadDraft();
    if (draft != null && draft.isNotEmpty) {
      _hasDraft = true;
      _accumulatedSeconds = draft['accumulatedSeconds'] ?? 0;
      _timerRunning = draft['timerRunning'] == true;
      final startTimeStr = draft['timerStartTime'];
      
      if (_timerRunning && startTimeStr != null) {
        _timerStartTime = DateTime.tryParse(startTimeStr);
      } else {
        _timerStartTime = null;
      }

      final exercises = draft['exercises'] as List? ?? [];
      _draftExerciseCount = exercises.where((e) => (e['name'] ?? '').toString().trim().isNotEmpty).length;
      _draftWorkoutName = '';
      _draftCompletedSets = 0;
      _draftTotalSets = 0;
      final liftNames = <String>[];
      for (final ex in exercises) {
        final name = (ex['name'] ?? '').toString().trim();
        if (name.isNotEmpty && !liftNames.contains(name)) liftNames.add(name);
        final sets = ex['sets'] as List? ?? [];
        _draftTotalSets += sets.length;
        for (final s in sets) {
          if (s['isCompleted'] == true) _draftCompletedSets++;
        }
      }
      _draftWorkoutName = liftNames.take(2).join(' + ');

      if (_timerRunning) _startTimer();
      if (mounted) setState(() {});
    } else {
      _hasDraft = false;
      _draftWorkoutName = '';
      if (mounted) setState(() {});
    }
  }

  void _startTimer() {
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_dashboard');
    if (cached != null) {
      final data = jsonDecode(cached);
      if (mounted) {
        setState(() {
          _sessions = data['sessions'] ?? [];
          _prs = data['prs'] ?? _prs;
        });
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getSessions(),
        ApiService.getPRs(),
      ]);
      final sessions = results[0] as List<dynamic>;
      final prs = results[1] as Map<String, dynamic>;
      
      sessions.sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_dashboard', jsonEncode({'sessions': sessions, 'prs': prs}));
      
      final offlineCount = await OfflineQueue.getLength();
      
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _prs = prs;
          _offlineCount = offlineCount;
        });
      }
    } catch (e) {
      final offlineCount = await OfflineQueue.getLength();
      if (mounted) {
        setState(() {
          _offlineCount = offlineCount;
        });
      }
    }
  }

  void _openSessionScreen() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSessionScreen()));
    if (result == true) {
      _loadData();
    }
    _checkDraft();
  }

  Future<void> _syncOfflineData() async {
    setState(() => _isSyncing = true);
    try {
      await OfflineQueue.syncAll();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All sessions synced'),
          backgroundColor: AppColors.accentGreen, behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _navIndex,
              children: List.generate(4, (i) {
                if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
                switch (i) {
                  case 0: return _buildHomeTab();
                  case 1: return SessionsScreen(sessions: _sessions, onRefresh: _loadData, prs: _prs);
                  case 2: return const AnalyticsScreen();
                  case 3: return const ProfileScreen();
                  default: return const SizedBox.shrink();
                }
              }),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accentBlue,
      backgroundColor: AppColors.cardBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xl, Spacing.lg, 100),
        children: [
          _buildHeader(),
          if (_offlineCount > 0) ...[
            const SizedBox(height: Spacing.base),
            _buildOfflineBanner(),
          ],
          const SizedBox(height: Spacing.xl),
          _buildTodayWorkout(),
          const SizedBox(height: Spacing.xl),
          _buildSBDLifts(),
          const SizedBox(height: Spacing.xl),
          _buildWeeklyProgress(),
          const SizedBox(height: Spacing.xl),
          _buildLastSameWeekday(),
        ],
      ),
    );
  }

  // ─── Header ───

  Widget _buildHeader() {
    final auth = context.read<AuthService>();
    final username = auth.username ?? 'Athlete';
    
    final hour = DateTime.now().hour;
    String greeting = 'Good evening';
    if (hour < 12) greeting = 'Good morning';
    else if (hour < 17) greeting = 'Good afternoon';

    final todayDay = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][DateTime.now().weekday - 1];
    int currentWeek = 1;
    String phase = '';
    if (_sessions.isNotEmpty) {
      currentWeek = _sessions.first['week'] ?? 1;
      // Derive phase from block if available
      final block = _sessions.first['block'] ?? 1;
      if (block == 1) phase = 'Hypertrophy';
      else if (block == 2) phase = 'Strength';
      else if (block == 3) phase = 'Peaking';
      else phase = 'Block $block';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $username',
          style: AppTypography.h1,
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          'Week $currentWeek • $todayDay${phase.isNotEmpty ? ' • $phase' : ''}',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }

  // ─── Offline Banner ───

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.base, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: AppColors.accentAmber, size: 18),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              '$_offlineCount session${_offlineCount == 1 ? '' : 's'} pending sync',
              style: AppTypography.bodySmall.copyWith(color: AppColors.accentAmber),
            ),
          ),
          GestureDetector(
            onTap: _isSyncing ? null : _syncOfflineData,
            child: _isSyncing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.accentAmber, strokeWidth: 1.5))
                : Text('Sync', style: AppTypography.bodySmall.copyWith(color: AppColors.accentAmber, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Today's Workout ───

  String _getNextSessionTitle() {
    final todayDay = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][DateTime.now().weekday - 1];
    for (final s in _sessions) {
      if (s['day'] == todayDay) {
        final exercises = s['exercises'] as List? ?? [];
        if (exercises.isNotEmpty) {
          final mainLifts = exercises
              .where((e) => (e['category'] ?? 'main') == 'main')
              .map((e) => e['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
          if (mainLifts.isNotEmpty) return mainLifts.take(2).join(' + ');
          return exercises.first['name']?.toString() ?? '$todayDay Training';
        }
      }
    }
    return '$todayDay Training';
  }

  Widget _buildTodayWorkout() {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _hasDraft ? 'WORKOUT IN PROGRESS' : 'TODAY',
            style: AppTypography.sectionHeader.copyWith(
              color: _hasDraft ? AppColors.accentGreen : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            _hasDraft
                ? (_draftWorkoutName.isNotEmpty ? _draftWorkoutName : 'Workout')
                : _getNextSessionTitle(),
            style: AppTypography.h1,
          ),
          const SizedBox(height: Spacing.sm),
          if (_hasDraft) ...[
            Row(
              children: [
                _DraftTimerDisplay(
                  timerRunning: _timerRunning,
                  timerStartTime: _timerStartTime,
                  accumulatedSeconds: _accumulatedSeconds,
                ),
                const SizedBox(width: Spacing.base),
                Text(
                  '$_draftCompletedSets / $_draftTotalSets sets',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ] else
            _buildTodayMeta(),
          const SizedBox(height: Spacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasDraft ? AppColors.accentGreen : AppColors.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                elevation: 0,
              ),
              onPressed: _openSessionScreen,
              child: Text(
                _hasDraft ? 'Resume Workout' : 'Start Workout',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMeta() {
    final todayDay = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][DateTime.now().weekday - 1];
    int currentWeek = 1;
    if (_sessions.isNotEmpty) {
      currentWeek = _sessions.first['week'] ?? 1;
      final latestDay = _sessions.first['day'] ?? '';
      final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      if (dayOrder.indexOf(todayDay) < dayOrder.indexOf(latestDay)) currentWeek += 1;
    }
    return Text(
      'Week $currentWeek • $todayDay',
      style: AppTypography.bodySmall,
    );
  }

  // ─── SBD Lifts ───

  Widget _buildSBDLifts() {
    final s = _prs['Squat'] ?? 0;
    final b = _prs['Bench'] ?? 0;
    final d = _prs['Deadlift'] ?? 0;
    final total = (s as num) + (b as num) + (d as num);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('YOUR LIFTS', style: AppTypography.sectionHeader),
        const SizedBox(height: Spacing.base),
        Row(
          children: [
            _buildLiftStat('SQUAT', s),
            const SizedBox(width: Spacing.md),
            _buildLiftStat('BENCH', b),
            const SizedBox(width: Spacing.md),
            _buildLiftStat('DEADLIFT', d),
          ],
        ),
        const SizedBox(height: Spacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: Spacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfacePrimary,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Center(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(text: 'TOTAL  ', style: AppTypography.label),
                TextSpan(
                  text: '${total.toString().replaceAll('.0', '')}',
                  style: AppTypography.monoLarge.copyWith(color: AppColors.accentBlueLight),
                ),
                TextSpan(text: ' kg', style: AppTypography.bodySmall),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiftStat(String label, num value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.base, horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          children: [
            Text(label, style: AppTypography.labelSmall),
            const SizedBox(height: Spacing.sm),
            Text(
              value.toString().replaceAll('.0', ''),
              style: AppTypography.monoLarge,
            ),
            Text('kg', style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }

  // ─── Weekly Progress ───

  Widget _buildWeeklyProgress() {
    // Count sessions this week
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    int thisWeekCount = 0;
    for (final s in _sessions) {
      final dt = DateTime.tryParse(s['date']?.toString() ?? '');
      if (dt != null && dt.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
        thisWeekCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('THIS WEEK', style: AppTypography.sectionHeader),
            GestureDetector(
              onTap: () {
                setState(() { _navIndex = 2; _visitedTabs.add(2); });
              },
              child: Text('Details →', style: AppTypography.bodySmall.copyWith(color: AppColors.accentBlueLight)),
            ),
          ],
        ),
        const SizedBox(height: Spacing.base),
        Row(
          children: List.generate(7, (i) {
            final filled = i < thisWeekCount;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 6 ? Spacing.sm : 0),
                height: 6,
                decoration: BoxDecoration(
                  color: filled ? AppColors.accentBlue : AppColors.elevated,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          '$thisWeekCount session${thisWeekCount == 1 ? '' : 's'} this week',
          style: AppTypography.bodySmall,
        ),
        if (_sessions.isNotEmpty) ...[
          const SizedBox(height: Spacing.base),
          _buildProgressTrends(),
        ],
      ],
    );
  }

  Widget _buildProgressTrends() {
    final processor = AnalyticsProcessor(_sessions);
    final progress = processor.getWeeklyProgress(TimeRange.days30);
    if (progress.isEmpty) return const SizedBox();

    return Column(
      children: progress.map((p) {
        final diff = p.change >= 0 ? '+${p.change.toStringAsFixed(1)}' : p.change.toStringAsFixed(1);
        final isPositive = p.change >= 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(p.lift, style: AppTypography.bodyMedium),
              Text(
                '$diff kg',
                style: AppTypography.mono.copyWith(
                  color: isPositive ? AppColors.accentGreen : AppColors.accentRed,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Last Same-Weekday Session ───

  Widget _buildLastSameWeekday() {
    final todayDay = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][DateTime.now().weekday - 1];
    final recent = _sessions.where((s) => s['day'] == todayDay).toList();
    
    if (recent.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST ${todayDay.toUpperCase()}', style: AppTypography.sectionHeader),
          const SizedBox(height: Spacing.md),
          Text('No previous $todayDay session.', style: AppTypography.bodySmall),
        ],
      );
    }

    final session = recent.first;
    final exercises = session['exercises'] as List? ?? [];
    final dateStr = session['date']?.toString();
    String formattedDate = '';
    if (dateStr != null) {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) formattedDate = DateFormat('MMM d').format(dt);
    }

    // Duration
    String dur = '';
    final dMin = session['durationInMinutes'];
    if (dMin != null) {
      final m = int.tryParse(dMin.toString()) ?? 0;
      if (m >= 60) {
        dur = '${m ~/ 60}h ${m % 60}m';
      } else if (m > 0) {
        dur = '${m}m';
      }
    }

    // Main lifts
    final liftNames = exercises
        .where((e) => (e['category'] ?? 'main') == 'main')
        .map((e) => e['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LAST ${todayDay.toUpperCase()}', style: AppTypography.sectionHeader),
            GestureDetector(
              onTap: () { setState(() { _navIndex = 1; _visitedTabs.add(1); }); },
              child: Text('View all →', style: AppTypography.bodySmall.copyWith(color: AppColors.accentBlueLight)),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        Container(
          padding: const EdgeInsets.all(Spacing.base),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (formattedDate.isNotEmpty)
                      Text(formattedDate, style: AppTypography.bodySmall),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      liftNames.isNotEmpty ? liftNames.join(' + ') : 'Training',
                      style: AppTypography.h3,
                    ),
                  ],
                ),
              ),
              if (dur.isNotEmpty)
                Text(dur, style: AppTypography.mono.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Bottom Navigation ───

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            _buildNavItem(0, Icons.home_rounded, 'Home'),
            _buildNavItem(1, Icons.list_alt_rounded, 'Sessions'),
            // Center FAB
            Expanded(
              child: GestureDetector(
                onTap: _openSessionScreen,
                child: Center(
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
            _buildNavItem(2, Icons.bar_chart_rounded, 'Analytics'),
            _buildNavItem(3, Icons.person_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final active = _navIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() { _navIndex = index; _visitedTabs.add(index); });
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? AppColors.accentBlue : AppColors.textMuted, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.accentBlue : AppColors.textMuted,
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Draft Timer Display ───

class _DraftTimerDisplay extends StatefulWidget {
  final bool timerRunning;
  final DateTime? timerStartTime;
  final int accumulatedSeconds;

  const _DraftTimerDisplay({
    required this.timerRunning,
    this.timerStartTime,
    required this.accumulatedSeconds,
  });

  @override
  State<_DraftTimerDisplay> createState() => _DraftTimerDisplayState();
}

class _DraftTimerDisplayState extends State<_DraftTimerDisplay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.timerRunning) _startTick();
  }

  @override
  void didUpdateWidget(_DraftTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timerRunning && !oldWidget.timerRunning) {
      _startTick();
    } else if (!widget.timerRunning && oldWidget.timerRunning) {
      _timer?.cancel();
      if (mounted) setState(() {});
    }
  }

  void _startTick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _currentSeconds {
    if (!widget.timerRunning || widget.timerStartTime == null) return widget.accumulatedSeconds;
    return widget.accumulatedSeconds + DateTime.now().difference(widget.timerStartTime!).inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _currentSeconds;
    final h = seconds ~/ 3600;
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    final display = h > 0 ? '$h:$m:$s' : '$m:$s';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 4),
        Text(display, style: AppTypography.mono.copyWith(color: AppColors.textSecondary, fontSize: 14)),
        if (widget.timerRunning) ...[
          const SizedBox(width: 6),
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle)),
        ],
      ],
    );
  }
}
