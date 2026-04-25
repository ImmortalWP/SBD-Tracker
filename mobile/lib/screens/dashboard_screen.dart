import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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
      if (mounted) setState(() { _sessions = sessions; _prs = prs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Group: block → week → sessions
  Map<int, Map<int, List<dynamic>>> _grouped() {
    final Map<int, Map<int, List<dynamic>>> g = {};
    for (final s in _sessions) {
      final b = (s['block'] as num?)?.toInt() ?? 0;
      final w = (s['week'] as num?)?.toInt() ?? 0;
      g.putIfAbsent(b, () => {});
      g[b]!.putIfAbsent(w, () => []);
      g[b]![w]!.add(s);
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    final blocks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Header
          const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.text50)),
          Text('${_sessions.length} sessions logged', style: const TextStyle(fontSize: 13, color: AppTheme.text500)),
          const SizedBox(height: 20),

          // PRs
          const Text('PERSONAL RECORDS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 1)),
          const SizedBox(height: 8),
          _buildPRRow(),
          const SizedBox(height: 8),
          _buildTotalRow(),
          const SizedBox(height: 24),

          // Sessions
          const Text('TRAINING LOG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 1)),
          const SizedBox(height: 10),

          if (_loading)
            ...List.generate(3, (_) => Container(height: 60, margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: AppTheme.bg900, borderRadius: BorderRadius.circular(12))))
          else if (_sessions.isEmpty)
            _emptyState()
          else
            ...blocks.take(3).map((b) => _buildBlock(b, grouped[b]!)),
        ],
      ),
    );
  }

  Widget _buildPRRow() {
    return IntrinsicHeight(
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
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(lift, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            FittedBox(
              fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text('${val}kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow() {
    final total = (_prs['Squat'] ?? 0) + (_prs['Bench'] ?? 0) + (_prs['Deadlift'] ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.bg850, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.bg800)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('SBD Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text400)),
          Text('$total kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildBlock(int block, Map<int, List<dynamic>> weeks) {
    final sortedWeeks = weeks.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.accentRed.withValues(alpha: 0.2), AppTheme.accentAmber.withValues(alpha: 0.1)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('BLOCK $block', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.accentRed, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: AppTheme.bg800)),
          ]),
        ),
        ...sortedWeeks.map((w) => _buildWeek(w, weeks[w]!)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildWeek(int week, List<dynamic> sessions) {
    final dayOrder = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final sorted = [...sessions]..sort((a, b) => dayOrder.indexOf(a['day'] ?? '').compareTo(dayOrder.indexOf(b['day'] ?? '')));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Row(children: [
            Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.accentAmber, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(week == 0 ? 'Unassigned' : 'Week $week',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentAmber)),
          ]),
        ),
        ...sorted.map((s) => _ExpandableSession(session: s, onDelete: () {
          setState(() => _sessions.removeWhere((x) => x['_id'] == s['_id']));
        })),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: AppTheme.bg900, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.bg800)),
      child: const Column(children: [
        Text('🏋️', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('No sessions yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text300)),
        SizedBox(height: 4),
        Text('Tap Log to record your first session', style: TextStyle(fontSize: 13, color: AppTheme.text500)),
      ]),
    );
  }
}

/// Expandable session card — shows summary, tap to expand full details
class _ExpandableSession extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onDelete;
  const _ExpandableSession({required this.session, required this.onDelete});

  @override
  State<_ExpandableSession> createState() => _ExpandableSessionState();
}

class _ExpandableSessionState extends State<_ExpandableSession> {
  bool _expanded = false;

  Map<String, dynamic> get s => widget.session;

  @override
  Widget build(BuildContext context) {
    final exercises = s['exercises'] as List? ?? [];
    final keyLifts = exercises.where((e) => e['category'] == 'main' || e['category'] == 'secondary').toList();
    final accessories = exercises.where((e) => e['category'] != 'main' && e['category'] != 'secondary').toList();

    String? dateStr;
    try { dateStr = DateFormat('MMM d').format(DateTime.parse(s['date'])); } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.bg900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _expanded ? AppTheme.accentAmber.withValues(alpha: 0.2) : AppTheme.bg800),
      ),
      child: Column(children: [
        // Always visible: summary row
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              // Day badge
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(
                  (s['day'] ?? 'N/A').toString().substring(0, 3),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.accentAmber),
                )),
              ),
              const SizedBox(width: 10),
              // Summary text — show main + secondary lifts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keyLifts.map((e) => e['name']).join(' / '),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text100),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (dateStr != null) Text('$dateStr  ', style: const TextStyle(fontSize: 11, color: AppTheme.text500)),
                      if (accessories.isNotEmpty) Text('+ ${accessories.length} accessory', style: const TextStyle(fontSize: 11, color: AppTheme.text600)),
                    ]),
                  ],
                ),
              ),
              // Quick weight summary — show HIGHEST weight per exercise (main, secondary & accessories)
              ...exercises.map((ex) {
                final sets = (ex['sets'] as List? ?? []);
                if (sets.isEmpty) return const SizedBox();
                final maxWeight = sets.fold<num>(0, (max, s) => ((s['weight'] as num?) ?? 0) > max ? (s['weight'] as num) : max);
                if (maxWeight <= 0) return const SizedBox();
                final color = ex['category'] == 'main' ? AppTheme.accentRed
                    : ex['category'] == 'secondary' ? AppTheme.accentBlue
                    : AppTheme.accentGreen;
                return Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text('${maxWeight}kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
                );
              }),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppTheme.text600),
            ]),
          ),
        ),

        // Expanded details
        if (_expanded) ...[
          const Divider(height: 1, color: AppTheme.bg800),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // All exercises with full set details
                ...exercises.map((ex) {
                  final color = ex['category'] == 'main' ? AppTheme.accentRed
                      : ex['category'] == 'secondary' ? AppTheme.accentBlue
                      : AppTheme.accentGreen;
                  final sets = ex['sets'] as List? ?? [];
                  final pct = ex['percentage'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 3, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text(ex['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                        if (pct != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text('$pct%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 6),
                      // Sets in a readable grid
                      Wrap(spacing: 6, runSpacing: 4, children: sets.map<Widget>((st) {
                        final w = st['weight'];
                        final r = st['reps'];
                        final n = st['sets'] ?? 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withValues(alpha: 0.12)),
                          ),
                          child: Column(children: [
                            Text('$w kg', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
                            Text(n > 1 ? '$n×$r reps' : '$r reps',
                                style: const TextStyle(fontSize: 11, color: AppTheme.text500)),
                          ]),
                        );
                      }).toList()),
                    ]),
                  );
                }),

                // Notes
                if (s['notes'] != null && (s['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.notes, size: 13, color: AppTheme.text500),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s['notes'], style: const TextStyle(fontSize: 12, color: AppTheme.text500, fontStyle: FontStyle.italic))),
                  ]),
                ],

                // Delete button
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_outline, size: 14, color: AppTheme.accentRed),
                        SizedBox(width: 4),
                        Text('Delete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentRed)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
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
    if (ok == true) {
      try { await ApiService.deleteSession(s['_id']); } catch (_) {}
      widget.onDelete();
    }
  }
}
