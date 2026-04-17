import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/offline_queue.dart';
import '../screens/add_session_screen.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final Function(String)? onDelete;
  final VoidCallback? onRefresh;

  const SessionCard({
    super.key,
    required this.session,
    this.onDelete,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final exercises = session['exercises'] as List? ?? [];
    final mainLifts = exercises.where((e) => e['category'] == 'main').toList();
    final secondary = exercises.where((e) => e['category'] == 'secondary').toList();
    final accessories = exercises.where((e) => e['category'] == 'accessory').toList();

    String? formattedDate;
    if (session['date'] != null) {
      try {
        final dt = DateTime.parse(session['date']);
        formattedDate = DateFormat('MMM d, yyyy').format(dt);
      } catch (_) {}
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row - badges
            Row(
              children: [
                _badge('Block ${session['block']}', AppTheme.accentRed),
                if (session['week'] != null) ...[
                  const SizedBox(width: 6),
                  _badge('W${session['week']}', AppTheme.accentBlue),
                ],
                if (session['percentage'] != null) ...[
                  const SizedBox(width: 6),
                  _badge('${session['percentage']}%', AppTheme.accentGreen),
                ],
                const SizedBox(width: 6),
                _badge(session['day'] ?? '', AppTheme.accentAmber),
                const Spacer(),
                // Edit
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddSessionScreen(existingSession: session)),
                    );
                    if (result == true) onRefresh?.call();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 18, color: AppTheme.text500),
                  ),
                ),
                const SizedBox(width: 4),
                // Delete
                GestureDetector(
                  onTap: () => _handleDelete(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 18, color: AppTheme.text500),
                  ),
                ),
              ],
            ),
            if (formattedDate != null) ...[
              const SizedBox(height: 6),
              Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppTheme.text500)),
            ],
            const SizedBox(height: 12),

            // Exercises - improved table layout
            if (mainLifts.isNotEmpty) _buildExerciseSection('Main Lifts', mainLifts, AppTheme.accentRed),
            if (secondary.isNotEmpty) _buildExerciseSection('Secondary', secondary, AppTheme.accentBlue),
            if (accessories.isNotEmpty) _buildExerciseSection('Accessories', accessories, AppTheme.accentGreen),

            // Notes
            if (session['notes'] != null && (session['notes'] as String).isNotEmpty) ...[
              const Divider(height: 20, color: AppTheme.bg700),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 14, color: AppTheme.text500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(session['notes'], style: const TextStyle(fontSize: 12, color: AppTheme.text400, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildExerciseSection(String title, List<dynamic> lifts, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...lifts.map((ex) {
            final sets = ex['sets'] as List? ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bg900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text100)),
                  const SizedBox(height: 6),
                  // Sets table
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                    },
                    children: [
                      // Header
                      const TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('Set', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 0.5)),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('Weight', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 0.5)),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('Sets', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 0.5)),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('Reps', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                      // Data rows
                      ...sets.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final s = entry.value;
                        return TableRow(
                          decoration: BoxDecoration(
                            border: idx < sets.length - 1
                                ? const Border(bottom: BorderSide(color: AppTheme.bg800, width: 0.5))
                                : null,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, color: AppTheme.text500, fontFamily: 'monospace')),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('${s['weight']} kg', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('${s['sets'] ?? 1}', style: const TextStyle(fontSize: 12, color: AppTheme.text200, fontFamily: 'monospace')),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('${s['reps']}', style: const TextStyle(fontSize: 12, color: AppTheme.text200, fontFamily: 'monospace')),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg850,
        title: const Text('Delete Session?'),
        content: const Text('This action cannot be undone.', style: TextStyle(color: AppTheme.text400)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteSession(session['_id']);
        onDelete?.call(session['_id']);
      } catch (e) {
        // Queue offline delete
        final errMsg = e.toString();
        if (errMsg.contains('SocketException') || errMsg.contains('ClientException') || errMsg.contains('Connection')) {
          await OfflineQueue.enqueue({
            'type': 'delete',
            'sessionId': session['_id'],
          });
          onDelete?.call(session['_id']);
        }
      }
    }
  }
}
