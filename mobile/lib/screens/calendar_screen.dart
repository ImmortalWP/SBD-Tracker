import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class TrainingCalendarScreen extends StatefulWidget {
  const TrainingCalendarScreen({super.key});
  @override
  State<TrainingCalendarScreen> createState() => _TrainingCalendarScreenState();
}

class _TrainingCalendarScreenState extends State<TrainingCalendarScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<dynamic> _sessions = [];
  bool _loading = true;
  String? _selectedKey;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    try {
      final sessions = await ApiService.getSessions();
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<dynamic>> get _sessionsByDate {
    final map = <String, List<dynamic>>{};
    for (final s in _sessions) {
      final dt = DateTime.tryParse(s['date']?.toString() ?? '');
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(dt);
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Calendar', style: AppTypography.h2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 40),
              children: [
                _buildMonthNav(),
                const SizedBox(height: Spacing.md),
                _buildWeekdayHeaders(),
                const SizedBox(height: Spacing.sm),
                _buildCalendarGrid(),
                const SizedBox(height: Spacing.xl),
                _buildMonthStats(),
                if (_selectedKey != null) ...[
                  const SizedBox(height: Spacing.base),
                  _buildSelectedDetail(),
                ],
              ],
            ),
    );
  }

  Widget _buildMonthNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => setState(() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1); _selectedKey = null; }),
          child: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 28),
        ),
        Text(DateFormat('MMMM yyyy').format(_currentMonth), style: AppTypography.h3),
        GestureDetector(
          onTap: () => setState(() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1); _selectedKey = null; }),
          child: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 28),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: days.map((d) => Expanded(
        child: Center(child: Text(d, style: AppTypography.labelSmall)),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    final map = _sessionsByDate;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (int i = 1; i < startWeekday; i++) cells.add(const SizedBox());

    for (int day = 1; day <= daysInMonth; day++) {
      final dt = DateTime(_currentMonth.year, _currentMonth.month, day);
      final key = DateFormat('yyyy-MM-dd').format(dt);
      final sessions = map[key] ?? [];
      final hasSession = sessions.isNotEmpty;
      final isToday = dt.year == today.year && dt.month == today.month && dt.day == today.day;
      final isSelected = _selectedKey == key;

      cells.add(GestureDetector(
        onTap: hasSession ? () => setState(() => _selectedKey = key) : null,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentBlueBg : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: isToday ? Border.all(color: AppColors.accentBlue, width: 1) : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasSession ? FontWeight.w600 : FontWeight.w400,
                    color: hasSession ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                if (hasSession)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4, height: 4,
                    decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  Widget _buildMonthStats() {
    final map = _sessionsByDate;
    int monthSessions = 0;
    double monthVolume = 0;

    for (final entry in map.entries) {
      final dt = DateTime.tryParse(entry.key);
      if (dt == null || dt.year != _currentMonth.year || dt.month != _currentMonth.month) continue;
      for (final s in entry.value) {
        monthSessions++;
        for (final ex in (s['exercises'] as List? ?? [])) {
          for (final set in (ex['sets'] as List? ?? [])) {
            monthVolume += ((set['weight'] as num?)?.toDouble() ?? 0) * ((set['reps'] as num?)?.toInt() ?? 0);
          }
        }
      }
    }

    return Row(
      children: [
        Expanded(child: _buildMonthStat('$monthSessions', 'Sessions', AppColors.accentBlueLight)),
        const SizedBox(width: Spacing.md),
        Expanded(child: _buildMonthStat('${(monthVolume / 1000).toStringAsFixed(1)}t', 'Volume', AppColors.accentGreen)),
      ],
    );
  }

  Widget _buildMonthStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Spacing.base),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        children: [
          Text(value, style: AppTypography.monoLarge.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.labelSmall),
        ],
      ),
    );
  }

  Widget _buildSelectedDetail() {
    final map = _sessionsByDate;
    final sessions = map[_selectedKey] ?? [];
    if (sessions.isEmpty) return const SizedBox();
    final session = sessions.first;
    final exercises = session['exercises'] as List? ?? [];
    final dt = DateTime.tryParse(_selectedKey ?? '');
    final dateStr = dt != null ? DateFormat('EEEE, MMM d').format(dt) : '';

    return Container(
      padding: const EdgeInsets.all(Spacing.base),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: AppTypography.bodyMedium.copyWith(color: AppColors.accentBlueLight)),
          const SizedBox(height: Spacing.sm),
          ...exercises.take(5).map((ex) {
            final name = ex['name']?.toString() ?? '';
            final sets = ex['sets'] as List? ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: AppTypography.bodySmall),
                  Text('${sets.length} sets', style: AppTypography.labelSmall),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
