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
      
      // Sort globally by date descending
      sessions.sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_sessions', jsonEncode(sessions));
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<int, List<dynamic>> _groupByBlock() {
    final map = <int, List<dynamic>>{};
    for (final s in _sessions) {
      final block = s['block'] as int;
      map.putIfAbsent(block, () => []).add(s);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.key.compareTo(a.key))); // sort blocks descending
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByBlock();

    return Scaffold(
      backgroundColor: AppTheme.bg950,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.accentRed,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            children: [
              const Text('Training Log', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.text50)),
              const SizedBox(height: 6),
              Text('${_sessions.length} session${_sessions.length != 1 ? 's' : ''} found',
                  style: const TextStyle(fontSize: 14, color: AppTheme.text500)),
              const SizedBox(height: 24),

              if (_loading && _sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.text500, strokeWidth: 2)),
                )
              else if (_sessions.isEmpty)
                const Text('No sessions logged yet.', style: TextStyle(color: AppTheme.text500, fontSize: 14))
              else
                ...grouped.entries.expand((entry) => [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Block ${entry.key}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text100)),
                        const SizedBox(height: 8),
                        const Divider(color: AppTheme.bg850, height: 1),
                      ],
                    ),
                  ),
                  ...entry.value.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: SessionCard(
                      session: s,
                      onDelete: (id) => setState(() => _sessions.removeWhere((s) => s['_id'] == id)),
                      onRefresh: _loadData,
                    ),
                  )),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
