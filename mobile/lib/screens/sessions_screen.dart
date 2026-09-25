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
  final Set<int> _expandedIndices = {0};
  String _exerciseSearch = '';
  DateTimeRange? _dateRange;

  List<dynamic> get _filteredSessions {
    return widget.sessions.where((session) {
      // Date range filter
      if (_dateRange != null) {
        final dateStr = session['date']?.toString();
        if (dateStr != null) {
          final dt = DateTime.tryParse(dateStr);
          if (dt != null) {
            if (dt.isBefore(_dateRange!.start) || dt.isAfter(_dateRange!.end.add(const Duration(days: 1)))) return false;
          }
        }
      }
      // Exercise name filter
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSessions;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                      suffixIcon: (_exerciseSearch.isNotEmpty || _dateRange != null)
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                              onPressed: () => setState(() { _exerciseSearch = ''; _dateRange = null; }),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                // Date range chip
                GestureDetector(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.accentBlue,
                            surface: AppColors.cardBg,
                            onSurface: AppColors.textPrimary,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => _dateRange = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: _dateRange != null ? AppColors.accentBlueBg : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range, size: 14, color: _dateRange != null ? AppColors.accentBlueLight : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          _dateRange != null
                              ? '${DateFormat('MMM d').format(_dateRange!.start)} – ${DateFormat('MMM d').format(_dateRange!.end)}'
                              : 'Date range',
                          style: AppTypography.labelSmall.copyWith(
                            color: _dateRange != null ? AppColors.accentBlueLight : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.base),
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
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 100),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final session = filtered[index];
                        final isExpanded = _expandedIndices.contains(index);
                        return _buildSessionRow(index, session, isExpanded);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Session Row ───

  Widget _buildSessionRow(int index, Map<String, dynamic> session, bool isExpanded) {
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
    final weekStr = session['week']?.toString() ?? '';
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
          if (isExpanded) { _expandedIndices.remove(index); }
          else { _expandedIndices.add(index); }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.sm),
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
                // Date column
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
                      Text(
                        '${weekStr.isNotEmpty ? 'W$weekStr • ' : ''}$dur',
                        style: AppTypography.labelSmall,
                      ),
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
              // Summary stats
              _buildCompactStats(session),
              const SizedBox(height: Spacing.base),
              // Exercises
              ...exercises.map((ex) => _buildExerciseDetail(ex)).toList(),
              // Notes
              _buildNotes(session),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStats(Map<String, dynamic> session) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: Spacing.sm),
          ...setsList.asMap().entries.map((entry) {
            final s = entry.value;
            final w = s['weight']?.toString() ?? '0';
            final r = s['reps']?.toString() ?? '0';
            final c = int.tryParse(s['sets']?.toString() ?? '1') ?? 1;
            final display = c > 1 ? '$w × $r × $c' : '$w × $r';
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(display, style: AppTypography.mono.copyWith(fontSize: 13, color: AppColors.textSecondary)),
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

  Widget _buildNotes(Map<String, dynamic> session) {
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
