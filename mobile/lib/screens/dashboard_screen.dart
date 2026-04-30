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
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.accentRed,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              _buildGreeting(),
              const SizedBox(height: 24),
              _buildNextSessionCard(),
              _buildSBDStatsCard(),
              _buildProgressionCard(),
              _buildRecentSessionsCard(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final auth = context.read<AuthService>();
    final username = auth.username ?? 'Lifter';
    
    final hour = DateTime.now().hour;
    String greeting = 'Good evening';
    if (hour < 12) greeting = 'Good morning';
    else if (hour < 17) greeting = 'Good afternoon';

    return Text(
      '$greeting, $username 👋',
      style: const TextStyle(fontSize: 16, color: AppTheme.text400, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildNextSessionCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_today_rounded, color: AppTheme.accentRed, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Next Session', style: TextStyle(fontSize: 13, color: AppTheme.text500, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      _hasDraft ? 'Workout in progress' : 'Ready to train',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasDraft) ...[
            const SizedBox(height: 20),
            Center(child: Text(_timerDisplay, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'monospace', letterSpacing: 2))),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              onPressed: _openSessionScreen,
              child: Text(
                _hasDraft ? 'Continue Workout' : 'Start Session',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSBDStatsCard() {
    final s = _prs['Squat'] ?? 0;
    final b = _prs['Bench'] ?? 0;
    final d = _prs['Deadlift'] ?? 0;
    final total = s + b + d;

    return SectionCard(
      title: 'Your Maxes',
      icon: const Icon(Icons.emoji_events_outlined, color: AppTheme.text400, size: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(label: 'Squat', value: s, icon: Icons.fitness_center),
          Container(width: 1, height: 40, color: const Color(0xFF222222)),
          _StatItem(label: 'Bench', value: b, icon: Icons.airline_seat_flat),
          Container(width: 1, height: 40, color: const Color(0xFF222222)),
          _StatItem(label: 'Deadlift', value: d, icon: Icons.accessibility_new),
          Container(width: 1, height: 40, color: const Color(0xFF222222)),
          _StatItem(label: 'Total', value: total, icon: Icons.functions, color: AppTheme.accentAmber),
        ],
      ),
    );
  }

  Widget _buildProgressionCard() {
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

    final curVol = getVolume(currentSessions);
    final prevVol = getVolume(prevSessions);

    return SectionCard(
      title: 'This Week',
      icon: const Icon(Icons.trending_up_rounded, color: AppTheme.text400, size: 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressStat('Squat', getTopSet(currentSessions, 'Squat'), getTopSet(prevSessions, 'Squat'), 'kg'),
              Container(width: 1, height: 40, color: const Color(0xFF222222)),
              _buildProgressStat('Bench', getTopSet(currentSessions, 'Bench'), getTopSet(prevSessions, 'Bench'), 'kg'),
              Container(width: 1, height: 40, color: const Color(0xFF222222)),
              _buildProgressStat('Volume', curVol, prevVol, '%', isPercentage: true),
              Container(width: 1, height: 40, color: const Color(0xFF222222)),
              Expanded(child: _buildInsight(currentSessions, prevSessions, curVol, prevVol)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, double cur, double prev, String unit, {bool isPercentage = false}) {
    if (cur == 0 && prev == 0) return _ProgressItem(label: label, diffStr: '-', color: AppTheme.text500, icon: null);

    final diff = cur - prev;
    String diffStr;
    Color color;
    IconData? icon;

    if (prev == 0) {
      diffStr = '-';
      color = AppTheme.text500;
    } else if (isPercentage) {
      final pct = ((cur - prev) / prev) * 100;
      if (pct > 0) {
        diffStr = '+${pct.toStringAsFixed(1)}%';
        color = AppTheme.accentGreen;
        icon = Icons.arrow_circle_up_rounded;
      } else if (pct < 0) {
        diffStr = '${pct.toStringAsFixed(1)}%';
        color = AppTheme.accentRed;
        icon = Icons.arrow_circle_down_rounded;
      } else {
        diffStr = '0%';
        color = AppTheme.text500;
      }
    } else {
      if (diff > 0) {
        diffStr = '+${diff.toString().replaceAll('.0', '')}$unit';
        color = AppTheme.accentGreen;
        icon = Icons.arrow_circle_up_rounded;
      } else if (diff < 0) {
        diffStr = '${diff.toString().replaceAll('.0', '')}$unit';
        color = AppTheme.accentRed;
        icon = Icons.arrow_circle_down_rounded;
      } else {
        diffStr = '0$unit';
        color = AppTheme.text500;
      }
    }

    return _ProgressItem(label: label, diffStr: diffStr, color: color, icon: icon);
  }

  Widget _buildInsight(List currentSessions, List prevSessions, double curVol, double prevVol) {
    String title = 'Consistent';
    String subtitle = 'Keep it up';
    Color color = AppTheme.text500;
    IconData icon = Icons.check_circle_outline;

    if (prevVol > 0) {
      final pct = ((curVol - prevVol) / prevVol) * 100;
      if (pct < -15) {
        title = 'Volume dropping';
        subtitle = 'Risk of plateau';
        color = AppTheme.accentAmber;
        icon = Icons.warning_amber_rounded;
      } else if (pct > 20) {
        title = 'High volume';
        subtitle = 'Watch recovery';
        color = AppTheme.accentAmber;
        icon = Icons.warning_amber_rounded;
      }
    }

    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.text500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildRecentSessionsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: AppTheme.text400, size: 18),
                const SizedBox(width: 8),
                const Text('Recent Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            GestureDetector(
              onTap: () => context.findAncestorStateOfType<MainShellState>()?.switchTab(1),
              child: const Text('View all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentRed)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading && _sessions.isEmpty)
          const Center(child: CircularProgressIndicator(color: AppTheme.text500, strokeWidth: 2))
        else if (_sessions.isEmpty)
          const Text('No sessions logged yet.', style: TextStyle(color: AppTheme.text600, fontSize: 14))
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF222222)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sessions.length > 5 ? 5 : _sessions.length,
              separatorBuilder: (ctx, idx) => const Divider(color: Color(0xFF222222), height: 1),
              itemBuilder: (ctx, idx) {
                final session = _sessions[idx];
                return _SessionTile(session: session, getMaxWeight: _getMaxWeight);
              },
            ),
          )
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? icon;
  final Widget child;

  const SectionCard({super.key, this.title, this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final num value;
  final IconData icon;
  final Color? color;

  const _StatItem({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color ?? AppTheme.text500),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.text500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value.toString().replaceAll('.0', ''),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 2),
          const Text('kg', style: TextStyle(fontSize: 10, color: AppTheme.text600)),
        ],
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final String label;
  final String diffStr;
  final Color color;
  final IconData? icon;

  const _ProgressItem({required this.label, required this.diffStr, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.text500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                diffStr,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace'),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 14, color: color),
              ]
            ],
          ),
          const SizedBox(height: 6),
          const Text('vs last week', style: TextStyle(fontSize: 10, color: AppTheme.text600)),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final double Function(Map<String, dynamic>) getMaxWeight;

  const _SessionTile({required this.session, required this.getMaxWeight});

  @override
  Widget build(BuildContext context) {
    final exercises = session['exercises'] as List? ?? [];
    final mainLifts = exercises.where((e) => e['category'] == 'main' || e['category'] == 'secondary').toList();
    
    final liftNames = mainLifts.map((e) => e['name']).join(' / ');
    
    final weights = mainLifts.map((ex) {
      final pct = ex['percentage'];
      final maxW = getMaxWeight(ex);
      final wStr = '${maxW.toString().replaceAll('.0', '')}kg';
      
      if (pct != null && pct.toString().isNotEmpty && ex['category'] == 'main') {
        return '$pct% • $wStr';
      }
      return wStr;
    }).join(' • ');

    final wText = session['week']?.toString() ?? '-';
    String dText = session['day']?.toString() ?? '-';
    
    // Fallback simple parsing for day if it's a number string
    if (int.tryParse(dText) != null) dText = 'D$dText';
    // Format day name minimally e.g., "Mon"
    if (dText.length > 3 && int.tryParse(dText) == null) {
      dText = dText.substring(0, 3);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.bg800.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_month_outlined, color: AppTheme.text400, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('W$wText', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text400)),
              const SizedBox(height: 2),
              Text(dText, style: const TextStyle(fontSize: 11, color: AppTheme.text500)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liftNames.isEmpty ? 'Accessories only' : liftNames,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (weights.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    weights,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text500, fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppTheme.text600, size: 20),
        ],
      ),
    );
  }
}
