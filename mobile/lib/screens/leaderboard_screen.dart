import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> _leaderboard = [];
  bool _loading = true;
  String _selectedLift = 'total';
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadCached();
    _loadData();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('sbd_token');
    if (token != null) {
      try {
        final parts = token.split('.');
        final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        setState(() => _myUsername = payload['username']);
      } catch (_) {}
    }
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_leaderboard');
    if (cached != null) {
      setState(() {
        _leaderboard = jsonDecode(cached);
        _loading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final data = await ApiService.getLeaderboard();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_leaderboard', jsonEncode(data));
      if (mounted) setState(() { _leaderboard = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _sorted {
    final list = List<dynamic>.from(_leaderboard);
    if (_selectedLift == 'total') {
      list.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));
    } else {
      list.sort((a, b) => (b[_selectedLift] as num).compareTo(a[_selectedLift] as num));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    final medals = ['🥇', '🥈', '🥉'];
    final medalColors = [const Color(0xFFEAB308), const Color(0xFF9CA3AF), const Color(0xFFB45309)];

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              Text('🏆 ', style: TextStyle(fontSize: 24)),
              Text('Leaderboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text50)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Compare PRs across all lifters.', style: TextStyle(fontSize: 13, color: AppTheme.text400)),
          const SizedBox(height: 16),

          // Filter buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterBtn('Total', 'total', '🏆'),
                _filterBtn('Squat', 'Squat', '🦵'),
                _filterBtn('Bench', 'Bench', '💪'),
                _filterBtn('Deadlift', 'Deadlift', '🏋️'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            ...List.generate(3, (_) => Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: AppTheme.bg850, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.bg800)),
            ))
          else if (sorted.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No lifters yet.', style: TextStyle(color: AppTheme.text400)))))
          else
            ...sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final e = entry.value;
              final isMe = e['username'] == _myUsername;
              final displayVal = _selectedLift == 'total' ? e['total'] : e[_selectedLift];
              final topVal = _selectedLift == 'total' ? sorted[0]['total'] : sorted[0][_selectedLift];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: idx < 3 ? medalColors[idx].withValues(alpha: 0.08) : AppTheme.bg850,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isMe ? AppTheme.accentRed.withValues(alpha: 0.3) : (idx < 3 ? medalColors[idx].withValues(alpha: 0.2) : AppTheme.bg800),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Rank
                        SizedBox(
                          width: 36,
                          child: idx < 3
                              ? Text(medals[idx], style: const TextStyle(fontSize: 24))
                              : Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.bg800, border: Border.all(color: AppTheme.bg700)),
                                  child: Center(child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text400, fontSize: 13))),
                                ),
                        ),
                        const SizedBox(width: 12),
                        // User info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(e['username'], style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text50, fontSize: 15)),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentRed.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2)),
                                      ),
                                      child: const Text('YOU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.accentRed)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _liftBadge('S', e['Squat'], AppTheme.accentRed),
                                  const SizedBox(width: 6),
                                  _liftBadge('B', e['Bench'], AppTheme.accentBlue),
                                  const SizedBox(width: 6),
                                  _liftBadge('D', e['Deadlift'], AppTheme.accentAmber),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Value
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              displayVal > 0 ? '$displayVal' : '—',
                              style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800, fontFamily: 'monospace',
                                color: idx == 0 ? medalColors[0] : idx == 1 ? medalColors[1] : idx == 2 ? medalColors[2] : AppTheme.text100,
                              ),
                            ),
                            Text(
                              '${displayVal > 0 ? "kg " : ""}${_selectedLift == "total" ? "total" : _selectedLift}',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.text500, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Progress bar
                    if (displayVal > 0 && topVal > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (displayVal / topVal).clamp(0.05, 1.0).toDouble(),
                          minHeight: 5,
                          backgroundColor: AppTheme.bg800,
                          valueColor: AlwaysStoppedAnimation(
                            idx == 0 ? medalColors[0] : idx == 1 ? medalColors[1] : idx == 2 ? medalColors[2] : AppTheme.accentRed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, String key, String emoji) {
    final active = _selectedLift == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: () => setState(() => _selectedLift = key),
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? AppTheme.accentRed.withValues(alpha: 0.1) : AppTheme.bg800.withValues(alpha: 0.5),
          side: BorderSide(color: active ? AppTheme.accentRed.withValues(alpha: 0.25) : AppTheme.bg700),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? AppTheme.accentRed : AppTheme.text400, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _liftBadge(String letter, dynamic val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$letter: ${val > 0 ? "${val}kg" : "—"}',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, fontFamily: 'monospace'),
      ),
    );
  }
}
