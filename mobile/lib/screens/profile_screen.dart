import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  final _classes = ['59kg', '66kg', '74kg', '83kg', '93kg', '105kg', '120kg', '120kg+',
    '47kg', '52kg', '57kg', '63kg', '69kg', '76kg', '84kg', '84kg+'];

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
      if (mounted) setState(() { _profile = data['profile']; _prs = data['prs'] ?? _prs; _totalSessions = data['total'] ?? 0; _loading = false; _fill(); });
    }
  }

  void _fill() {
    if (_profile != null) {
      if (_profile!['bodyWeight'] != null) _weightCtrl.text = _profile!['bodyWeight'].toString();
      if (_profile!['height'] != null) _heightCtrl.text = _profile!['height'].toString();
      _weightClass = _profile!['weightClass'];
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([ApiService.getProfile(), ApiService.getPRs(), ApiService.getSessions()]);
      final profile = results[0] as Map<String, dynamic>;
      final prs = results[1] as Map<String, dynamic>;
      final sessions = results[2] as List<dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_profile', jsonEncode({'profile': profile, 'prs': prs, 'total': sessions.length}));
      if (mounted) setState(() { _profile = profile; _prs = prs; _totalSessions = sessions.length; _loading = false; _fill(); });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final data = <String, dynamic>{};
    if (_weightCtrl.text.isNotEmpty) data['bodyWeight'] = double.tryParse(_weightCtrl.text);
    if (_heightCtrl.text.isNotEmpty) data['height'] = double.tryParse(_heightCtrl.text);
    if (_weightClass != null) data['weightClass'] = _weightClass;
    try {
      final result = await ApiService.updateProfile(data);
      setState(() => _profile = result);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Profile saved'), backgroundColor: AppTheme.accentGreen, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppTheme.accentRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final total = (_prs['Squat'] ?? 0) + (_prs['Bench'] ?? 0) + (_prs['Deadlift'] ?? 0);
    final bw = _profile?['bodyWeight'];

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Avatar + name
          Center(child: Column(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppTheme.accentRed.withValues(alpha: 0.3), AppTheme.accentAmber.withValues(alpha: 0.2)]),
                border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3), width: 2),
              ),
              child: Center(child: Text((auth.username ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.text50))),
            ),
            const SizedBox(height: 8),
            Text(auth.username?.toUpperCase() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text50, letterSpacing: 1)),
            Text('Powerlifter${_weightClass != null ? ' · $_weightClass' : ''}', style: const TextStyle(fontSize: 12, color: AppTheme.text500)),
          ])),
          const SizedBox(height: 20),

          // Stats row
          Row(children: [
            _stat('Total', '${total}kg', AppTheme.accentRed),
            const SizedBox(width: 8),
            _stat('Sessions', '$_totalSessions', AppTheme.accentBlue),
            const SizedBox(width: 8),
            _stat('BW', bw != null ? '${bw}kg' : '—', AppTheme.accentAmber),
          ]),
          const SizedBox(height: 20),

          // Body stats form
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.bg900, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.bg800)),
            child: Column(children: [
              Row(children: [
                Expanded(child: TextField(controller: _weightCtrl, keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16, color: AppTheme.text100),
                    decoration: _deco('Body Weight', 'kg'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _heightCtrl, keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16, color: AppTheme.text100),
                    decoration: _deco('Height', 'cm'))),
              ]),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _weightClass,
                decoration: InputDecoration(
                  labelText: 'Weight Class', labelStyle: const TextStyle(fontSize: 12, color: AppTheme.text500),
                  filled: true, fillColor: AppTheme.bg850,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                dropdownColor: AppTheme.bg850,
                items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => _weightClass = v,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _save, child: const Text('SAVE')),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Logout
          OutlinedButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout, size: 16, color: AppTheme.accentRed),
            label: const Text('Logout', style: TextStyle(color: AppTheme.accentRed)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.accentRed),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.15))),
        child: Column(children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace'))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.text500)),
        ]),
      ),
    );
  }

  InputDecoration _deco(String label, String suffix) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(fontSize: 12, color: AppTheme.text500),
    suffixText: suffix, filled: true, fillColor: AppTheme.bg850,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  @override
  void dispose() { _weightCtrl.dispose(); _heightCtrl.dispose(); super.dispose(); }
}
