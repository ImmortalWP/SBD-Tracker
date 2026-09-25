import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Training calendar showing session history on a monthly grid.
class TrainingCalendarScreen extends StatefulWidget {
  const TrainingCalendarScreen({super.key});

  @override
  State<TrainingCalendarScreen> createState() => _TrainingCalendarScreenState();
}

class _TrainingCalendarScreenState extends State<TrainingCalendarScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<dynamic> _sessions = [];
  bool _loading = true;
  Map<String, dynamic>? _selectedDaySession;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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
      final dateStr = s['date']?.toString();
      if (dateStr == null) continue;
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(dt);
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDaySession = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDaySession = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                _buildMonthNav(),
                const SizedBox(height: 12),
                _buildWeekdayHeaders(),
                const SizedBox(height: 8),
                _buildCalendarGrid(),
                const SizedBox(height: 20),
                _buildMonthStats(),
                if (_selectedDaySession != null) ...[
                  const SizedBox(height: 20),
                  _buildSelectedSessionCard(),
                ],
              ],
            ),
    );
  }

  Widget _buildMonthNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          onPressed: _prevMonth,
        ),
        Text(
          DateFormat('MMMM yyyy').format(_currentMonth),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: days.map((d) => Expanded(
        child: Center(
          child: Text(d, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon, 7=Sun
    final daysInMonth = lastDay.day;
    final map = _sessionsByDate;
    final today = DateTime.now();

    final cells = <Widget>[];
    // Leading empty cells
    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final dt = DateTime(_currentMonth.year, _currentMonth.month, day);
      final key = DateFormat('yyyy-MM-dd').format(dt);
      final sessions = map[key] ?? [];
      final hasSession = sessions.isNotEmpty;
      final isToday = dt.year == today.year && dt.month == today.month && dt.day == today.day;
      final isSelected = _selectedDaySession != null &&
          _selectedDaySession!['date']?.toString().startsWith(key) == true;

      cells.add(GestureDetector(
        onTap: hasSession ? () {
          setState(() => _selectedDaySession = sessions.first);
        } : null,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentBlueBg
                : hasSession ? AppColors.accentGreen.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isToday ? Border.all(color: AppColors.accentBlue, width: 1.5) : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasSession ? FontWeight.w700 : FontWeight.w400,
                    color: hasSession ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                if (hasSession)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      color: sessions.length > 1 ? AppColors.accentAmber : AppColors.accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
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
      if (dt == null) continue;
      if (dt.year == _currentMonth.year && dt.month == _currentMonth.month) {
        for (final s in entry.value) {
          monthSessions++;
          final exercises = s['exercises'] as List? ?? [];
          for (final ex in exercises) {
            final sets = ex['sets'] as List? ?? [];
            for (final set in sets) {
              final w = (set['weight'] as num?)?.toDouble() ?? 0;
              final r = (set['reps'] as num?)?.toInt() ?? 0;
              monthVolume += w * r;
            }
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('$monthSessions', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accentBlueLight)),
                const Text('Sessions', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.borderColor),
          Expanded(
            child: Column(
              children: [
                Text('${(monthVolume / 1000).toStringAsFixed(1)}t', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accentGreen)),
                const Text('Volume', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedSessionCard() {
    final session = _selectedDaySession!;
    final date = DateTime.tryParse(session['date']?.toString() ?? '');
    final dateStr = date != null ? DateFormat('EEEE, MMM d').format(date) : '';
    final exercises = session['exercises'] as List? ?? [];
    final day = session['day']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBlueBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentBlueLight)),
              if (day.isNotEmpty)
                Text(day, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          ...exercises.take(5).map((ex) {
            final name = ex['name']?.toString() ?? '';
            final sets = ex['sets'] as List? ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Text('•  ', style: TextStyle(color: AppColors.textMuted)),
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                  Text('${sets.length} sets', style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'monospace')),
                ],
              ),
            );
          }).toList(),
          if (exercises.length > 5)
            Text('+${exercises.length - 5} more', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
