import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic> _prs = {'Squat': 0, 'Bench': 0, 'Deadlift': 0};
  bool _loading = true;
  int _totalSessions = 0;

  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String? _weightClass;

  final _weightClasses = [
    '59kg', '66kg', '74kg', '83kg', '93kg', '105kg', '120kg', '120kg+',
    '47kg', '52kg', '57kg', '63kg', '69kg', '76kg', '84kg', '84kg+',
  ];

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadData();
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_profile');
    if (cached != null) {
      final data = jsonDecode(cached);
      setState(() {
        _profile = data['profile'];
        _prs = data['prs'] ?? _prs;
        _totalSessions = data['totalSessions'] ?? 0;
        _loading = false;
        _populateFields();
      });
    }
  }

  void _populateFields() {
    if (_profile != null) {
      if (_profile!['bodyWeight'] != null) _weightCtrl.text = _profile!['bodyWeight'].toString();
      if (_profile!['height'] != null) _heightCtrl.text = _profile!['height'].toString();
      _weightClass = _profile!['weightClass'];
    }
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_profile', jsonEncode({
        'profile': profile, 'prs': prs, 'totalSessions': sessions.length,
      }));

      if (mounted) {
        setState(() {
          _profile = profile;
          _prs = prs;
          _totalSessions = sessions.length;
          _loading = false;
          _populateFields();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final data = <String, dynamic>{};
    if (_weightCtrl.text.isNotEmpty) data['bodyWeight'] = double.parse(_weightCtrl.text);
    if (_heightCtrl.text.isNotEmpty) data['height'] = double.parse(_heightCtrl.text);
    if (_weightClass != null) data['weightClass'] = _weightClass;

    try {
      final result = await ApiService.updateProfile(data);
      setState(() => _profile = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final total = (_prs['Squat'] ?? 0) + (_prs['Bench'] ?? 0) + (_prs['Deadlift'] ?? 0);
    final bw = _profile?['bodyWeight'];
    final wilks = bw != null && bw > 0 && total > 0 ? (total * _wilksCoeff(bw.toDouble())).toStringAsFixed(1) : null;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.accentRed.withValues(alpha: 0.3), AppTheme.accentAmber.withValues(alpha: 0.3)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      (auth.username ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.text50),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  auth.username?.toUpperCase() ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.text50, letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  'Powerlifter${_weightClass != null ? ' · $_weightClass' : ''}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.text500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats row - always 4 cards, same size
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [
              _statBox('Total', '${total}kg', AppTheme.accentRed),
              _statBox('Sessions', '$_totalSessions', AppTheme.accentBlue),
              _statBox('BW', bw != null ? '${bw}kg' : '—', AppTheme.accentAmber),
              _statBox('Wilks', wilks ?? '—', AppTheme.accentGreen),
            ],
          ),
          const SizedBox(height: 24),

          // PR Summary
          const Text('🏆 PERSONAL RECORDS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...['Squat', 'Bench', 'Deadlift'].map((lift) {
            final colors = {'Squat': AppTheme.accentRed, 'Bench': AppTheme.accentBlue, 'Deadlift': AppTheme.accentAmber};
            final icons = {'Squat': '🦵', 'Bench': '💪', 'Deadlift': '🏋️'};
            final val = _prs[lift] ?? 0;
            final color = colors[lift]!;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Text(icons[lift]!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(lift, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text200))),
                  Text('$val', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
                  Text(' kg', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7))),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),

          // Body stats
          const Text('⚖️ BODY STATS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'BODY WEIGHT (kg)', suffixText: 'kg'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'HEIGHT (cm)', suffixText: 'cm'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _weightClass,
                    decoration: const InputDecoration(labelText: 'WEIGHT CLASS'),
                    dropdownColor: AppTheme.bg900,
                    items: _weightClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _weightClass = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('SAVE PROFILE'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Weight history
          if (_profile?['weightHistory'] != null && (_profile!['weightHistory'] as List).isNotEmpty) ...[
            const Text('📈 WEIGHT HISTORY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: (_profile!['weightHistory'] as List).reversed.take(10).map<Widget>((entry) {
                    String dateStr = '';
                    try {
                      dateStr = DateFormat('MMM d, yyyy').format(DateTime.parse(entry['date']));
                    } catch (_) {}
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentAmber),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(dateStr, style: const TextStyle(fontSize: 13, color: AppTheme.text400))),
                          Text('${entry['weight']} kg',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text100, fontFamily: 'monospace')),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          // Logout
          OutlinedButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout, size: 18, color: AppTheme.accentRed),
            label: const Text('LOGOUT', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.accentRed),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.text500)),
        ],
      ),
    );
  }

  // Simplified Wilks coefficient approximation (male)
  double _wilksCoeff(double bw) {
    const a = -216.0475144;
    const b = 16.2606339;
    const c = -0.002388645;
    const d = -0.00113732;
    const e = 7.01863E-06;
    const f = -1.291E-08;
    final denom = a + b * bw + c * bw * bw + d * bw * bw * bw + e * bw * bw * bw * bw + f * bw * bw * bw * bw * bw;
    return denom != 0 ? 500 / denom : 0;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }
}
