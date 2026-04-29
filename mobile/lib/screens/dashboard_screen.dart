import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/draft_service.dart';
import '../theme/app_theme.dart';
import '../screens/add_session_screen.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _sessions = [];
  Map<String, dynamic> _prs = {'Squat': 0, 'Bench': 0, 'Deadlift': 0};
  bool _loading = true;

  bool _hasDraft = false;
  int _elapsedSeconds = 0;
  Timer? _timerTick;

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
      _elapsedSeconds = draft['elapsedSeconds'] ?? 0;
      final wasRunning = draft['timerRunning'] == true;
      final lastTickStr = draft['lastTickTime'];

      if (wasRunning && lastTickStr != null) {
        final lastTick = DateTime.tryParse(lastTickStr);
        if (lastTick != null) {
          _elapsedSeconds += DateTime.now().difference(lastTick).inSeconds;
        }
        _startTimer();
      } else if (wasRunning) {
        _startTimer();
      }
      
      if (mounted) setState(() {});
    } else {
      _hasDraft = false;
      _timerTick?.cancel();
      if (mounted) setState(() {});
    }
  }

  void _startTimer() {
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  String get _timerDisplay {
    final h = _elapsedSeconds ~/ 3600;
    final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
      
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _prs = prs;
          _loading = false;
        });
      }
      _checkDraft();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _getMaxWeight(Map<String, dynamic> ex) {
    final sets = ex['sets'] as List? ?? [];
    double max = 0;
    for (final st in sets) {
      final w = (st['weight'] as num?)?.toDouble() ?? 0.0;
      if (w > max) max = w;
    }
    return max;
  }

  Widget _buildProgressionSummary() {
    if (_sessions.isEmpty) return const SizedBox();

    final currentBlock = _sessions.first['block'] as int? ?? 1;
    final currentWeek = int.tryParse(_sessions.first['week']?.toString() ?? '1') ?? 1;

    final currentSessions = _sessions.where((s) => s['block'] == currentBlock && int.tryParse(s['week']?.toString() ?? '0') == currentWeek).toList();
    final prevSessions = _sessions.where((s) => s['block'] == currentBlock && int.tryParse(s['week']?.toString() ?? '0') == currentWeek - 1).toList();

    double getTopSet(List sessions, String liftName) {
      double max = 0;
      for (var s in sessions) {
        for (var ex in (s['exercises'] as List? ?? [])) {
          if (ex['name'] == liftName) {
            final m = _getMaxWeight(ex);
            if (m > max) max = m;
          }
        }
      }
      return max;
    }

    double getVolume(List sessions) {
      double vol = 0;
      for (var s in sessions) {
        for (var ex in (s['exercises'] as List? ?? [])) {
          if (['Squat', 'Bench', 'Deadlift'].contains(ex['name'])) {
            for (var set in (ex['sets'] as List? ?? [])) {
              final w = double.tryParse(set['weight']?.toString() ?? '0') ?? 0;
              final r = int.tryParse(set['reps']?.toString() ?? '0') ?? 0;
              final c = int.tryParse(set['sets']?.toString() ?? '1') ?? 1;
              vol += w * r * c;
            }
          }
        }
      }
      return vol;
    }

    final lifts = ['Squat', 'Bench', 'Deadlift'];
    List<Widget> liftRows = [];
    for (var lift in lifts) {
      final cur = getTopSet(currentSessions, lift);
      final prev = getTopSet(prevSessions, lift);
      if (cur == 0) continue;
      
      final allTimePR = double.tryParse(_prs[lift]?.toString() ?? '0') ?? 0;
      final isPR = cur >= allTimePR && cur > 0;
      
      final diff = cur - prev;
      String diffStr = '';
      Color color = AppTheme.text500;
      String icon = '';
      
      if (prev == 0) {
        diffStr = 'Baseline';
      } else if (diff > 0) {
        diffStr = '+${diff.toString().replaceAll('.0', '')}kg';
        color = AppTheme.accentGreen;
        icon = '↑';
      } else if (diff < 0) {
        diffStr = '${diff.toString().replaceAll('.0', '')}kg';
        color = AppTheme.accentRed;
        icon = '↓';
      } else {
        diffStr = 'No change';
      }

      liftRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(width: 80, child: Text(lift, style: const TextStyle(fontSize: 14, color: AppTheme.text400, fontWeight: FontWeight.w500))),
              Text(diffStr, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
              const SizedBox(width: 6),
              if (icon.isNotEmpty) Text(icon, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w700)),
              if (isPR) const Padding(padding: EdgeInsets.only(left: 6), child: Text('🔥', style: TextStyle(fontSize: 14))),
            ],
          ),
        ),
      );
    }

    if (liftRows.isEmpty) return const SizedBox();

    final curVol = getVolume(currentSessions);
    final prevVol = getVolume(prevSessions);
    String volStr = '';
    Color volColor = AppTheme.text500;
    if (prevVol > 0) {
      final pct = ((curVol - prevVol) / prevVol) * 100;
      if (pct > 0) {
        volStr = '+${pct.toStringAsFixed(1)}%';
        volColor = AppTheme.accentGreen;
      } else if (pct < 0) {
        volStr = '${pct.toStringAsFixed(1)}%';
        volColor = AppTheme.accentRed;
      } else {
        volStr = '0%';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('This Week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text100)),
        const SizedBox(height: 12),
        ...liftRows,
        if (volStr.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Volume ', style: TextStyle(fontSize: 14, color: AppTheme.text400, fontWeight: FontWeight.w500)),
              Text(volStr, style: TextStyle(fontSize: 14, color: volColor, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
            ],
          ),
        ],
      ],
    );
  }

  void _openSessionScreen() async {
    final reload = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSessionScreen()));
    if (reload == true) {
      _loadData();
    }
    _checkDraft();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg950,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.accentRed,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            children: [
              _buildHeader(),
              const SizedBox(height: 36),
              _buildPRRow(),
              const SizedBox(height: 16),
              _buildProgressionSummary(),
              _buildCoachInsights(),
              const SizedBox(height: 36),
              _buildRecentSessions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoachInsights() {
    if (_sessions.isEmpty) return const SizedBox();

    final insights = <String>[];

    double getVolume(List sessions) {
      double vol = 0;
      for (var s in sessions) {
        for (var ex in (s['exercises'] as List? ?? [])) {
          if (['Squat', 'Bench', 'Deadlift'].contains(ex['name'])) {
            for (var set in (ex['sets'] as List? ?? [])) {
              final w = double.tryParse(set['weight']?.toString() ?? '0') ?? 0;
              final r = int.tryParse(set['reps']?.toString() ?? '0') ?? 0;
              final c = int.tryParse(set['sets']?.toString() ?? '1') ?? 1;
              vol += w * r * c;
            }
          }
        }
      }
      return vol;
    }
    
    final currentBlock = _sessions.first['block'] as int? ?? 1;
    final currentWeek = int.tryParse(_sessions.first['week']?.toString() ?? '1') ?? 1;
    final currentSessions = _sessions.where((s) => s['block'] == currentBlock && int.tryParse(s['week']?.toString() ?? '0') == currentWeek).toList();
    final prevSessions = _sessions.where((s) => s['block'] == currentBlock && int.tryParse(s['week']?.toString() ?? '0') == currentWeek - 1).toList();

    // 1. Volume Drop
    final curVol = getVolume(currentSessions);
    final prevVol = getVolume(prevSessions);
    if (prevVol > 0) {
      final pct = ((curVol - prevVol) / prevVol) * 100;
      if (pct < -15) {
        insights.add('Volume dropping — risk of plateau');
      }
    }

    // 2. Best Week & Trends
    final lifts = ['Squat', 'Bench', 'Deadlift'];
    for (var lift in lifts) {
      if (insights.length >= 2) break; // Max 2 insights

      final liftSessions = _sessions.where((s) {
        final exs = s['exercises'] as List? ?? [];
        return exs.any((ex) => ex['name'] == lift);
      }).toList();

      if (liftSessions.isNotEmpty) {
        double curMax = 0;
        for (var s in currentSessions) {
          for (var ex in (s['exercises'] as List? ?? [])) {
            if (ex['name'] == lift) {
              final w = _getMaxWeight(ex);
              if (w > curMax) curMax = w;
            }
          }
        }

        if (curMax > 0 && liftSessions.length > currentSessions.length) {
          bool isBest = true;
          final sixWeeksAgoDate = DateTime.now().subtract(const Duration(days: 42));
          for (var s in liftSessions) {
            final dateStr = s['date']?.toString() ?? '';
            final d = DateTime.tryParse(dateStr);
            if (d == null) continue;
            if (d.isBefore(sixWeeksAgoDate)) break;
            
            if (!(s['block'] == currentBlock && int.tryParse(s['week']?.toString() ?? '0') == currentWeek)) {
              for (var ex in (s['exercises'] as List? ?? [])) {
                if (ex['name'] == lift) {
                  final w = _getMaxWeight(ex);
                  if (w >= curMax) {
                    isBest = false;
                    break;
                  }
                }
              }
            }
            if (!isBest) break;
          }
          if (isBest && insights.length < 2) {
            insights.add('Best $lift week in last 6 weeks 🔥');
            continue;
          }
        }

        if (insights.length < 2 && liftSessions.length >= 3) {
          double w1 = 0, w2 = 0, w3 = 0;
          
          for (var ex in (liftSessions[0]['exercises'] as List? ?? [])) {
            if (ex['name'] == lift) w3 = _getMaxWeight(ex);
          }
          for (var ex in (liftSessions[1]['exercises'] as List? ?? [])) {
            if (ex['name'] == lift) w2 = _getMaxWeight(ex);
          }
          for (var ex in (liftSessions[2]['exercises'] as List? ?? [])) {
            if (ex['name'] == lift) w1 = _getMaxWeight(ex);
          }
          
          if (w1 > 0 && w2 > 0 && w3 > 0) {
            if (w1 < w2 && w2 < w3) {
              insights.add('$lift trending up for 3 sessions 📈');
            } else if (w1 > w2 && w2 > w3) {
              insights.add('$lift trending down — check recovery 📉');
            }
          }
        }
      }
    }

    if (insights.isEmpty && currentSessions.length >= 3) {
      insights.add('Consistent training this week. Keep it up!');
    }

    if (insights.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: insights.map((insight) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight,
                  style: const TextStyle(fontSize: 13, color: AppTheme.text500, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildHeader() {
    final auth = context.read<AuthService>();
    final username = auth.username ?? 'Lifter';
    
    final hour = DateTime.now().hour;
    String greeting = 'Good evening';
    if (hour < 12) greeting = 'Good morning';
    else if (hour < 17) greeting = 'Good afternoon';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, $username', style: const TextStyle(fontSize: 16, color: AppTheme.text400, fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        
        if (_hasDraft) ...[
          const Text('Workout in progress', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.text50)),
          const SizedBox(height: 6),
          Text(_timerDisplay, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.accentGreen, fontFamily: 'monospace', letterSpacing: 2)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: AppTheme.bg950,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: _openSessionScreen,
              child: const Text('Continue Workout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          )
        ] else ...[
          const Text('Next Session', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.text50)),
          const SizedBox(height: 6),
          const Text('Ready to train', style: TextStyle(fontSize: 15, color: AppTheme.text500)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.text50,
                foregroundColor: AppTheme.bg950,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: _openSessionScreen,
              child: const Text('Start Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          )
        ],
      ],
    );
  }

  Widget _buildPRRow() {
    final s = _prs['Squat'] ?? 0;
    final b = _prs['Bench'] ?? 0;
    final d = _prs['Deadlift'] ?? 0;
    final total = s + b + d;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        _prText('S', s),
        _prText('B', b),
        _prText('D', d),
        const Text('|', style: TextStyle(color: AppTheme.text600, fontSize: 16, fontWeight: FontWeight.w400)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('Total ', style: TextStyle(fontSize: 13, color: AppTheme.text500, fontWeight: FontWeight.w600)),
            Text('${total}kg', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.text100)),
          ],
        ),
      ],
    );
  }

  Widget _prText(String label, num value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$label ', style: const TextStyle(fontSize: 13, color: AppTheme.text500, fontWeight: FontWeight.w600)),
        Text(value.toString().replaceAll('.0', ''), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.text100)),
      ],
    );
  }
  Widget _buildRecentSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text100)),
        const SizedBox(height: 16),
        
        if (_loading && _sessions.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppTheme.text500, strokeWidth: 2)))
        else if (_sessions.isEmpty)
          const Text('No sessions logged yet.', style: TextStyle(color: AppTheme.text600, fontSize: 14))
        else ..._buildRecentSessionsList()
      ],
    );
  }

  List<Widget> _buildRecentSessionsList() {
    final now = DateTime.now();
    
    final recent = _sessions.where((s) {
      if (s['date'] == null) return false;
      final d = DateTime.tryParse(s['date'].toString());
      if (d == null) return false;
      // Keep sessions from exactly now down to 7 days ago, ignoring time of day differences by just checking the date difference loosely or using isAfter
      // A safe check: difference in days <= 7
      final diff = now.difference(d).inDays;
      return diff >= 0 && diff <= 7;
    }).toList();

    if (recent.isEmpty) {
      return [const Text('No sessions in the last 7 days.', style: TextStyle(color: AppTheme.text600, fontSize: 14))];
    }

    final Map<int, List<dynamic>> grouped = {};
    for (var s in recent) {
      final block = s['block'] as int? ?? 0;
      grouped.putIfAbsent(block, () => []).add(s);
    }

    final Map<String, int> dayOrder = {
      'Sunday': 0, 'Monday': 1, 'Tuesday': 2, 'Wednesday': 3,
      'Thursday': 4, 'Friday': 5, 'Saturday': 6,
    };

    final widgets = <Widget>[];
    for (var entry in grouped.entries) {
      final sessionsInBlock = entry.value;
      sessionsInBlock.sort((a, b) {
        final wa = int.tryParse(a['week']?.toString() ?? '0') ?? 0;
        final wb = int.tryParse(b['week']?.toString() ?? '0') ?? 0;
        if (wa != wb) return wb.compareTo(wa); // descending week

        final da = dayOrder[a['day']?.toString()] ?? 99;
        final db = dayOrder[b['day']?.toString()] ?? 99;
        return da.compareTo(db); // ascending day
      });

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Block ${entry.key}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text100)),
              const SizedBox(height: 6),
              const Divider(color: AppTheme.bg800, height: 1),
            ],
          ),
        ),
      );

      for (var session in sessionsInBlock) {
        final exercises = session['exercises'] as List? ?? [];
        final mainLifts = exercises.where((e) => e['category'] == 'main' || e['category'] == 'secondary').toList();
        
        final liftNames = mainLifts.map((e) => e['name']).join(' / ');
        
        final weights = mainLifts.map((ex) {
          final pct = ex['percentage'];
          final maxW = _getMaxWeight(ex);
          final wStr = '${maxW.toString().replaceAll('.0', '')}kg';
          
          if (pct != null && pct.toString().isNotEmpty && ex['category'] == 'main') {
            return '$pct% • $wStr';
          }
          return wStr;
        }).join(' • ');

        final wText = session['week']?.toString() ?? '-';
        // Format Day safely: if it's a number string like "1", show "D1". If it's "Monday", show "Monday".
        String dText = session['day']?.toString() ?? '-';
        if (int.tryParse(dText) != null) dText = 'D$dText';

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _ExpandableRecentSession(
              session: session,
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'W$wText $dText',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text500),
                        ),
                        const TextSpan(text: '   '),
                        TextSpan(
                          text: liftNames.isEmpty ? 'Accessories only' : liftNames,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text100),
                        ),
                      ],
                    ),
                  ),
                  if (weights.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(weights, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text400, fontFamily: 'monospace')),
                  ],
                ],
              ),
            ),
          ),
        );
      }
    }

    widgets.add(const SizedBox(height: 8));
    widgets.add(
      Center(
        child: TextButton(
          onPressed: () {
            context.findAncestorStateOfType<MainShellState>()?.switchTab(1);
          },
          child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text500)),
        ),
      ),
    );

    return widgets;
  }
}

class _ExpandableRecentSession extends StatefulWidget {
  final Map<String, dynamic> session;
  final Widget header;

  const _ExpandableRecentSession({required this.session, required this.header});

  @override
  State<_ExpandableRecentSession> createState() => _ExpandableRecentSessionState();
}

class _ExpandableRecentSessionState extends State<_ExpandableRecentSession> {
  bool _expanded = false;

  Widget _buildCompactExerciseRow(dynamic ex) {
    final cat = ex['category'];
    Color color = AppTheme.accentGreen;
    if (cat == 'main') color = AppTheme.accentRed;
    else if (cat == 'secondary') color = AppTheme.accentBlue;

    final sets = ex['sets'] as List? ?? [];
    
    final setsDisplay = sets.map((s) {
      final w = s['weight'];
      final r = s['reps'];
      final c = s['sets'] ?? 1;
      final wStr = w.toString().replaceAll('.0', '');
      if (c is int && c > 1 || c is String && int.tryParse(c) != null && int.parse(c) > 1) {
        return '$c × $wStr kg × $r reps';
      }
      return '$wStr kg × $r reps';
    }).join('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ex['name'],
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.3),
            overflow: TextOverflow.ellipsis,
          ),
          if (setsDisplay.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppTheme.bg800, width: 2)),
              ),
              child: Text(
                setsDisplay,
                style: const TextStyle(fontSize: 13, color: AppTheme.text500, fontFamily: 'monospace', height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.session['exercises'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(6),
          child: widget.header,
        ),
        if (_expanded && exercises.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: exercises.map((ex) => _buildCompactExerciseRow(ex)).toList(),
            ),
          ),
      ],
    );
  }
}
