import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/session_card.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
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
    final cached = prefs.getString('cache_sessions');
    if (cached != null) {
      setState(() {
        _sessions = jsonDecode(cached);
        _loading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final sessions = await ApiService.getSessions();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_sessions', jsonEncode(sessions));
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Group sessions by block
  Map<int, List<dynamic>> _groupByBlock() {
    final map = <int, List<dynamic>>{};
    for (final s in _sessions) {
      final block = s['block'] as int;
      map.putIfAbsent(block, () => []).add(s);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByBlock();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Text('Training Log',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text50)),
          const SizedBox(height: 2),
          Text('${_sessions.length} session${_sessions.length != 1 ? 's' : ''} found',
              style: const TextStyle(fontSize: 13, color: AppTheme.text400)),
          const SizedBox(height: 16),

          if (_loading)
            ...List.generate(3, (_) => Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.bg850,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.bg800),
              ),
            ))
          else if (_sessions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Text('📋', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    const Text('No sessions logged yet.', style: TextStyle(color: AppTheme.text400, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...grouped.entries.expand((entry) => [
              // Block header
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Row(
                  children: [
                    Text('Block ${entry.key}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text100)),
                    const SizedBox(width: 12),
                    Expanded(child: Container(height: 1, color: AppTheme.bg800)),
                    const SizedBox(width: 12),
                    Text('${entry.value.length} session${entry.value.length != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.text500)),
                  ],
                ),
              ),
              ...entry.value.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SessionCard(
                  session: s,
                  onDelete: (id) => setState(() => _sessions.removeWhere((s) => s['_id'] == id)),
                  onRefresh: _loadData,
                ),
              )),
            ]),
        ],
      ),
    );
  }
}
