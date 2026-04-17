import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/session_card.dart';
import 'dart:convert';
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
      setState(() {
        _sessions = data['sessions'] ?? [];
        _prs = (data['prs'] as Map<String, dynamic>?) ?? _prs;
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final recent = _sessions.take(3).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Training Dashboard',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text50),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_sessions.length} session${_sessions.length != 1 ? 's' : ''} logged',
                    style: const TextStyle(fontSize: 13, color: AppTheme.text400),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // PR Cards
          const Text('Personal Records',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
          const SizedBox(height: 10),
          _buildPRCards(),
          const SizedBox(height: 24),

          // Recent Sessions
          const Text('Recent Sessions',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
          const SizedBox(height: 10),

          if (_loading)
            ...List.generate(3, (_) => _buildSkeleton())
          else if (recent.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Text('🏋️', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    const Text('No sessions logged yet.', style: TextStyle(color: AppTheme.text400, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...recent.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SessionCard(
                session: s,
                onDelete: (id) => setState(() => _sessions.removeWhere((s) => s['_id'] == id)),
                onRefresh: _loadData,
              ),
            )),
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lift['icon'] as String, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 6),
                      Text(name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${val}kg',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bg850,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.bg800),
      ),
    );
  }
}
