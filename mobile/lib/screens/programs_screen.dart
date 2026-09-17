import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  List<dynamic> _programs = [];
  Map<String, dynamic>? _activeData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getPrograms(),
        ApiService.getActiveProgram(),
      ]);
      if (mounted) {
        setState(() {
          _programs = results[0] as List<dynamic>;
          _activeData = results[1] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? get _activeProgramId {
    final program = _activeData?['program'];
    if (program == null) return null;
    return program['_id']?.toString();
  }

  Map<String, dynamic>? get _activeProgress => _activeData?['progress'] != null
      ? Map<String, dynamic>.from(_activeData!['progress'])
      : null;

  Future<void> _startProgram(String id) async {
    try {
      await ApiService.startProgram(id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Program started!'), backgroundColor: AppColors.accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  Future<void> _stopProgram(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Stop Program?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Your progress will be reset.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.stopProgram(id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  void _viewProgramDetails(String id) async {
    try {
      final program = await ApiService.getProgram(id);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => _ProgramDetailScreen(
            program: program,
            isActive: _activeProgramId == id,
            progress: _activeProgramId == id ? _activeProgress : null,
            onStart: () => _startProgram(id),
            onStop: () => _stopProgram(id),
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.accentBlue,
          backgroundColor: AppColors.cardBg,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            children: [
              const Text('Programs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Choose a training program', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator(color: AppColors.accentBlue, strokeWidth: 2)),
                )
              else if (_programs.isEmpty)
                _buildEmptyState()
              else ...[
                if (_activeProgramId != null) ...[
                  _buildActiveProgramCard(),
                  const SizedBox(height: 24),
                  const Text('ALL PROGRAMS', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                ],
                ..._programs.map((p) => _buildProgramCard(p)).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.fitness_center, size: 48, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text('No Programs Available', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Text('Programs will appear here once created.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActiveProgramCard() {
    final activeProgram = _activeData?['program'];
    if (activeProgram == null) return const SizedBox();
    final progress = _activeProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentBlueBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accentGreen, letterSpacing: 0.8)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _stopProgram(activeProgram['_id'].toString()),
                child: const Text('Stop', style: TextStyle(fontSize: 13, color: AppColors.accentRed, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            activeProgram['name']?.toString() ?? 'Program',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildProgressChip('Week ${progress?['currentWeek'] ?? 1}', Icons.calendar_today),
              const SizedBox(width: 12),
              _buildProgressChip('Day ${progress?['currentDay'] ?? 1}', Icons.today),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _viewProgramDetails(activeProgram['_id'].toString()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('View Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accentBlueLight),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProgramCard(dynamic program) {
    final id = program['_id']?.toString() ?? '';
    final name = program['name']?.toString() ?? 'Unnamed';
    final category = program['category']?.toString() ?? 'General';
    final difficulty = program['difficulty']?.toString() ?? '';
    final weeks = program['weeks'] ?? 0;
    final daysPerWeek = program['daysPerWeek'] ?? 0;
    final isActive = _activeProgramId == id;

    Color categoryColor;
    switch (category) {
      case 'Powerlifting': categoryColor = AppColors.accentRed; break;
      case 'Strength': categoryColor = AppColors.accentBlue; break;
      case 'Hypertrophy': categoryColor = AppColors.accentGreen; break;
      case 'Bodybuilding': categoryColor = AppColors.statPurple; break;
      default: categoryColor = AppColors.accentAmber;
    }

    return GestureDetector(
      onTap: () => _viewProgramDetails(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? AppColors.accentBlue.withValues(alpha: 0.3) : AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.fitness_center, color: categoryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: categoryColor)),
                      ),
                      if (difficulty.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(difficulty, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                      const SizedBox(width: 6),
                      Text('${weeks}w • ${daysPerWeek}d/w', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace')),
                    ],
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Program Detail Screen ───

class _ProgramDetailScreen extends StatelessWidget {
  final Map<String, dynamic> program;
  final bool isActive;
  final Map<String, dynamic>? progress;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _ProgramDetailScreen({
    required this.program,
    required this.isActive,
    this.progress,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final name = program['name']?.toString() ?? 'Program';
    final description = program['description']?.toString() ?? '';
    final category = program['category']?.toString() ?? 'General';
    final difficulty = program['difficulty']?.toString() ?? '';
    final weeks = program['weeks'] ?? 0;
    final daysPerWeek = program['daysPerWeek'] ?? 0;
    final schedule = program['schedule'] as List? ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isActive)
            TextButton(
              onPressed: () { onStop(); Navigator.pop(context); },
              child: const Text('Stop', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(category, AppColors.accentBlue),
              if (difficulty.isNotEmpty) ...[const SizedBox(width: 8), _chip(difficulty, AppColors.textMuted)],
              const SizedBox(width: 8),
              _chip('${weeks}w • ${daysPerWeek}d/w', AppColors.textMuted),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          ],
          const SizedBox(height: 24),
          if (!isActive) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { onStart(); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Start This Program', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (isActive && progress != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentBlueBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _progressItem('Week', '${progress!['currentWeek'] ?? 1}', '$weeks'),
                  Container(width: 1, height: 40, color: AppColors.borderColor),
                  _progressItem('Day', '${progress!['currentDay'] ?? 1}', '$daysPerWeek'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Schedule
          if (schedule.isNotEmpty) ...[
            const Text('SCHEDULE', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 12),
            ...schedule.map((week) => _buildWeekCard(week)).toList(),
          ] else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: const Center(
                child: Text('No schedule defined yet.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _progressItem(String label, String current, String total) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: current, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.accentBlueLight)),
              TextSpan(text: ' / $total', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekCard(dynamic week) {
    final weekNum = week['weekNumber'] ?? 0;
    final weekName = week['name']?.toString();
    final days = week['days'] as List? ?? [];
    final isCurrentWeek = isActive && (progress?['currentWeek'] ?? 1) == weekNum;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrentWeek ? AppColors.accentBlue.withValues(alpha: 0.3) : AppColors.borderColor),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isCurrentWeek ? AppColors.accentBlueBg : AppColors.inputBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('W$weekNum', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isCurrentWeek ? AppColors.accentBlueLight : AppColors.textSecondary)),
            ),
          ),
          title: Text(
            weekName ?? 'Week $weekNum',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          subtitle: Text('${days.length} days', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          iconColor: AppColors.textMuted,
          collapsedIconColor: AppColors.textMuted,
          initiallyExpanded: isCurrentWeek,
          children: days.map<Widget>((day) => _buildDayRow(day, weekNum)).toList(),
        ),
      ),
    );
  }

  Widget _buildDayRow(dynamic day, int weekNum) {
    final dayNum = day['dayNumber'] ?? 0;
    final dayName = day['name']?.toString() ?? 'Day $dayNum';
    final exercises = day['exercises'] as List? ?? [];
    final isCurrentDay = isActive &&
        (progress?['currentWeek'] ?? 1) == weekNum &&
        (progress?['currentDay'] ?? 1) == dayNum;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentDay ? AppColors.accentBlueBg : AppColors.inputBg,
        borderRadius: BorderRadius.circular(10),
        border: isCurrentDay ? Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isCurrentDay) ...[
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
              ],
              Text(dayName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isCurrentDay ? AppColors.accentBlueLight : AppColors.textPrimary)),
              const Spacer(),
              Text('${exercises.length} exercises', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...exercises.map<Widget>((ex) {
              final name = ex['name']?.toString() ?? '';
              final sets = ex['sets'] ?? 0;
              final reps = ex['reps']?.toString() ?? '';
              final pct = ex['percentage1rm'];
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Text('•  ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                    Text(
                      '$sets × $reps${pct != null ? ' @${pct}%' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}
