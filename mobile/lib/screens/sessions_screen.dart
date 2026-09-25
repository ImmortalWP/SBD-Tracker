import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/session_utils.dart';
import '../theme/app_colors.dart';

class SessionsScreen extends StatefulWidget {
  final List<dynamic> sessions;
  final Map<String, dynamic> prs;
  final Future<void> Function() onRefresh;

  const SessionsScreen({
    super.key,
    required this.sessions,
    required this.prs,
    required this.onRefresh,
  });

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  // ─── Filter State ───
  int? _selectedBlock;
  int? _selectedWeek;
  String? _selectedDay;
  String _exerciseSearch = '';
  final Set<String> _collapsedBlocks = {};
  final Set<String> _collapsedWeeks = {};
  final Set<int> _expandedSessions = {0}; // First session auto-expanded

  // ─── Dynamic filter options from real data ───
  List<int> get _availableBlocks {
    final blocks = widget.sessions.map((s) => s['block'] as int? ?? 1).toSet().toList();
    blocks.sort((a, b) => b.compareTo(a)); // newest first
    return blocks;
  }

  List<int> get _availableWeeks {
    var sessions = widget.sessions.toList();
    if (_selectedBlock != null) {
      sessions = sessions.where((s) => s['block'] == _selectedBlock).toList();
    }
    final weeks = sessions.map((s) => s['week'] as int? ?? 1).toSet().toList();
    weeks.sort((a, b) => b.compareTo(a));
    return weeks;
  }

  List<String> get _availableDays {
    var sessions = widget.sessions.toList();
    if (_selectedBlock != null) sessions = sessions.where((s) => s['block'] == _selectedBlock).toList();
    if (_selectedWeek != null) sessions = sessions.where((s) => s['week'] == _selectedWeek).toList();
    final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final days = sessions.map((s) => s['day']?.toString() ?? '').where((d) => d.isNotEmpty).toSet().toList();
    days.sort((a, b) => dayOrder.indexOf(a).compareTo(dayOrder.indexOf(b)));
    return days;
  }

  bool get _hasActiveFilters => _selectedBlock != null || _selectedWeek != null || _selectedDay != null || _exerciseSearch.isNotEmpty;

  List<dynamic> get _filteredSessions {
    return widget.sessions.where((session) {
      if (_selectedBlock != null && session['block'] != _selectedBlock) return false;
      if (_selectedWeek != null && session['week'] != _selectedWeek) return false;
      if (_selectedDay != null && session['day'] != _selectedDay) return false;
      if (_exerciseSearch.isNotEmpty) {
        final exercises = session['exercises'] as List? ?? [];
        final query = _exerciseSearch.toLowerCase();
        final hasMatch = exercises.any((ex) {
          final name = (ex['name']?.toString() ?? '').toLowerCase();
          return name.contains(query);
        });
        if (!hasMatch) return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedBlock = null;
      _selectedWeek = null;
      _selectedDay = null;
      _exerciseSearch = '';
    });
  }

  /// Map block number to a descriptive name using common powerlifting block naming
  String _blockName(int block) {
    // Check if any session in this block has a meaningful name from the program
    // For now, use standard powerlifting periodization naming
    switch (block) {
      case 1: return 'Hypertrophy';
      case 2: return 'Strength';
      case 3: return 'Peaking';
      case 4: return 'Deload';
      default: return 'Block $block';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSessions;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xl, Spacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Training Log', style: AppTypography.h1),
                    Text('${filtered.length}', style: AppTypography.mono.copyWith(color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: Spacing.base),
                // Search bar
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _exerciseSearch = v),
                    style: AppTypography.body.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search exercises...',
                      hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                // Filter chips row
                _buildFilterChips(),
                if (_hasActiveFilters) ...[
                  const SizedBox(height: Spacing.sm),
                  GestureDetector(
                    onTap: _clearFilters,
                    child: Text('Clear filters', style: AppTypography.bodySmall.copyWith(color: AppColors.accentBlueLight)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          // Session list
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              color: AppColors.accentBlue,
              backgroundColor: AppColors.cardBg,
              child: filtered.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.inbox_rounded, size: 40, color: AppColors.textMuted),
                                const SizedBox(height: Spacing.md),
                                const Text('No sessions found', style: AppTypography.bodyMedium),
                                if (_hasActiveFilters) ...[
                                  const SizedBox(height: Spacing.sm),
                                  GestureDetector(
                                    onTap: _clearFilters,
                                    child: Text('Clear filters', style: AppTypography.bodySmall.copyWith(color: AppColors.accentBlueLight)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 100),
                      children: _buildGroupedList(filtered),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filter Chips ───

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildDropdownChip(
            label: _selectedBlock != null ? _blockName(_selectedBlock!) : 'Block',
            isActive: _selectedBlock != null,
            options: _availableBlocks,
            displayBuilder: (b) => _blockName(b),
            onSelected: (b) => setState(() { _selectedBlock = b; _selectedWeek = null; _selectedDay = null; }),
          ),
          const SizedBox(width: Spacing.sm),
          _buildDropdownChip(
            label: _selectedWeek != null ? 'Week $_selectedWeek' : 'Week',
            isActive: _selectedWeek != null,
            options: _availableWeeks,
            displayBuilder: (w) => 'Week $w',
            onSelected: (w) => setState(() { _selectedWeek = w; _selectedDay = null; }),
          ),
          const SizedBox(width: Spacing.sm),
          _buildStringDropdownChip(
            label: _selectedDay ?? 'Day',
            isActive: _selectedDay != null,
            options: _availableDays,
            onSelected: (d) => setState(() => _selectedDay = d),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip<T>({
    required String label,
    required bool isActive,
    required List<T> options,
    required String Function(T) displayBuilder,
    required Function(T?) onSelected,
  }) {
    return GestureDetector(
      onTap: () {
        if (options.isEmpty) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.cardBg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Spacing.base),
                  child: Text(label, style: AppTypography.h3),
                ),
                if (isActive)
                  ListTile(
                    title: Text('Clear', style: AppTypography.bodyMedium.copyWith(color: AppColors.accentRed)),
                    leading: const Icon(Icons.clear, color: AppColors.accentRed, size: 18),
                    onTap: () { onSelected(null); Navigator.pop(ctx); },
                  ),
                ...options.map((o) => ListTile(
                  title: Text(displayBuilder(o), style: AppTypography.body),
                  onTap: () { onSelected(o); Navigator.pop(ctx); },
                )).toList(),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentBlueBg : AppColors.cardBg,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTypography.labelSmall.copyWith(color: isActive ? AppColors.accentBlueLight : AppColors.textMuted)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: isActive ? AppColors.accentBlueLight : AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildStringDropdownChip({
    required String label,
    required bool isActive,
    required List<String> options,
    required Function(String?) onSelected,
  }) {
    return _buildDropdownChip<String>(
      label: label,
      isActive: isActive,
      options: options,
      displayBuilder: (d) => d,
      onSelected: onSelected,
    );
  }

  // ─── Grouped Session List (Block → Week → Session) ───

  List<Widget> _buildGroupedList(List<dynamic> sessions) {
    // Group by block → week
    final grouped = <int, Map<int, List<dynamic>>>{};
    for (final s in sessions) {
      final block = s['block'] as int? ?? 1;
      final week = s['week'] as int? ?? 1;
      grouped.putIfAbsent(block, () => {});
      grouped[block]!.putIfAbsent(week, () => []);
      grouped[block]![week]!.add(s);
    }

    // Sort blocks (newest first)
    final sortedBlocks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    int globalIndex = 0;

    for (final block in sortedBlocks) {
      final blockKey = 'block_$block';
      final isBlockCollapsed = _collapsedBlocks.contains(blockKey);

      // Block header
      widgets.add(
        GestureDetector(
          onTap: () => setState(() {
            if (isBlockCollapsed) _collapsedBlocks.remove(blockKey);
            else _collapsedBlocks.add(blockKey);
          }),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.sm),
            child: Row(
              children: [
                Icon(
                  isBlockCollapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                  color: AppColors.accentBlueLight, size: 20,
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  _blockName(block).toUpperCase(),
                  style: AppTypography.sectionHeader.copyWith(color: AppColors.accentBlueLight, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );

      if (isBlockCollapsed) {
        // Count sessions in this block for the collapsed state
        int blockSessionCount = 0;
        for (final weekSessions in grouped[block]!.values) {
          blockSessionCount += weekSessions.length;
        }
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: Spacing.xl, bottom: Spacing.sm),
            child: Text('$blockSessionCount sessions', style: AppTypography.bodySmall),
          ),
        );
        // Count global index past all sessions in this block
        for (final weekSessions in grouped[block]!.values) {
          globalIndex += weekSessions.length;
        }
        continue;
      }

      // Sort weeks within block (newest first)
      final sortedWeeks = grouped[block]!.keys.toList()..sort((a, b) => b.compareTo(a));

      for (final week in sortedWeeks) {
        final weekKey = 'block_${block}_week_$week';
        final isWeekCollapsed = _collapsedWeeks.contains(weekKey);
        final weekSessions = grouped[block]![week]!;

        // Week header
        widgets.add(
          GestureDetector(
            onTap: () => setState(() {
              if (isWeekCollapsed) _collapsedWeeks.remove(weekKey);
              else _collapsedWeeks.add(weekKey);
            }),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: Spacing.lg, top: Spacing.md, bottom: Spacing.sm),
              child: Row(
                children: [
                  Icon(
                    isWeekCollapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                    color: AppColors.textSecondary, size: 18,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text('WEEK $week', style: AppTypography.label.copyWith(fontSize: 12)),
                  const SizedBox(width: Spacing.sm),
                  Text('${weekSessions.length} session${weekSessions.length == 1 ? '' : 's'}', style: AppTypography.labelSmall),
                ],
              ),
            ),
          ),
        );

        if (isWeekCollapsed) {
          globalIndex += weekSessions.length;
          continue;
        }

        // Sessions within the week
        for (final session in weekSessions) {
          final sessionIndex = globalIndex;
          final isExpanded = _expandedSessions.contains(sessionIndex);
          widgets.add(_buildSessionRow(sessionIndex, session, isExpanded));
          globalIndex++;
        }
      }
    }

    return widgets;
  }

  // ─── Session Row ───

  Widget _buildSessionRow(int index, dynamic session, bool isExpanded) {
    final dateStr = session['date']?.toString();
    String dayName = '';
    String dateFormatted = '';
    if (dateStr != null) {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        dayName = DateFormat('EEEE').format(dt);
        dateFormatted = DateFormat('MMM d').format(dt);
      }
    }
    final exercises = session['exercises'] as List? ?? [];
    final dur = SessionUtils.getSessionDuration(session);

    // Main lifts summary
    final liftNames = exercises
        .map((e) => e['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .take(3)
        .toList();
    final liftSummary = liftNames.isNotEmpty ? liftNames.join(' + ') : 'Training';

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) _expandedSessions.remove(index);
          else _expandedSessions.add(index);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.sm, left: Spacing.lg),
        padding: const EdgeInsets.all(Spacing.base),
        decoration: BoxDecoration(
          color: isExpanded ? AppColors.cardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact row
            Row(
              children: [
                // Day + date
                SizedBox(
                  width: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dayName.isNotEmpty ? dayName.substring(0, 3) : '', style: AppTypography.label),
                      Text(dateFormatted, style: AppTypography.bodySmall.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.md),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(liftSummary, style: AppTypography.h3.copyWith(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(dur, style: AppTypography.labelSmall),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted, size: 20,
                ),
              ],
            ),
            // Expanded detail
            if (isExpanded) ...[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.base),
                child: Container(height: 0.5, color: AppColors.borderColor),
              ),
              const SizedBox(height: Spacing.base),
              _buildCompactStats(session),
              const SizedBox(height: Spacing.base),
              ...exercises.map((ex) => _buildExerciseDetail(ex)).toList(),
              _buildNotes(session),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStats(dynamic session) {
    final vol = SessionUtils.getSessionVolume(session);
    final sets = SessionUtils.getSessionSets(session);
    final exercises = session['exercises'] as List? ?? [];
    return Row(
      children: [
        _buildStatPill('${exercises.length} exercises'),
        const SizedBox(width: Spacing.sm),
        _buildStatPill('${vol.toStringAsFixed(0)} kg vol'),
        const SizedBox(width: Spacing.sm),
        _buildStatPill('$sets sets'),
      ],
    );
  }

  Widget _buildStatPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: AppTypography.labelSmall.copyWith(fontSize: 11)),
    );
  }

  Widget _buildExerciseDetail(dynamic ex) {
    final name = ex['name']?.toString() ?? 'Unknown';
    final setsList = ex['sets'] as List? ?? [];
    final exPct = ex['percentage'];
    final backoffPct = ex['backoffPercentage'];

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              if (exPct != null) ...[
                const SizedBox(width: Spacing.sm),
                Text('— ${exPct}%', style: AppTypography.bodySmall.copyWith(color: AppColors.accentBlue, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
              if (backoffPct != null) ...[
                const SizedBox(width: Spacing.xs),
                Text('(${backoffPct}% bo)', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ...setsList.asMap().entries.map((entry) {
            final s = entry.value;
            final w = s['weight']?.toString() ?? '0';
            final r = s['reps']?.toString() ?? '0';
            final c = int.tryParse(s['sets']?.toString() ?? '1') ?? 1;
            final pct = s['percentage'];

            final display = c > 1 ? '$w × $r × $c' : '$w × $r';
            String? pctStr;
            if (pct != null) {
              final pctNum = double.tryParse(pct.toString());
              if (pctNum != null && pctNum > 0) pctStr = '${pctNum.toStringAsFixed(0)}%';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Text(display, style: AppTypography.mono.copyWith(fontSize: 13, color: AppColors.textSecondary)),
                  if (pctStr != null) ...[
                    const SizedBox(width: Spacing.sm),
                    Text('— $pctStr', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ],
              ),
            );
          }).toList(),
          // Exercise note
          if (ex['note'] != null && (ex['note']?.toString().trim() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                ex['note'].toString().trim(),
                style: AppTypography.bodySmall.copyWith(fontStyle: FontStyle.italic, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotes(dynamic session) {
    final noteText = (session['note']?.toString().trim().isNotEmpty == true)
        ? session['note'].toString()
        : (session['notes']?.toString().trim().isNotEmpty == true)
            ? session['notes'].toString()
            : null;
    if (noteText == null || noteText.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes', style: AppTypography.label),
          const SizedBox(height: Spacing.xs),
          Text(noteText, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
