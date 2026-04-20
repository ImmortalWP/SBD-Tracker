import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/session_card.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _sessions = [];
  Map<String, dynamic> _prs = {'Squat': 0, 'Bench': 0, 'Deadlift': 0};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadData();
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_dashboard');
    if (cached != null) {
      final data = jsonDecode(cached);
      if (mounted) {
        setState(() {
          _sessions = data['sessions'] ?? [];
          _prs = (data['prs'] as Map<String, dynamic>?) ?? _prs;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([ApiService.getSessions(), ApiService.getPRs()]);
      final sessions = results[0] as List<dynamic>;
      final prs = results[1] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_dashboard', jsonEncode({'sessions': sessions, 'prs': prs}));
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _prs = prs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Group sessions by block → week → day
  Map<int, Map<int, List<dynamic>>> _groupByBlockWeek() {
    final Map<int, Map<int, List<dynamic>>> grouped = {};
    for (final s in _sessions) {
      final block = (s['block'] as num?)?.toInt() ?? 0;
      final week = (s['week'] as num?)?.toInt() ?? 0;
      grouped.putIfAbsent(block, () => {});
      grouped[block]!.putIfAbsent(week, () => []);
      grouped[block]![week]!.add(s);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByBlockWeek();
    final sortedBlocks = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // newest block first

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.text50)),
                  Text(
                    '${_sessions.length} session${_sessions.length != 1 ? 's' : ''} logged',
                    style: const TextStyle(fontSize: 13, color: AppTheme.text500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.fitness_center, size: 14, color: AppTheme.accentRed),
                    SizedBox(width: 6),
                    Text('SBD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.accentRed)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // PR Cards
          _buildPRSection(),
          const SizedBox(height: 24),

          // Session history grouped by block/week
          if (_loading)
            ..._buildSkeletons()
          else if (_sessions.isEmpty)
            _buildEmpty()
          else
            ...sortedBlocks.take(2).map((block) => _buildBlockSection(block, grouped[block]!)),
        ],
      ),
    );
  }

  Widget _buildPRSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PERSONAL RECORDS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 1)),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _prCard('Squat', '🦵', AppTheme.accentRed),
              const SizedBox(width: 8),
              _prCard('Bench', '💪', AppTheme.accentBlue),
              const SizedBox(width: 8),
              _prCard('Deadlift', '🏋️', AppTheme.accentAmber),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.bg850,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.bg800),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total (S+B+D)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text400)),
              Text(
                '${(_prs['Squat'] ?? 0) + (_prs['Bench'] ?? 0) + (_prs['Deadlift'] ?? 0)} kg',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _prCard(String lift, String emoji, Color color) {
    final val = _prs[lift] ?? 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(lift, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${val}kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockSection(int block, Map<int, List<dynamic>> weeks) {
    final sortedWeeks = weeks.keys.toList()..sort((a, b) => b.compareTo(a)); // newest week first

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Block header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.accentRed.withValues(alpha: 0.2), AppTheme.accentAmber.withValues(alpha: 0.1)]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                ),
                child: Text('BLOCK $block', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.accentRed, letterSpacing: 1)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: AppTheme.bg800)),
            ],
          ),
        ),

        ...sortedWeeks.map((week) => _buildWeekSection(block, week, weeks[week]!)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWeekSection(int block, int week, List<dynamic> sessions) {
    // Sort sessions by day order
    final dayOrder = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final sorted = [...sessions]..sort((a, b) {
      final ai = dayOrder.indexOf(a['day'] ?? '');
      final bi = dayOrder.indexOf(b['day'] ?? '');
      return ai.compareTo(bi);
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 4, height: 16,
                  decoration: BoxDecoration(color: AppTheme.accentAmber, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Text(
                  week == 0 ? 'Unassigned' : 'Week $week',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentAmber),
                ),
                const SizedBox(width: 8),
                Text('${sessions.length} session${sessions.length != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.text500)),
              ],
            ),
          ),

          // Sessions as compact cards
          ...sorted.map((s) => _buildCompactSessionCard(s)),
        ],
      ),
    );
  }

  Widget _buildCompactSessionCard(Map<String, dynamic> s) {
    final exercises = s['exercises'] as List? ?? [];
    final mainLifts = exercises.where((e) => e['category'] == 'main').toList();

    String? dateStr;
    try {
      dateStr = DateFormat('MMM d').format(DateTime.parse(s['date']));
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.bg900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.bg800),
      ),
      child: Column(
        children: [
          // Top row: Day + date + block/week badges
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                // Day of week - big and clear
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    s['day'] ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accentAmber),
                  ),
                ),
                const SizedBox(width: 8),
                if (dateStr != null) Text(dateStr, style: const TextStyle(fontSize: 12, color: AppTheme.text500)),
                const Spacer(),
                // Edit/delete via popup
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.text600),
                  color: AppTheme.bg850,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (v) {
                    if (v == 'delete') _confirmDelete(s);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'delete', child: Row(children: [
                      Icon(Icons.delete_outline, size: 16, color: AppTheme.accentRed),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppTheme.accentRed, fontSize: 13)),
                    ])),
                  ],
                ),
              ],
            ),
          ),

          // Main lifts — each on its own row, big and scannable
          if (mainLifts.isEmpty && exercises.isNotEmpty)
            _buildExerciseRow(exercises.first, AppTheme.accentGreen)
          else
            ...mainLifts.map((ex) => _buildExerciseRow(ex, AppTheme.accentRed)),

          // Accessories count
          if (exercises.length > mainLifts.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                '+ ${exercises.length - mainLifts.length} accessory exercise${exercises.length - mainLifts.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: AppTheme.text600),
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(Map<String, dynamic> ex, Color color) {
    final sets = ex['sets'] as List? ?? [];
    final pct = ex['percentage'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Color dot
          Container(width: 3, height: 30, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          // Lift name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(ex['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text100)),
                    if (pct != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('$pct%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Sets summary — clear and readable
          Wrap(
            spacing: 4,
            children: sets.map<Widget>((s) {
              final w = s['weight'];
              final r = s['reps'];
              final st = s['sets'] ?? 1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Text(
                  st > 1 ? '${w}kg  $st×$r' : '${w}kg  ×$r',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace'),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg850,
        title: const Text('Delete Session?'),
        content: const Text('This cannot be undone.', style: TextStyle(color: AppTheme.text400)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppTheme.accentRed))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteSession(s['_id']);
        setState(() => _sessions.removeWhere((x) => x['_id'] == s['_id']));
      } catch (_) {}
    }
  }

  Widget _buildEmpty() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.bg900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.bg800),
      ),
      child: Column(
        children: [
          const Text('🏋️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('No sessions yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text300)),
          const SizedBox(height: 4),
          const Text('Tap Log to record your first session', style: TextStyle(fontSize: 13, color: AppTheme.text500)),
        ],
      ),
    );
  }

  List<Widget> _buildSkeletons() {
    return List.generate(3, (i) => Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bg900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.bg800),
      ),
    ));
  }
}
