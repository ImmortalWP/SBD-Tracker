import 'dart:math' as math;

/// Represents a single data point for a lift's strength over time.
class StrengthPoint {
  final DateTime date;
  final double value; // e1RM or top set weight
  final String label; // e.g. "W3" or "Apr 12"

  StrengthPoint({required this.date, required this.value, required this.label});
}

/// Represents weekly volume data.
class VolumePoint {
  final DateTime weekStart;
  final double volume;
  final String label;

  VolumePoint({required this.weekStart, required this.volume, required this.label});
}

/// Weekly progress for a single lift.
class LiftProgress {
  final String lift;
  final double current;
  final double previous;
  final double change;
  final double changePercent;
  final TrendDirection trend;

  LiftProgress({
    required this.lift,
    required this.current,
    required this.previous,
    required this.change,
    required this.changePercent,
    required this.trend,
  });
}

enum TrendDirection { up, down, flat, plateau }

/// Smart insight generated from the data.
class Insight {
  final String text;
  final InsightType type;

  Insight({required this.text, required this.type});
}

enum InsightType { positive, warning, neutral }

/// Time range for filtering analytics data.
enum TimeRange {
  days7('7D', 7),
  weeks4('4W', 28),
  weeks12('12W', 84),
  months6('6M', 180);

  final String label;
  final int days;
  const TimeRange(this.label, this.days);
}

class AnalyticsProcessor {
  final List<dynamic> sessions;

  AnalyticsProcessor(this.sessions);

  /// Epley formula: e1RM = weight × (1 + reps/30)
  static double estimateE1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  /// Filter sessions by time range.
  List<dynamic> _filterByRange(TimeRange range) {
    final cutoff = DateTime.now().subtract(Duration(days: range.days));
    return sessions.where((s) {
      final d = DateTime.tryParse(s['date']?.toString() ?? '');
      return d != null && d.isAfter(cutoff);
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return da.compareTo(db);
      });
  }

  /// Check if an exercise name matches a lift category.
  static bool _isLift(String name, String lift) {
    final n = name.toLowerCase();
    switch (lift) {
      case 'Squat':
        return n.contains('squat') && !n.contains('split');
      case 'Bench':
        return n.contains('bench') || n.contains('larsen');
      case 'Deadlift':
        return n.contains('dead') || (n.contains('rdl') && !n.contains('accessory'));
      default:
        return false;
    }
  }

  /// Get strength trend points for a specific lift.
  List<StrengthPoint> getStrengthTrend(String lift, TimeRange range) {
    final filtered = _filterByRange(range);
    final points = <StrengthPoint>[];

    for (final session in filtered) {
      final date = DateTime.tryParse(session['date']?.toString() ?? '');
      if (date == null) continue;

      double bestE1RM = 0;
      for (final ex in (session['exercises'] as List? ?? [])) {
        final name = ex['name']?.toString() ?? '';
        if (!_isLift(name, lift)) continue;

        for (final set in (ex['sets'] as List? ?? [])) {
          final w = (set['weight'] as num?)?.toDouble() ?? 0;
          final r = (set['reps'] as num?)?.toInt() ?? 0;
          final e1rm = estimateE1RM(w, r);
          if (e1rm > bestE1RM) bestE1RM = e1rm;
        }
      }

      if (bestE1RM > 0) {
        final label = '${date.month}/${date.day}';
        points.add(StrengthPoint(date: date, value: bestE1RM, label: label));
      }
    }

    return points;
  }

  /// Get weekly volume trend.
  List<VolumePoint> getVolumeTrend(TimeRange range) {
    final filtered = _filterByRange(range);
    if (filtered.isEmpty) return [];

    // Group by ISO week
    final Map<String, double> weekVolumes = {};
    final Map<String, DateTime> weekStarts = {};

    for (final session in filtered) {
      final date = DateTime.tryParse(session['date']?.toString() ?? '');
      if (date == null) continue;

      // Get Monday of that week
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final key = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      weekStarts.putIfAbsent(key, () => monday);
      weekVolumes.putIfAbsent(key, () => 0);

      for (final ex in (session['exercises'] as List? ?? [])) {
        final name = (ex['name']?.toString() ?? '').toLowerCase();
        // Only count SBD + direct variations for volume
        if (name.contains('squat') || name.contains('bench') || name.contains('larsen') ||
            name.contains('dead') || name.contains('rdl')) {
          for (final set in (ex['sets'] as List? ?? [])) {
            final w = (set['weight'] as num?)?.toDouble() ?? 0;
            final r = (set['reps'] as num?)?.toInt() ?? 0;
            final c = (set['sets'] as num?)?.toInt() ?? 1;
            weekVolumes[key] = weekVolumes[key]! + (w * r * c);
          }
        }
      }
    }

    final sortedKeys = weekVolumes.keys.toList()..sort();
    return sortedKeys.map((key) {
      final ws = weekStarts[key]!;
      return VolumePoint(
        weekStart: ws,
        volume: weekVolumes[key]!,
        label: '${ws.month}/${ws.day}',
      );
    }).toList();
  }

  /// Get weekly progress for S/B/D.
  List<LiftProgress> getWeeklyProgress(TimeRange range) {
    final lifts = ['Squat', 'Bench', 'Deadlift'];
    final progress = <LiftProgress>[];

    for (final lift in lifts) {
      final points = getStrengthTrend(lift, range);
      if (points.length < 2) {
        if (points.isNotEmpty) {
          progress.add(LiftProgress(
            lift: lift,
            current: points.last.value,
            previous: 0,
            change: 0,
            changePercent: 0,
            trend: TrendDirection.flat,
          ));
        }
        continue;
      }

      // Compare last 2 data points
      final current = points.last.value;
      final previous = points[points.length - 2].value;
      final change = current - previous;
      final pct = previous > 0 ? (change / previous) * 100 : 0.0;

      // Detect plateau: last 3+ points within 2% of each other
      TrendDirection trend;
      if (points.length >= 3) {
        final last3 = points.sublist(points.length - 3);
        final avg = last3.map((p) => p.value).reduce((a, b) => a + b) / 3;
        final allClose = last3.every((p) => (p.value - avg).abs() / avg < 0.02);
        if (allClose) {
          trend = TrendDirection.plateau;
        } else if (change > 0) {
          trend = TrendDirection.up;
        } else if (change < 0) {
          trend = TrendDirection.down;
        } else {
          trend = TrendDirection.flat;
        }
      } else {
        trend = change > 0 ? TrendDirection.up : (change < 0 ? TrendDirection.down : TrendDirection.flat);
      }

      progress.add(LiftProgress(
        lift: lift,
        current: current,
        previous: previous,
        change: change,
        changePercent: pct,
        trend: trend,
      ));
    }

    return progress;
  }

  /// Generate 2–3 smart insights.
  List<Insight> getInsights(TimeRange range) {
    final insights = <Insight>[];
    final progress = getWeeklyProgress(range);
    final volumeTrend = getVolumeTrend(range);

    // 1. Check for PRs / best e1RM in range
    for (final lift in ['Squat', 'Bench', 'Deadlift']) {
      if (insights.length >= 3) break;
      final points = getStrengthTrend(lift, range);
      if (points.length >= 2) {
        final allValues = points.map((p) => p.value).toList();
        final maxVal = allValues.reduce(math.max);
        if (points.last.value == maxVal && points.last.value > points[points.length - 2].value) {
          insights.add(Insight(
            text: '$lift hit a new peak e1RM of ${maxVal.toStringAsFixed(0)}kg',
            type: InsightType.positive,
          ));
        }
      }
    }

    // 2. Detect plateaus
    for (final p in progress) {
      if (insights.length >= 3) break;
      if (p.trend == TrendDirection.plateau) {
        insights.add(Insight(
          text: '${p.lift} has plateaued — consider adjusting programming',
          type: InsightType.warning,
        ));
      }
    }

    // 3. Volume trend analysis
    if (volumeTrend.length >= 2 && insights.length < 3) {
      final lastVol = volumeTrend.last.volume;
      final prevVol = volumeTrend[volumeTrend.length - 2].volume;
      if (prevVol > 0) {
        final pct = ((lastVol - prevVol) / prevVol) * 100;
        if (pct > 15) {
          insights.add(Insight(
            text: 'Volume up ${pct.toStringAsFixed(0)}% this week — manage fatigue',
            type: InsightType.warning,
          ));
        } else if (pct < -15) {
          insights.add(Insight(
            text: 'Volume dropped ${pct.abs().toStringAsFixed(0)}% — possible deload or missed sessions',
            type: InsightType.warning,
          ));
        } else if (pct > 0) {
          insights.add(Insight(
            text: 'Consistent volume progression (+${pct.toStringAsFixed(0)}%)',
            type: InsightType.positive,
          ));
        }
      }
    }

    // 4. Strongest lift trending
    if (insights.length < 3) {
      final upLifts = progress.where((p) => p.trend == TrendDirection.up).toList();
      if (upLifts.isNotEmpty) {
        final best = upLifts.reduce((a, b) => a.changePercent > b.changePercent ? a : b);
        insights.add(Insight(
          text: '${best.lift} progressing strongest (+${best.changePercent.toStringAsFixed(1)}%)',
          type: InsightType.positive,
        ));
      }
    }

    // 5. Session frequency
    if (insights.length < 3) {
      final filtered = _filterByRange(range);
      final weeks = range.days / 7.0;
      final freq = filtered.length / weeks;
      if (freq >= 4) {
        insights.add(Insight(
          text: 'Averaging ${freq.toStringAsFixed(1)} sessions/week — solid consistency',
          type: InsightType.positive,
        ));
      } else if (freq < 2 && filtered.isNotEmpty) {
        insights.add(Insight(
          text: 'Only ${freq.toStringAsFixed(1)} sessions/week — try to increase frequency',
          type: InsightType.warning,
        ));
      }
    }

    // Fallback
    if (insights.isEmpty) {
      insights.add(Insight(
        text: 'Keep logging sessions to unlock deeper insights',
        type: InsightType.neutral,
      ));
    }

    return insights.take(3).toList();
  }
}
