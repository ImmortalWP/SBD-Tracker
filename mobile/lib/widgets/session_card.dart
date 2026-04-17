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
        formattedDate = DateFormat('EEE, MMM d').format(dt);
      } catch (_) {}
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.bg800.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge('Block ${session['block']}', AppTheme.accentRed),
                          if (session['week'] != null) _badge('Week ${session['week']}', AppTheme.accentBlue),
                          if (session['percentage'] != null) _badge('${session['percentage']}%', AppTheme.accentGreen),
                          _badge(session['day'] ?? '', AppTheme.accentAmber),
                        ],
                      ),
                      if (formattedDate != null) ...[
                        const SizedBox(height: 6),
                        Text(formattedDate, style: const TextStyle(fontSize: 12, color: AppTheme.text500)),
                      ],
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.text500, size: 20),
                  color: AppTheme.bg850,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (v) {
                    if (v == 'edit') _handleEdit(context);
                    if (v == 'delete') _handleDelete(context);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: AppTheme.text400), SizedBox(width: 8), Text('Edit')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppTheme.accentRed), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppTheme.accentRed))])),
                  ],
                ),
              ],
            ),
          ),

          // Exercises - Lyfta style: big bold weight, clear layout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mainLifts.isNotEmpty) _buildExerciseGroup(mainLifts, AppTheme.accentRed),
                if (secondary.isNotEmpty) _buildExerciseGroup(secondary, AppTheme.accentBlue),
                if (accessories.isNotEmpty) _buildExerciseGroup(accessories, AppTheme.accentGreen),
              ],
            ),
          ),

          // Notes
          if (session['notes'] != null && (session['notes'] as String).isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bg900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 14, color: AppTheme.text500),
                  const SizedBox(width: 8),
                  Expanded(child: Text(session['notes'], style: const TextStyle(fontSize: 13, color: AppTheme.text400, fontStyle: FontStyle.italic))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildExerciseGroup(List<dynamic> exercises, Color color) {
    return Column(
      children: exercises.map((ex) {
        final sets = ex['sets'] as List? ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exercise name - BIG
              Row(
                children: [
                  Container(
                    width: 4, height: 20,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ex['name'],
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.text50, letterSpacing: -0.3),
                    ),
                  ),
                  // Total volume badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.bg800,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${sets.length} ${sets.length == 1 ? 'set' : 'sets'}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.text500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Sets - each row is clear and readable
              ...sets.asMap().entries.map((entry) {
                final s = entry.value;
                final weight = s['weight'];
                final reps = s['reps'];
                final numSets = s['sets'] ?? 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bg900.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // Set indicator
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.15),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text('${entry.key + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Weight - BIG AND BOLD
                      Text('$weight', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
                      Text(' kg', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7))),
                      const Spacer(),
                      // Sets × Reps
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.bg800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (numSets > 1) ...[
                              Text('$numSets', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text200, fontFamily: 'monospace')),
                              const Text(' × ', style: TextStyle(fontSize: 13, color: AppTheme.text500)),
                            ],
                            Text('$reps', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text200, fontFamily: 'monospace')),
                            const Text(' reps', style: TextStyle(fontSize: 11, color: AppTheme.text500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _handleEdit(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddSessionScreen(existingSession: session)),
    );
    if (result == true) onRefresh?.call();
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
        final errMsg = e.toString();
        if (errMsg.contains('SocketException') || errMsg.contains('ClientException') || errMsg.contains('Connection')) {
          await OfflineQueue.enqueue({'type': 'delete', 'sessionId': session['_id']});
          onDelete?.call(session['_id']);
        }
      }
    }
  }
}
