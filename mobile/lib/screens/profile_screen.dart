import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic> _prs = {'Squat': 0, 'Bench': 0, 'Deadlift': 0};
  List<dynamic> _sessions = [];
  bool _loading = true;
  int _totalSessions = 0;

  // Theme Colors
  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _cardColor = Color(0xFF1E293B);
  static const Color _primaryAccent = Color(0xFF3B82F6);
  static const Color _textHighContrast = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _textDim = Color(0xFF64748B);

  // Editable 1RM controllers
  final _squatRMCtrl = TextEditingController();
  final _benchRMCtrl = TextEditingController();
  final _deadliftRMCtrl = TextEditingController();

  // Body stats
  final _weightCtrl = TextEditingController();

  // Training config
  final _blockCtrl = TextEditingController();
  final _weekCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();

  // Goal Tracker
  final _goalTotalCtrl = TextEditingController();

  // Settings
  bool _useKg = true;
  bool _notificationsEnabled = true;
  String? _weightClass;

  final _classes = [
    '59kg', '66kg', '74kg', '83kg', '93kg', '105kg', '120kg', '120kg+',
    '47kg', '52kg', '57kg', '63kg', '69kg', '76kg', '84kg', '84kg+',
  ];

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadData();
    _loadLocalSettings();
  }

  @override
  void dispose() {
    _squatRMCtrl.dispose();
    _benchRMCtrl.dispose();
    _deadliftRMCtrl.dispose();
    _weightCtrl.dispose();
    _blockCtrl.dispose();
    _weekCtrl.dispose();
    _daysCtrl.dispose();
    _goalTotalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _useKg = prefs.getBool('profile_useKg') ?? true;
        _blockCtrl.text = prefs.getString('profile_block') ?? '';
        _weekCtrl.text = prefs.getString('profile_week') ?? '';
        _daysCtrl.text = prefs.getString('profile_days') ?? '';
        _goalTotalCtrl.text = prefs.getString('profile_goal_total') ?? '600';
        _notificationsEnabled = prefs.getBool('profile_notifications') ?? true;
      });
    }
  }

  Future<void> _saveLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_useKg', _useKg);
    await prefs.setString('profile_block', _blockCtrl.text);
    await prefs.setString('profile_week', _weekCtrl.text);
    await prefs.setString('profile_days', _daysCtrl.text);
    await prefs.setString('profile_goal_total', _goalTotalCtrl.text);
    await prefs.setBool('profile_notifications', _notificationsEnabled);
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_profile');
    if (cached != null) {
      final data = jsonDecode(cached);
      if (mounted) {
        setState(() {
          _profile = data['profile'];
          _prs = data['prs'] ?? _prs;
          _totalSessions = data['total'] ?? 0;
          _sessions = data['sessions'] ?? [];
          _loading = false;
          _fillFields();
        });
      }
    }
  }

  void _fillFields() {
    if (_profile != null) {
      if (_profile!['bodyWeight'] != null) _weightCtrl.text = _profile!['bodyWeight'].toString();
      final wc = _profile!['weightClass'];
      _weightClass = _classes.contains(wc) ? wc : null;
    }
    // Fill 1RM from PRs
    final s = _prs['Squat'];
    final b = _prs['Bench'];
    final d = _prs['Deadlift'];
    if (s != null && s != 0) _squatRMCtrl.text = s.toString().replaceAll('.0', '');
    if (b != null && b != 0) _benchRMCtrl.text = b.toString().replaceAll('.0', '');
    if (d != null && d != 0) _deadliftRMCtrl.text = d.toString().replaceAll('.0', '');
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getProfile(),
        ApiService.getPRs(),
        ApiService.getSessions(),
      ]);
      final profile = results[0] as Map<String, dynamic>;
      final prs = results[1] as Map<String, dynamic>;
      final sessions = results[2] as List<dynamic>;

      // Sort sessions descending by date (newest first)
      sessions.sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_profile', jsonEncode({
        'profile': profile,
        'prs': prs,
        'total': sessions.length,
        'sessions': sessions,
      }));

      if (mounted) {
        setState(() {
          _profile = profile;
          _prs = prs;
          _totalSessions = sessions.length;
          _sessions = sessions;
          _loading = false;
          _fillFields();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final data = <String, dynamic>{};
    if (_weightCtrl.text.isNotEmpty) data['bodyWeight'] = double.tryParse(_weightCtrl.text);
    if (_weightClass != null) data['weightClass'] = _weightClass;
    try {
      final result = await ApiService.updateProfile(data);
      setState(() => _profile = result);
      await _saveLocalSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile saved'),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: AppTheme.accentRed,
        ));
      }
    }
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset All Data', style: TextStyle(color: _textHighContrast, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will clear all cached data on this device. Your server data will remain intact.',
          style: TextStyle(color: _textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('sbd_token');
      await prefs.clear();
      if (token != null) await prefs.setString('sbd_token', token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Local data cleared'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ));
        _loadData();
      }
    }
  }

  String _getStrengthBadge(num total) {
    if (total == 0) return 'Beginner';
    if (total < 350) return 'Beginner';
    if (total < 550) return 'Intermediate';
    return 'Advanced';
  }

  int _calculateConsistency(List<dynamic> sessions) {
    if (sessions.isEmpty) return 0;
    final targetDaysPerWeek = int.tryParse(_daysCtrl.text) ?? 4;
    if (targetDaysPerWeek <= 0) return 0;

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    int actualCount = 0;
    for (var s in sessions) {
      final dateStr = s['date']?.toString();
      if (dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date != null && date.isAfter(thirtyDaysAgo)) {
        actualCount++;
      }
    }

    final targetCount = (targetDaysPerWeek * 30 / 7).round();
    if (targetCount == 0) return 0;
    final pct = ((actualCount / targetCount) * 100).round();
    return pct.clamp(0, 100);
  }

  double _calculateTotalVolume(List<dynamic> sessions) {
    double totalVolume = 0;
    for (var s in sessions) {
      final exercises = s['exercises'] as List? ?? [];
      for (var ex in exercises) {
        final sets = ex['sets'] as List? ?? [];
        for (var set in sets) {
          final w = double.tryParse(set['weight']?.toString() ?? '0') ?? 0;
          final r = int.tryParse(set['reps']?.toString() ?? '0') ?? 0;
          final c = int.tryParse(set['sets']?.toString() ?? '1') ?? 1;
          totalVolume += w * r * c;
        }
      }
    }
    return totalVolume;
  }

  String _getNextWorkout(List<dynamic> sessions) {
    if (sessions.isEmpty) return 'Squat + Bench';
    final latest = sessions.first;
    final exercises = latest['exercises'] as List? ?? [];
    final liftNames = exercises.map((ex) => (ex['name']?.toString() ?? '').toLowerCase()).toList();

    bool trainedSquat = liftNames.any((n) => n.contains('squat'));
    bool trainedBench = liftNames.any((n) => n.contains('bench'));
    bool trainedDeadlift = liftNames.any((n) => n.contains('dead'));

    if (trainedDeadlift) {
      return 'Squat + Bench';
    } else if (trainedSquat && !trainedBench) {
      return 'Bench Press (Primary)';
    } else if (trainedBench && !trainedSquat) {
      return 'Deadlift + Accessories';
    } else {
      return 'Deadlift + Accessories';
    }
  }

  List<PRItem> _calculateRecentPRs(List<dynamic> sessions) {
    final Map<String, PRItem> bestPRs = {};

    for (var s in sessions) {
      final dateStr = s['date']?.toString();
      if (dateStr == null) continue;
      final date = DateTime.tryParse(dateStr) ?? DateTime(2000);

      final exercises = s['exercises'] as List? ?? [];
      for (var ex in exercises) {
        final name = ex['name']?.toString() ?? '';
        String? category;
        if (name.toLowerCase() == 'squat') {
          category = 'Squat';
        } else if (name.toLowerCase() == 'bench' || name.toLowerCase() == 'bench press') {
          category = 'Bench';
        } else if (name.toLowerCase() == 'deadlift') {
          category = 'Deadlift';
        }
        if (category == null) continue;

        final sets = ex['sets'] as List? ?? [];
        for (var set in sets) {
          final w = double.tryParse(set['weight']?.toString() ?? '0') ?? 0;
          final r = int.tryParse(set['reps']?.toString() ?? '0') ?? 0;
          if (w <= 0) continue;

          final existing = bestPRs[category];
          if (existing == null || w > existing.weight) {
            bestPRs[category] = PRItem(lift: category, weight: w, reps: r, date: date);
          } else if (w == existing.weight && date.isAfter(existing.date)) {
            if (r > existing.reps || date.isAfter(existing.date)) {
              bestPRs[category] = PRItem(lift: category, weight: w, reps: r, date: date);
            }
          }
        }
      }
    }

    final list = bestPRs.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final sq = _prs['Squat'] ?? 0;
    final bn = _prs['Bench'] ?? 0;
    final dl = _prs['Deadlift'] ?? 0;
    final total = sq + bn + dl;

    final consistency = _calculateConsistency(_sessions);
    final totalVolume = _calculateTotalVolume(_sessions);
    final nextWorkout = _getNextWorkout(_sessions);
    final prTimeline = _calculateRecentPRs(_sessions);

    final String dayName = DateFormat('EEEE').format(DateTime.now());

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: _primaryAccent,
          backgroundColor: _cardColor,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primaryAccent, strokeWidth: 2))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    // Section 1: Athlete Header
                    _buildAthleteHeader(auth, total),
                    const SizedBox(height: 24),

                    // Section 2: Total Hero Card
                    _buildHeroTotalCard(sq, bn, dl, total),
                    const SizedBox(height: 24),

                    // Section 3: Training Stats Grid
                    _buildTrainingStatsGrid(_totalSessions, consistency, totalVolume),
                    const SizedBox(height: 24),

                    // Section 4: Current Program
                    _buildCurrentProgramCard(
                      _blockCtrl.text,
                      _weekCtrl.text,
                      dayName,
                      nextWorkout,
                    ),
                    const SizedBox(height: 24),

                    // Section 5: Recent PRs
                    _buildRecentPRsTimeline(prTimeline),
                    const SizedBox(height: 24),

                    // Section 6: Goal Tracker
                    _buildGoalTrackerCard(total),
                    const SizedBox(height: 24),

                    // Section 8: Settings
                    _buildSettingsSection(auth),
                  ],
                ),
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildAthleteHeader(AuthService auth, num total) {
    final weightClassStr = _weightClass != null ? '$_weightClass Class' : '— Class';
    final badge = _getStrengthBadge(total);

    Color badgeColor = const Color(0xFF10B981);
    if (badge == 'Beginner') {
      badgeColor = const Color(0xFF3B82F6);
    } else if (badge == 'Advanced') {
      badgeColor = const Color(0xFFF59E0B);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _primaryAccent.withOpacity(0.4),
                _primaryAccent.withOpacity(0.1),
              ],
            ),
            border: Border.all(color: _primaryAccent.withOpacity(0.5), width: 2),
          ),
          child: Center(
            child: Text(
              (auth.username ?? 'U')[0].toUpperCase(),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _textHighContrast),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.username ?? 'Lifter',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textHighContrast, letterSpacing: 0.2),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'Powerlifter',
                    style: TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(color: _textDim, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    weightClassStr,
                    style: const TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
          ),
          child: Text(
            badge,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroTotalCard(num sq, num bn, num dl, num total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Text(
            'TOTAL',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 6),
          Text(
            '${total.toString().replaceAll('.0', '')} kg',
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: _textHighContrast, letterSpacing: -0.5),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroLiftCol('Squat', sq, const Color(0xFFEF4444)),
              _buildHeroLiftCol('Bench', bn, const Color(0xFF3B82F6)),
              _buildHeroLiftCol('Deadlift', dl, const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroLiftCol(String name, num weight, Color accentColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              name.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textMuted, letterSpacing: 0.8),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${weight.toString().replaceAll('.0', '')}kg',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textHighContrast, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildTrainingStatsGrid(int sessionsCompleted, int consistency, double totalVolume) {
    String formattedVolume = '';
    if (totalVolume >= 1000000) {
      formattedVolume = '${(totalVolume / 1000000).toStringAsFixed(1)}M kg';
    } else if (totalVolume >= 1000) {
      formattedVolume = '${(totalVolume / 1000).toStringAsFixed(0)}k kg';
    } else {
      formattedVolume = '${totalVolume.toStringAsFixed(0)} kg';
    }

    return Row(
      children: [
        Expanded(child: _buildStatCard('Sessions', '$sessionsCompleted', Icons.fitness_center)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Consistency', '$consistency%', Icons.insights)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Total Volume', formattedVolume, Icons.fitness_center)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: _primaryAccent),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textHighContrast, fontFamily: 'monospace'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentProgramCard(String block, String week, String day, String nextWorkout) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CURRENT PROGRAM',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 1.2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  day,
                  style: const TextStyle(fontSize: 10, color: _primaryAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildProgramProgressCol('Block', block),
              const SizedBox(width: 32),
              _buildProgramProgressCol('Week', week),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.next_plan_outlined, size: 16, color: _primaryAccent),
              const SizedBox(width: 8),
              const Text(
                'Next Workout: ',
                style: TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: Text(
                  nextWorkout,
                  style: const TextStyle(fontSize: 13, color: _textHighContrast, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgramProgressCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 9, color: _textDim, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value.isNotEmpty ? value : '—',
          style: const TextStyle(fontSize: 18, color: _textHighContrast, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildRecentPRsTimeline(List<PRItem> prs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT PERSONAL RECORDS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 14),
        if (prs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const Center(
              child: Text(
                'No personal records logged yet',
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = prs[index];
                Color badgeColor = const Color(0xFFEF4444);
                if (item.lift == 'Bench') badgeColor = const Color(0xFF3B82F6);
                if (item.lift == 'Deadlift') badgeColor = const Color(0xFFF59E0B);

                final dateStr = DateFormat('MMM d, yyyy').format(item.date);

                return Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.lift} PR',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textHighContrast),
                          ),
                          const SizedBox(height: 2),
                          Text(dateStr, style: const TextStyle(fontSize: 10, color: _textDim)),
                        ],
                      ),
                    ),
                    Text(
                      '${item.weight.toString().replaceAll('.0', '')}kg × ${item.reps}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGoalTrackerCard(num currentTotal) {
    final goalTotal = double.tryParse(_goalTotalCtrl.text) ?? 600;
    final progress = goalTotal > 0 ? (currentTotal / goalTotal).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STRENGTH GOAL TRACKER',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 1.2),
              ),
              GestureDetector(
                onTap: _showEditGoalDialog,
                child: const Row(
                  children: [
                    Text('Edit Goal', style: TextStyle(fontSize: 12, color: _primaryAccent, fontWeight: FontWeight.bold)),
                    SizedBox(width: 2),
                    Icon(Icons.edit, size: 10, color: _primaryAccent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Goal Total', style: TextStyle(fontSize: 14, color: _textMuted, fontWeight: FontWeight.w500)),
              Text(
                '${goalTotal.toString().replaceAll('.0', '')} kg',
                style: const TextStyle(fontSize: 14, color: _textHighContrast, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Total', style: TextStyle(fontSize: 14, color: _textMuted, fontWeight: FontWeight.w500)),
              Text(
                '${currentTotal.toString().replaceAll('.0', '')} kg',
                style: TextStyle(fontSize: 14, color: progress >= 1.0 ? const Color(0xFF10B981) : _primaryAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: _bgColor,
              valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? const Color(0xFF10B981) : _primaryAccent),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${(progress * 100).toStringAsFixed(0)}% of your goal reached',
              style: const TextStyle(fontSize: 11, color: _textDim, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditGoalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Strength Goal', style: TextStyle(color: _textHighContrast, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _goalTotalCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: _textHighContrast, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'e.g., 600',
            suffixText: 'kg',
            suffixStyle: const TextStyle(color: _textMuted),
            filled: true,
            fillColor: _bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('profile_goal_total', _goalTotalCtrl.text);
              setState(() {});
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: _primaryAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SETTINGS & CONTROLS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.edit_note,
                title: 'Edit Training Profile',
                trailing: const Icon(Icons.chevron_right, color: _textDim, size: 18),
                onTap: _showEditProfileSheet,
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.line_weight,
                title: 'Units',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_useKg ? 'KG' : 'LBS', style: const TextStyle(fontSize: 13, color: _primaryAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _useKg,
                      activeColor: _primaryAccent,
                      onChanged: (v) async {
                        setState(() => _useKg = v);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('profile_useKg', v);
                      },
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.dark_mode,
                title: 'Theme',
                trailing: const Text('Dark Navy', style: TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500)),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.notifications_none,
                title: 'Notifications',
                trailing: Switch(
                  value: _notificationsEnabled,
                  activeColor: _primaryAccent,
                  onChanged: (v) async {
                    setState(() => _notificationsEnabled = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('profile_notifications', v);
                  },
                ),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.backup_outlined,
                title: 'Backup & Export Data',
                trailing: const Icon(Icons.chevron_right, color: _textDim, size: 18),
                onTap: _showBackupExportDialog,
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.refresh,
                title: 'Reset Local Data',
                titleColor: const Color(0xFFF59E0B),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFF59E0B), size: 18),
                onTap: _resetData,
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.logout,
                title: 'Logout',
                titleColor: const Color(0xFFEF4444),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFEF4444), size: 18),
                onTap: () => auth.logout(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'SBD Tracker v1.0.0',
            style: TextStyle(fontSize: 11, color: _textDim, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: titleColor ?? _textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14, color: titleColor ?? _textHighContrast, fontWeight: FontWeight.w500),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      child: child,
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: Colors.white.withOpacity(0.05),
    );
  }

  void _showBackupExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Export Workout History', style: TextStyle(color: _textHighContrast, fontWeight: FontWeight.bold)),
        content: const Text(
          'Choose the format you would like to export your training logs. You can share or save it locally.',
          style: TextStyle(color: _textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ExportService.exportToCSV(_sessions);
            },
            child: const Text('CSV Format', style: TextStyle(color: _primaryAccent, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ExportService.exportToPDF(_sessions, _prs);
            },
            child: const Text('PDF Report', style: TextStyle(color: _primaryAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Training Profile',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textHighContrast),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: _textMuted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('ESTIMATED 1RM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    _sheetInputRow('Squat 1RM', _squatRMCtrl, _useKg ? 'kg' : 'lb'),
                    const SizedBox(height: 10),
                    _sheetInputRow('Bench 1RM', _benchRMCtrl, _useKg ? 'kg' : 'lb'),
                    const SizedBox(height: 10),
                    _sheetInputRow('Deadlift 1RM', _deadliftRMCtrl, _useKg ? 'kg' : 'lb'),
                    const SizedBox(height: 20),
                    const Text('CURRENT PROGRAM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _sheetCompactField('Block', _blockCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _sheetCompactField('Week', _weekCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _sheetCompactField('Days/wk', _daysCtrl)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('BODY STATS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _sheetCompactField('Body Weight', _weightCtrl, suffix: _useKg ? 'kg' : 'lb')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Weight Class', style: TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: _bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _weightClass,
                                    isExpanded: true,
                                    dropdownColor: _cardColor,
                                    style: const TextStyle(fontSize: 14, color: _textHighContrast, fontFamily: 'monospace'),
                                    hint: const Text('—', style: TextStyle(color: _textMuted)),
                                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                    onChanged: (v) {
                                      setState(() => _weightClass = v);
                                      setModalState(() {});
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _saveProfile();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text('Save Profile Changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetInputRow(String label, TextEditingController ctrl, String suffix) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(fontSize: 14, color: _textMuted, fontWeight: FontWeight.w500)),
        ),
        SizedBox(
          width: 100,
          height: 38,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 15, color: _textHighContrast, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            decoration: InputDecoration(
              suffixText: ' $suffix',
              suffixStyle: const TextStyle(fontSize: 12, color: _textDim),
              filled: true,
              fillColor: _bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _primaryAccent, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sheetCompactField(String label, TextEditingController ctrl, {String? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14, color: _textHighContrast, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: const TextStyle(fontSize: 11, color: _textDim),
              filled: true,
              fillColor: _bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _primaryAccent, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class PRItem {
  final String lift;
  final double weight;
  final int reps;
  final DateTime date;

  PRItem({required this.lift, required this.weight, required this.reps, required this.date});
}
