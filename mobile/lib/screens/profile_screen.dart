import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

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

  // Settings
  bool _useKg = true;
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
      });
    }
  }

  Future<void> _saveLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_useKg', _useKg);
    await prefs.setString('profile_block', _blockCtrl.text);
    await prefs.setString('profile_week', _weekCtrl.text);
    await prefs.setString('profile_days', _daysCtrl.text);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_profile', jsonEncode({
        'profile': profile,
        'prs': prs,
        'total': sessions.length,
      }));
      if (mounted) {
        setState(() {
          _profile = profile;
          _prs = prs;
          _totalSessions = sessions.length;
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
        backgroundColor: AppTheme.bg900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reset All Data', style: TextStyle(color: AppTheme.text50, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will clear all cached data on this device. Your server data will remain intact.',
          style: TextStyle(color: AppTheme.text400, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.text500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w700)),
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
          backgroundColor: AppTheme.accentAmber,
          behavior: SnackBarBehavior.floating,
        ));
        _loadData();
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final sessions = await ApiService.getSessions();
      final prs = await ApiService.getPRs();
      final export = jsonEncode({'prs': prs, 'sessions': sessions, 'exportedAt': DateTime.now().toIso8601String()});

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.bg900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Export Data', style: TextStyle(color: AppTheme.text50, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${sessions.length} sessions, ${prs.length} PRs', style: const TextStyle(color: AppTheme.text400, fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.bg950,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      export,
                      style: const TextStyle(fontSize: 10, color: AppTheme.text500, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: AppTheme.text500)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppTheme.accentRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final sq = _prs['Squat'] ?? 0;
    final bn = _prs['Bench'] ?? 0;
    final dl = _prs['Deadlift'] ?? 0;
    final total = sq + bn + dl;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // ─── Header ───
          _buildHeader(auth, total),
          const SizedBox(height: 32),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: AppTheme.text500, strokeWidth: 2)),
            )
          else ...[
            // ─── PR Section ───
            _buildPRSection(sq, bn, dl, total),
            const SizedBox(height: 36),

            // ─── Training Settings ───
            _buildTrainingSettings(),
            const SizedBox(height: 36),

            // ─── App Settings ───
            _buildAppSettings(auth),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(AuthService auth, num total) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentRed.withValues(alpha: 0.25),
                AppTheme.accentAmber.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3), width: 2),
          ),
          child: Center(
            child: Text(
              (auth.username ?? 'U')[0].toUpperCase(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text50),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Name + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.username ?? 'Lifter',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.text50),
              ),
              const SizedBox(height: 2),
              Text(
                'Powerlifting${_weightClass != null ? ' · $_weightClass' : ''}',
                style: const TextStyle(fontSize: 12, color: AppTheme.text500, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // Total
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.text600, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(
              '${total}kg',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace'),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PR SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPRSection(num sq, num bn, num dl, num total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PERSONAL RECORDS'),
        const SizedBox(height: 14),
        _prRow('Squat', sq, AppTheme.accentRed),
        _prRow('Bench', bn, AppTheme.accentBlue),
        _prRow('Deadlift', dl, AppTheme.accentAmber),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: AppTheme.bg800, height: 1),
        ),
        _prRow('Total', total, AppTheme.text50, bold: true),
        const SizedBox(height: 8),
        Row(
          children: [
            _miniStat('Sessions', '$_totalSessions'),
            const SizedBox(width: 24),
            _miniStat('Body Weight', _profile?['bodyWeight'] != null ? '${_profile!['bodyWeight']}kg' : '—'),
          ],
        ),
      ],
    );
  }

  Widget _prRow(String label, num value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: bold ? 1.0 : 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? AppTheme.text100 : AppTheme.text400,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${value.toString().replaceAll('.0', '')}kg',
            style: TextStyle(
              fontSize: bold ? 18 : 16,
              fontWeight: FontWeight.w800,
              color: bold ? AppTheme.text50 : color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Row(
      children: [
        Text('$label  ', style: const TextStyle(fontSize: 12, color: AppTheme.text600, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text300, fontFamily: 'monospace')),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TRAINING SETTINGS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTrainingSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('TRAINING SETTINGS'),
        const SizedBox(height: 14),

        // Editable 1RM fields
        _settingRow('Squat 1RM', _squatRMCtrl, suffix: _useKg ? 'kg' : 'lb'),
        _settingRow('Bench 1RM', _benchRMCtrl, suffix: _useKg ? 'kg' : 'lb'),
        _settingRow('Deadlift 1RM', _deadliftRMCtrl, suffix: _useKg ? 'kg' : 'lb'),
        const SizedBox(height: 16),

        // Units toggle
        Row(
          children: [
            const Expanded(
              child: Text('Units', style: TextStyle(fontSize: 14, color: AppTheme.text300, fontWeight: FontWeight.w500)),
            ),
            _unitToggle(),
          ],
        ),
        const SizedBox(height: 20),

        // Divider
        const Divider(color: AppTheme.bg800, height: 1),
        const SizedBox(height: 16),

        // Program config
        Row(
          children: [
            Expanded(child: _compactField('Block', _blockCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _compactField('Week', _weekCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _compactField('Days/wk', _daysCtrl)),
          ],
        ),
        const SizedBox(height: 12),

        // Body Weight + Weight Class
        Row(
          children: [
            Expanded(child: _compactField('Body Weight', _weightCtrl, suffix: _useKg ? 'kg' : 'lb')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Class', style: TextStyle(fontSize: 11, color: AppTheme.text600, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.bg900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.bg700, width: 0.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _weightClass,
                        isExpanded: true,
                        dropdownColor: AppTheme.bg850,
                        style: const TextStyle(fontSize: 14, color: AppTheme.text100, fontFamily: 'monospace'),
                        hint: const Text('—', style: TextStyle(color: AppTheme.text600)),
                        items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _weightClass = v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Save button
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _saveProfile,
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.text50,
              foregroundColor: AppTheme.bg950,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _settingRow(String label, TextEditingController ctrl, {String suffix = 'kg'}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.text300, fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 100,
            height: 38,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: AppTheme.text100, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
              decoration: InputDecoration(
                suffixText: suffix,
                suffixStyle: const TextStyle(fontSize: 12, color: AppTheme.text500),
                filled: true,
                fillColor: AppTheme.bg900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.bg700.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.bg700.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.accentRed.withValues(alpha: 0.5)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.bg700, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _unitOption('kg', _useKg),
          _unitOption('lb', !_useKg),
        ],
      ),
    );
  }

  Widget _unitOption(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() => _useKg = label == 'kg');
        _saveLocalSettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.bg700 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.text50 : AppTheme.text500,
          ),
        ),
      ),
    );
  }

  Widget _compactField(String label, TextEditingController ctrl, {String? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.text600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14, color: AppTheme.text100, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: const TextStyle(fontSize: 11, color: AppTheme.text500),
              filled: true,
              fillColor: AppTheme.bg900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.bg700.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.bg700.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.accentRed.withValues(alpha: 0.5)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  APP SETTINGS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAppSettings(AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('APP'),
        const SizedBox(height: 14),

        _actionRow(Icons.download_outlined, 'Export Data', AppTheme.text400, onTap: _exportData),
        _actionRow(Icons.refresh, 'Reset Local Data', AppTheme.accentAmber, onTap: _resetData),

        const SizedBox(height: 8),
        const Divider(color: AppTheme.bg800, height: 1),
        const SizedBox(height: 8),

        _actionRow(Icons.logout, 'Logout', AppTheme.accentRed, onTap: () => auth.logout()),

        const SizedBox(height: 24),
        Center(
          child: Text(
            'SBD Tracker v1.0',
            style: TextStyle(fontSize: 11, color: AppTheme.text700),
          ),
        ),
      ],
    );
  }

  Widget _actionRow(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, size: 18, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED
  // ═══════════════════════════════════════════════════════════════

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 1.5),
    );
  }
}
