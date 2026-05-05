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
    
    String? formattedDate;
    if (session['date'] != null) {
      try {
        final dt = DateTime.parse(session['date']);
        formattedDate = DateFormat('EEE, MMM d').format(dt);
      } catch (_) {}
    }

    final day = session['day'] ?? 'Day';
    final week = session['week'] != null ? 'Week ${session['week']}' : '';
    int durationMinutes = 0;
    if (session['elapsedSeconds'] != null) {
      durationMinutes = (int.tryParse(session['elapsedSeconds'].toString()) ?? 0) ~/ 60;
    } else if (session['duration'] != null) {
      durationMinutes = (num.tryParse(session['duration'].toString()) ?? 0).toInt();
    }
    
    String durationStr = '';
    if (durationMinutes > 0) {
      final h = durationMinutes ~/ 60;
      final m = durationMinutes % 60;
      if (h > 0) {
        durationStr = '${h}h ${m}m';
      } else {
        durationStr = '${m}min';
      }
    }
    
    final metaParts = [
      if (formattedDate != null) formattedDate else day,
      if (week.isNotEmpty) week,
      if (durationStr.isNotEmpty) durationStr,
    ];
    final metaString = metaParts.join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Text(
                metaString,
                style: const TextStyle(fontSize: 13, color: AppTheme.text500, fontWeight: FontWeight.w500),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.text500, size: 20),
              color: AppTheme.bg850,
              padding: EdgeInsets.zero,
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
        const SizedBox(height: 8),
        
        // Compact Exercise List
        if (exercises.isNotEmpty)
          ...exercises.map((ex) => _buildCompactExerciseRow(ex)),

        // Notes
        if (session['notes'] != null && (session['notes'] as String).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 14, color: AppTheme.text600),
                const SizedBox(width: 8),
                Expanded(child: Text(session['notes'], style: const TextStyle(fontSize: 13, color: AppTheme.text400, fontStyle: FontStyle.italic))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCompactExerciseRow(dynamic ex) {
    final cat = ex['category'];
    Color color = AppTheme.accentGreen;
    if (cat == 'main') color = AppTheme.accentRed;
    else if (cat == 'secondary') color = AppTheme.accentBlue;

    final sets = ex['sets'] as List? ?? [];
    
    final setsDisplay = sets.map((s) {
      final w = s['weight'];
      final r = s['reps'];
      final c = s['sets'] ?? 1;
      final wStr = w.toString().replaceAll('.0', '');
      if (c > 1) {
        return '$c × $wStr kg × $r reps';
      }
      return '$wStr kg × $r reps';
    }).join('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ex['name'],
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.3),
            overflow: TextOverflow.ellipsis,
          ),
          if (setsDisplay.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppTheme.bg800, width: 2)),
              ),
              child: Text(
                setsDisplay,
                style: const TextStyle(fontSize: 13, color: AppTheme.text500, fontFamily: 'monospace', height: 1.5),
              ),
            ),
          ],
          if (ex['note'] != null && (ex['note'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 12, color: AppTheme.text600),
                  const SizedBox(width: 6),
                  Expanded(child: Text(ex['note'], style: const TextStyle(fontSize: 12, color: AppTheme.text400, fontStyle: FontStyle.italic))),
                ],
              ),
            ),
        ],
      ),
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
