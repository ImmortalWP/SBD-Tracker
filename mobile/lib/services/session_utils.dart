/// Shared utility functions for session data calculations.
/// Extracted from duplicated logic in dashboard_screen, sessions_screen, and session_card.
class SessionUtils {
  SessionUtils._();

  /// Calculate total training volume for a session (weight × reps × sets).
  static double getSessionVolume(Map<String, dynamic> session) {
    double vol = 0;
    final exercises = session['exercises'] as List? ?? [];
    for (final ex in exercises) {
      for (final set in (ex['sets'] as List? ?? [])) {
        final w = double.tryParse(set['weight']?.toString() ?? '0') ?? 0;
        final r = int.tryParse(set['reps']?.toString() ?? '0') ?? 0;
        final c = int.tryParse(set['sets']?.toString() ?? '1') ?? 1;
        vol += w * r * c;
      }
    }
    return vol;
  }

  /// Count total sets in a session.
  static int getSessionSets(Map<String, dynamic> session) {
    int total = 0;
    final exercises = session['exercises'] as List? ?? [];
    for (final ex in exercises) {
      for (final set in (ex['sets'] as List? ?? [])) {
        final c = int.tryParse(set['sets']?.toString() ?? '1') ?? 1;
        total += c;
      }
    }
    return total;
  }

  /// Get formatted duration string from a session.
  static String getSessionDuration(Map<String, dynamic> session) {
    // Try durationInMinutes first (what the app saves on submit)
    final dMin = session['durationInMinutes'];
    if (dMin != null) {
      final m = int.tryParse(dMin.toString()) ?? 0;
      if (m > 0) return _formatMinutes(m);
    }
    // Fallback to legacy 'duration' field
    final dur = session['duration'];
    if (dur != null) {
      final m = int.tryParse(dur.toString()) ?? 0;
      if (m > 0) return _formatMinutes(m);
    }
    // Fallback to elapsedSeconds
    final s = session['elapsedSeconds'];
    if (s != null) {
      final int sec = s is int ? s : (int.tryParse(s.toString()) ?? 0);
      final h = sec ~/ 3600;
      final m = (sec % 3600) ~/ 60;
      if (h > 0) return '${h}h ${m}m';
      return '$m min';
    }
    return '— min';
  }

  /// Get the max weight lifted in a session.
  static double getMaxWeight(Map<String, dynamic> ex) {
    final sets = ex['sets'] as List? ?? [];
    double max = 0;
    for (final st in sets) {
      final w = (st['weight'] as num?)?.toDouble() ?? 0.0;
      if (w > max) max = w;
    }
    return max;
  }

  static String _formatMinutes(int m) {
    if (m >= 60) {
      final h = m ~/ 60;
      final rm = m % 60;
      return rm > 0 ? '${h}h ${rm}m' : '${h}h';
    }
    return '$m min';
  }
}
