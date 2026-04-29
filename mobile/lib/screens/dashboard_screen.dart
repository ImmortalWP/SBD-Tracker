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
      } else {
        if (mounted) setState(() {});
      }
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

  String _getInsight() {
    if (_sessions.isEmpty) return "Log a session to track progress";
    if (_sessions.length == 1) return "First session logged. Keep it up!";

    for (final s in _sessions) {
      final exList = s['exercises'] as List? ?? [];
      for (final ex in exList) {
        if (ex['category'] == 'main') {
          final liftName = ex['name'] as String;
          final currentMax = _getMaxWeight(ex);
          
          final previousSessions = _sessions.where((ps) => ps['_id'] != s['_id']).toList();
          for (final ps in previousSessions) {
            final pExList = ps['exercises'] as List? ?? [];
            for (final pEx in pExList) {
              if (pEx['name'] == liftName) {
                final prevMax = _getMaxWeight(pEx);
                if (currentMax > prevMax) {
                  return "$liftName +${(currentMax - prevMax).toStringAsFixed(1).replaceAll('.0', '')}kg from last session";
                } else if (currentMax < prevMax) {
                  return "$liftName ${(currentMax - prevMax).toStringAsFixed(1).replaceAll('.0', '')}kg from last session";
                } else {
                  return "Matched last session's $liftName weight";
                }
              }
            }
          }
        }
      }
    }
    return "Consistent training!";
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
              const SizedBox(height: 6),
              _buildInsight(),
              const SizedBox(height: 48),
              _buildRecentSessions(),
            ],
          ),
        ),
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

  Widget _buildInsight() {
    return Text(
      _getInsight(),
      style: const TextStyle(fontSize: 13, color: AppTheme.text500, fontWeight: FontWeight.w500),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'W$wText $dText',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text500),
                      ),
                      const TextSpan(
                        text: '   ', // Spacing instead of a dot, based on the prompt "W3 D1   Squat / Bench"
                      ),
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
