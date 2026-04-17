import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _prs = {'Squat': 0, 'Bench': 0, 'Deadlift': 0};
  Map<String, dynamic>? _analytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadData();
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_analytics');
    if (cached != null) {
      final data = jsonDecode(cached);
      setState(() {
        _prs = data['prs'] ?? _prs;
        _analytics = data['analytics'];
        _loading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([ApiService.getPRs(), ApiService.getAnalytics()]);
      final prs = results[0] as Map<String, dynamic>;
      final analytics = results[1] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_analytics', jsonEncode({'prs': prs, 'analytics': analytics}));
      if (mounted) setState(() { _prs = prs; _analytics = analytics; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatVol(num v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toString();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text50)),
          const SizedBox(height: 2),
          const Text('Track your progress across blocks.', style: TextStyle(fontSize: 13, color: AppTheme.text400)),
          const SizedBox(height: 20),

          // PRs
          const Text('🏆 PERSONAL RECORDS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
          const SizedBox(height: 10),
          _buildPRCards(),
          const SizedBox(height: 24),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.accentRed)))
          else if (_analytics != null) ...[
            // Summary cards
            const Text('📊 OVERVIEW',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
            const SizedBox(height: 10),
            _buildSummaryCards(),
            const SizedBox(height: 24),

            // Volume breakdown
            if (_analytics!['volume'] != null) ...[
              const Text('🏋️ TOTAL VOLUME',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
              const SizedBox(height: 10),
              _buildVolumeCards(),
              const SizedBox(height: 24),
            ],

            // Sessions per block
            if (_analytics!['sessionsPerBlock'] != null && (_analytics!['sessionsPerBlock'] as List).isNotEmpty) ...[
              const Text('📅 SESSIONS PER BLOCK',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
              const SizedBox(height: 10),
              _buildSessionsPerBlock(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPRCards() {
    final lifts = [
      {'name': 'Squat', 'icon': '🦵', 'color': AppTheme.accentRed},
      {'name': 'Bench', 'icon': '💪', 'color': AppTheme.accentBlue},
      {'name': 'Deadlift', 'icon': '🏋️', 'color': AppTheme.accentAmber},
    ];
    return Row(
      children: lifts.map((lift) {
        final name = lift['name'] as String;
        final color = lift['color'] as Color;
        final val = _prs[name] ?? 0;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: lift != lifts.last ? 8 : 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lift['icon'] as String, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text(name, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                Text('${val}kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace')),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCards() {
    final a = _analytics!;
    final totalVol = (a['volume'] as Map<String, dynamic>?)?.values.fold<num>(0, (sum, v) => sum + (v as num)) ?? 0;
    final items = [
      {'label': 'Total Volume', 'value': '${_formatVol(totalVol)} kg', 'icon': '🏋️'},
      {'label': 'Sessions', 'value': '${a['totalSessions'] ?? 0}', 'icon': '📋'},
      {'label': 'Blocks', 'value': '${a['totalBlocks'] ?? 0}', 'icon': '📦'},
      {'label': 'Avg/Block', 'value': (a['totalBlocks'] ?? 0) > 0 ? ((a['totalSessions'] ?? 0) / a['totalBlocks']).toStringAsFixed(1) : '—', 'icon': '📈'},
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.2,
      children: items.map((item) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${item['icon']} ${item['label']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.text500)),
              const SizedBox(height: 4),
              Text(item['value'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.text50)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildVolumeCards() {
    final volume = _analytics!['volume'] as Map<String, dynamic>;
    final maxVol = volume.values.fold<num>(0, (m, v) => (v as num) > m ? v : m);
    final colors = {'Squat': AppTheme.accentRed, 'Bench': AppTheme.accentBlue, 'Deadlift': AppTheme.accentAmber};

    return Column(
      children: volume.entries.map((e) {
        final color = colors[e.key] ?? AppTheme.text400;
        final val = e.value as num;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text200)),
                    Text('${_formatVol(val)} kg', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxVol > 0 ? (val / maxVol).toDouble() : 0,
                    minHeight: 8,
                    backgroundColor: AppTheme.bg800,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionsPerBlock() {
    final blocks = _analytics!['sessionsPerBlock'] as List;
    final maxCount = blocks.fold<num>(0, (m, b) => (b['count'] as num) > m ? b['count'] : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: blocks.map<Widget>((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2)),
                  ),
                  child: Text('Block ${b['_id']}', textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentRed)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxCount > 0 ? ((b['count'] as num) / maxCount).toDouble() : 0,
                      minHeight: 10,
                      backgroundColor: AppTheme.bg800,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.accentAmber),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${b['count']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text300, fontFamily: 'monospace')),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}
