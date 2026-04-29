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

  Map<int, Map<int, List<dynamic>>> _groupSessions() {
    final blocks = <int, Map<int, List<dynamic>>>{};
    for (final s in _sessions) {
      final block = s['block'] as int;
      final weekStr = s['week']?.toString() ?? '1';
      final week = int.tryParse(weekStr) ?? 1;
      
      blocks.putIfAbsent(block, () => {});
      blocks[block]!.putIfAbsent(week, () => []).add(s);
    }
    
    final sortedBlocks = Map.fromEntries(blocks.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
    
    for (final blockKey in sortedBlocks.keys) {
      final weeks = sortedBlocks[blockKey]!;
      sortedBlocks[blockKey] = Map.fromEntries(weeks.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
    }
    
    return sortedBlocks;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupSessions();

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
                ...grouped.entries.map((blockEntry) => _CollapsibleSection(
                  title: 'Block ${blockEntry.key}',
                  level: 0,
                  initialExpanded: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: blockEntry.value.entries.map((weekEntry) => _CollapsibleSection(
                      title: 'Week ${weekEntry.key}',
                      level: 1,
                      initialExpanded: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: weekEntry.value.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: SessionCard(
                            session: s,
                            onDelete: (id) => setState(() => _sessions.removeWhere((s) => s['_id'] == id)),
                            onRefresh: _loadData,
                          ),
                        )).toList(),
                      ),
                    )).toList(),
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final bool initialExpanded;
  final Widget child;
  final int level;
  
  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.initialExpanded = false,
    this.level = 0,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded;
  
  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: widget.level == 0 ? 12 : 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: widget.level == 0 ? 18 : 16,
                      fontWeight: widget.level == 0 ? FontWeight.w700 : FontWeight.w600,
                      color: widget.level == 0 ? AppTheme.text100 : AppTheme.text300,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.text500,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (widget.level == 0) const Divider(color: AppTheme.bg850, height: 1),
        if (_expanded)
          Padding(
            padding: EdgeInsets.only(
              top: widget.level == 0 ? 12 : 8,
              bottom: widget.level == 0 ? 16 : 8,
              left: widget.level == 0 ? 0 : 12,
            ),
            child: widget.child,
          ),
      ],
    );
  }
}
