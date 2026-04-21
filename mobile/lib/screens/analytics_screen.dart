import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _prs = {'Squat': 0, 'Bench': 0, 'Deadlift': 0};
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadData();
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_analytics2');
    if (cached != null) {
      final data = jsonDecode(cached);
      if (mounted) setState(() { _prs = data['prs'] ?? _prs; _sessions = data['sessions'] ?? []; _loading = false; });
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([ApiService.getPRs(), ApiService.getSessions()]);
      final prs = results[0] as Map<String, dynamic>;
      final sessions = results[1] as List<dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_analytics2', jsonEncode({'prs': prs, 'sessions': sessions}));
      if (mounted) setState(() { _prs = prs; _sessions = sessions; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = (_prs['Squat'] ?? 0) + (_prs['Bench'] ?? 0) + (_prs['Deadlift'] ?? 0);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          const Text('Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.text50)),
          const SizedBox(height: 20),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.accentRed)))
          else ...[
            // SBD Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.accentRed.withValues(alpha: 0.1), AppTheme.accentAmber.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                const Text('SBD TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('$total kg', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace')),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _miniPR('S', _prs['Squat'] ?? 0, AppTheme.accentRed),
                  const SizedBox(width: 16),
                  _miniPR('B', _prs['Bench'] ?? 0, AppTheme.accentBlue),
                  const SizedBox(width: 16),
                  _miniPR('D', _prs['Deadlift'] ?? 0, AppTheme.accentAmber),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // Quick stats
            Row(children: [
              _statCard('Sessions', '${_sessions.length}', Icons.fitness_center),
              const SizedBox(width: 8),
              _statCard('Blocks', '${_sessions.map((s) => s['block']).toSet().length}', Icons.layers),
            ]),
            const SizedBox(height: 20),

            // Volume per block chart
            if (_sessions.isNotEmpty) ...[
              const Text('VOLUME BY BLOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 1)),
              const SizedBox(height: 10),
              _buildVolumeChart(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _miniPR(String label, num val, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      Text('$val', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.bg900, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.bg800)),
        child: Row(children: [
          Icon(icon, size: 18, color: AppTheme.text500),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.text500)),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.text100, fontFamily: 'monospace')),
          ]),
        ]),
      ),
    );
  }

  Widget _buildVolumeChart() {
    final Map<int, Map<String, num>> blockVols = {};
    for (final s in _sessions) {
      final block = (s['block'] as num?)?.toInt() ?? 0;
      blockVols.putIfAbsent(block, () => {'Squat': 0, 'Bench': 0, 'Deadlift': 0});
      for (final ex in (s['exercises'] as List? ?? [])) {
        final name = (ex['name'] as String? ?? '').toLowerCase();
        for (final set in (ex['sets'] as List? ?? [])) {
          final vol = ((set['weight'] as num?) ?? 0) * ((set['reps'] as num?) ?? 0) * ((set['sets'] as num?) ?? 1);
          if (name.contains('squat')) blockVols[block]!['Squat'] = blockVols[block]!['Squat']! + vol;
          else if (name.contains('bench') || name.contains('larsen')) blockVols[block]!['Bench'] = blockVols[block]!['Bench']! + vol;
          else if (name.contains('dead') || name.contains('rdl')) blockVols[block]!['Deadlift'] = blockVols[block]!['Deadlift']! + vol;
        }
      }
    }
    if (blockVols.isEmpty) return const SizedBox();

    final sorted = blockVols.keys.toList()..sort();
    final maxVol = blockVols.values.expand((m) => m.values).fold<num>(0, (a, b) => math.max(a, b));
    final colors = {'Squat': AppTheme.accentRed, 'Bench': AppTheme.accentBlue, 'Deadlift': AppTheme.accentAmber};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.bg900, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.bg800)),
      child: Column(children: [
        // Legend
        Row(mainAxisAlignment: MainAxisAlignment.center, children: colors.entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text(e.key, style: const TextStyle(fontSize: 10, color: AppTheme.text500)),
          ]),
        )).toList()),
        const SizedBox(height: 14),
        // Bars
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: sorted.map((block) {
              final vols = blockVols[block]!;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Expanded(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: ['Squat', 'Bench', 'Deadlift'].map((lift) {
                        final h = maxVol > 0 ? ((vols[lift] ?? 0) / maxVol) : 0.0;
                        return Expanded(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: FractionallySizedBox(
                            heightFactor: h.toDouble().clamp(0.02, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: Container(decoration: BoxDecoration(color: colors[lift]!, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
                          ),
                        ));
                      }).toList()),
                    ),
                    const SizedBox(height: 4),
                    Text('B$block', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.text500)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}
