import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
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

  int? _selectedBlock;
  int? _selectedWeek;
  String? _selectedDay;

  List<dynamic> get _filteredSessions {
    return widget.sessions.where((session) {
      if (_selectedBlock != null && session['block'] != _selectedBlock) return false;
      if (_selectedWeek != null && session['week'] != _selectedWeek) return false;
      if (_selectedDay != null && session['day'] != _selectedDay) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSessions;
    return Scaffold(
      backgroundColor: Colors.transparent, // Uses Dashboard background
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(filtered.length),
            _buildFiltersRow(),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                color: AppColors.accentBlue,
                backgroundColor: AppColors.cardBg,
                child: filtered.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.only(top: 40),
                      children: const [
                        Center(child: Text('No sessions found', style: TextStyle(color: AppColors.textMuted, fontSize: 14))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final session = filtered[index];
                        final isExpanded = _expandedIndices.contains(index);
                        return _buildSessionCard(index, session, isExpanded);
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    final auth = context.read<AuthService>();
    final username = auth.username ?? 'Lifter';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Training Log',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.3),
              ),
              const SizedBox(height: 4),
              Text(
                '$count sessions found',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(username, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedBlock = null;
                          _selectedWeek = null;
                          _selectedDay = null;
                        });
                        setState(() {
                          _selectedBlock = null;
                          _selectedWeek = null;
                          _selectedDay = null;
                        });
                      },
                      child: const Text('Clear', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Day', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedDay,
                  decoration: const InputDecoration(filled: true, fillColor: AppColors.inputBg, border: OutlineInputBorder()),
                  dropdownColor: AppColors.cardBg,
                  style: const TextStyle(color: AppColors.textPrimary),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Days')),
                    ...['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((d) => DropdownMenuItem(value: d, child: Text(d))),
                  ],
                  onChanged: (v) {
                    setModalState(() => _selectedDay = v);
                    setState(() => _selectedDay = v);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Apply', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  List<int> get _availableBlocks {
    final blocks = <int>{};
    for (final s in widget.sessions) {
      final b = s['block'];
      if (b != null) blocks.add(b is int ? b : int.tryParse(b.toString()) ?? 1);
    }
    final sorted = blocks.toList()..sort();
    return sorted.isEmpty ? [1] : sorted;
  }

  List<int> get _availableWeeks {
    final weeks = <int>{};
    for (final s in widget.sessions) {
      final w = s['week'];
      if (w != null) weeks.add(w is int ? w : int.tryParse(w.toString()) ?? 1);
    }
    final sorted = weeks.toList()..sort();
    return sorted.isEmpty ? [1] : sorted;
  }

  Widget _buildFiltersRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Block dropdown
            PopupMenuButton<int?>(
              onSelected: (val) => setState(() => _selectedBlock = val),
              color: AppColors.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => [
                PopupMenuItem<int?>(value: null, child: Text('All Blocks', style: TextStyle(color: _selectedBlock == null ? AppColors.accentBlueLight : AppColors.textPrimary))),
                ..._availableBlocks.map((b) => PopupMenuItem<int?>(value: b, child: Text('Block $b', style: TextStyle(color: _selectedBlock == b ? AppColors.accentBlueLight : AppColors.textPrimary)))),
              ],
              child: _buildFilterBtn(Icons.grid_view, _selectedBlock != null ? 'Block $_selectedBlock' : 'All Blocks', true, _selectedBlock != null),
            ),
            const SizedBox(width: 12),
            // Week dropdown
            PopupMenuButton<int?>(
              onSelected: (val) => setState(() => _selectedWeek = val),
              color: AppColors.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => [
                PopupMenuItem<int?>(value: null, child: Text('All Weeks', style: TextStyle(color: _selectedWeek == null ? AppColors.accentBlueLight : AppColors.textPrimary))),
                ..._availableWeeks.map((w) => PopupMenuItem<int?>(value: w, child: Text('Week $w', style: TextStyle(color: _selectedWeek == w ? AppColors.accentBlueLight : AppColors.textPrimary)))),
              ],
              child: _buildFilterBtn(Icons.calendar_month, _selectedWeek != null ? 'Week $_selectedWeek' : 'All Weeks', true, _selectedWeek != null),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _showFilterSheet,
              child: _buildFilterBtn(Icons.filter_alt_outlined, _selectedDay ?? 'Day', false, _selectedDay != null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBtn(IconData icon, String label, bool hasDropdown, [bool isActive = false]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accentBlueBg : AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? AppColors.accentBlue : AppColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isActive ? AppColors.accentBlueLight : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? AppColors.accentBlueLight : AppColors.textPrimary)),
          if (hasDropdown) ...[
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, size: 16, color: isActive ? AppColors.accentBlueLight : AppColors.textSecondary),
          ]
        ],
      ),
    );
  }

  // --- Calculations for Session Summary ---

  double _getSessionVolume(Map<String, dynamic> session) => SessionUtils.getSessionVolume(session);

  int _getSessionSets(Map<String, dynamic> session) => SessionUtils.getSessionSets(session);

  String _getSessionDuration(Map<String, dynamic> session) => SessionUtils.getSessionDuration(session);

  // --- Main Card Builder ---

  Widget _buildSessionCard(int index, Map<String, dynamic> session, bool isExpanded) {
    final dateStr = session['date']?.toString();
    String formattedDate = 'Unknown Date';
    if (dateStr != null) {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        formattedDate = DateFormat('EEE, MMM d').format(dt);
      }
    }
    final weekStr = session['week']?.toString() ?? '1';
    final title = '$formattedDate • Week $weekStr';

    final exercises = session['exercises'] as List? ?? [];
    final vol = _getSessionVolume(session);
    final sets = _getSessionSets(session);
    final dur = _getSessionDuration(session);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedIndices.remove(index);
          } else {
            _expandedIndices.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: isExpanded ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (!isExpanded)
                  Row(
                    children: [
                      Text(
                        '${vol.toStringAsFixed(0)} kg • $sets sets • $dur',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
                    ],
                  )
                else
                  const Icon(Icons.keyboard_arrow_up, color: AppColors.textPrimary, size: 20),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.borderColor),
              const SizedBox(height: 16),
              _buildExpandedSummaryRow(exercises.length, vol, sets, dur),
              const SizedBox(height: 24),
              ...exercises.map((ex) => _ExerciseHistoryTile(ex: ex)).toList(),
              // Check both 'note' and 'notes' for backward compatibility
              Builder(builder: (_) {
                final noteText = (session['note']?.toString().trim().isNotEmpty == true)
                    ? session['note'].toString()
                    : (session['notes']?.toString().trim().isNotEmpty == true)
                        ? session['notes'].toString()
                        : null;
                if (noteText == null || noteText.trim().isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notes', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(noteText, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSummaryRow(int exCount, double vol, int sets, String dur) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSummaryStat(Icons.fitness_center, AppColors.accentBlueLight, '$exCount', 'Exercises'),
        _buildSummaryStat(Icons.signal_cellular_alt, AppColors.accentGreen, '${vol.toStringAsFixed(0)} kg', 'Volume'),
        _buildSummaryStat(Icons.trending_up, AppColors.statYellow, '$sets', 'Total Sets'),
        _buildSummaryStat(Icons.access_time, AppColors.statPurple, dur, 'Duration'),
      ],
    );
  }

  Widget _buildSummaryStat(IconData icon, Color iconColor, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

}

class _ExerciseHistoryTile extends StatefulWidget {
  final dynamic ex;
  const _ExerciseHistoryTile({required this.ex});

  @override
  State<_ExerciseHistoryTile> createState() => _ExerciseHistoryTileState();
}

class _ExerciseHistoryTileState extends State<_ExerciseHistoryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.ex['name']?.toString() ?? 'Unknown Lift';
    final pct = widget.ex['percentage']?.toString();
    final backoffPct = widget.ex['backoffPercentage']?.toString();
    final setsList = widget.ex['sets'] as List? ?? [];
    
    double maxWeight = 0;
    int maxReps = 1;
    int totalSets = 0;
    for (var s in setsList) {
      final w = double.tryParse(s['weight']?.toString() ?? '0') ?? 0;
      final r = int.tryParse(s['reps']?.toString() ?? '0') ?? 0;
      final c = int.tryParse(s['sets']?.toString() ?? '1') ?? 1;
      totalSets += c;
      if (w > maxWeight) {
        maxWeight = w;
        maxReps = r;
      }
    }

    final topSetStr = maxWeight > 0 ? '${maxWeight.toString().replaceAll('.0', '')} × $maxReps' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.accentBlueLight, width: 3)),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accentBlueLight)),
                          if (pct != null && pct.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text('— $pct%', style: const TextStyle(fontSize: 14, color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
                          ],
                          if (backoffPct != null && backoffPct.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('($backoffPct% backoff)', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                      Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Top: ', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      Text(topSetStr, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                      const SizedBox(width: 16),
                      const Text('Sets: ', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      Text('$totalSets', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(flex: 1, child: Text('SET', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
                        Expanded(flex: 2, child: Center(child: Text('WEIGHT', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)))),
                        Expanded(flex: 2, child: Center(child: Text('REPS', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._buildSetRows(setsList),
                    // Exercise note
                    if (widget.ex['note'] != null && (widget.ex['note']?.toString().trim() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.ex['note'].toString().trim(),
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSetRows(List dynamicSets) {
    List<Widget> rows = [];
    int setIndex = 1;
    
    for (var s in dynamicSets) {
      final w = s['weight']?.toString() ?? '0';
      final r = s['reps']?.toString() ?? '0';
      final c = int.tryParse(s['sets']?.toString() ?? '1') ?? 1;
      
      for (int i = 0; i < c; i++) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(flex: 1, child: Text('$setIndex', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
                Expanded(flex: 2, child: Center(child: Text(w, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'monospace')))),
                Expanded(flex: 2, child: Center(child: Text(r, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'monospace')))),
              ],
            ),
          )
        );
        setIndex++;
      }
    }
    
    return rows;
  }
}
