import 'package:flutter/material.dart';
import '../services/api_service.dart';
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
            // Header row
            Row(
              children: [
                // Block badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2)),
                  ),
                  child: Text('Block ${session['block']}',
                      style: const TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                if (session['percentage'] != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.2)),
                    ),
                    child: Text('${session['percentage']}%',
                        style: const TextStyle(color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                  ),
                ],
                const SizedBox(width: 6),
                // Day badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.2)),
                  ),
                  child: Text(session['day'] ?? '',
                      style: const TextStyle(color: AppTheme.accentAmber, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                // Edit/Delete
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.text500),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddSessionScreen(existingSession: session)),
                    );
                    if (result == true) onRefresh?.call();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.text500),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.bg850,
                        title: const Text('Delete Session?'),
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
                      } catch (_) {}
                    }
                  },
                ),
              ],
            ),
            if (formattedDate != null) ...[
              const SizedBox(height: 6),
              Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppTheme.text500)),
            ],
            const SizedBox(height: 10),

            // Exercises
            if (mainLifts.isNotEmpty) ..._buildLifts(mainLifts, 'Main Lifts', AppTheme.accentRed),
            if (secondary.isNotEmpty) ..._buildLifts(secondary, 'Secondary', AppTheme.accentBlue),
            if (accessories.isNotEmpty) ..._buildLifts(accessories, 'Accessories', AppTheme.accentGreen),

            // Notes
            if (session['notes'] != null && (session['notes'] as String).isNotEmpty) ...[
              const Divider(height: 20, color: AppTheme.bg700),
              Text(session['notes'], style: const TextStyle(fontSize: 12, color: AppTheme.text400, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLifts(List<dynamic> lifts, String title, Color color) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
      ),
      ...lifts.map((ex) {
        final sets = ex['sets'] as List? ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(ex['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text200)),
              ),
              Expanded(
                flex: 4,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: sets.map<Widget>((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bg800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${s['weight']}kg × ${s['reps']}${(s['sets'] ?? 1) > 1 ? ' (${s['sets']}s)' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.text300, fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }),
    ];
  }
}
