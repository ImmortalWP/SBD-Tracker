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

class LiftMetrics {
  final double currentMax;
  final double est1RM;
  final double volume7d;
  final int totalSets;
  final double prevVolume7d;
  final int prevTotalSets;
  final double prevEst1RM;

  LiftMetrics({
    required this.currentMax,
    required this.est1RM,
    required this.volume7d,
    required this.totalSets,
    required this.prevVolume7d,
    required this.prevTotalSets,
    required this.prevEst1RM,
  });
}

enum TrendDirection { up, down, flat, plateau }

/// Smart insight generated from the data.
class Insight {
  final String text;
  final InsightType type;
  final String? subtext;

  Insight({required this.text, required this.type, this.subtext});
}

enum InsightType { positive, warning, neutral }

/// Time range for filtering analytics data.
enum TimeRange {
  days7('Last 7 days', 7),
  days30('Last 30 days', 30),
  thisBlock('This Block', 28),
  thisMonth('This Month', 30),
  months6('Last 6M', 180),
  thisYear('This Year', 365);

  final String label;
  final int days;
  const TimeRange(this.label, this.days);
}

class AnalyticsProcessor {
  final List<dynamic> sessions;

  // ─── Memoization caches ───
  final Map<String, List<dynamic>> _filterCache = {};
  final Map<String, List<StrengthPoint>> _strengthCache = {};
  final Map<String, List<VolumePoint>> _volumeCache = {};
  final Map<String, LiftMetrics> _metricsCache = {};
  final Map<String, List<LiftProgress>> _progressCache = {};
  final Map<String, List<Insight>> _insightsCache = {};
  final Map<String, List<Map<String, dynamic>>> _variationsCache = {};

  AnalyticsProcessor(this.sessions);

  /// Clear all caches (call when session data changes).
  void clearCache() {
    _filterCache.clear();
    _strengthCache.clear();
    _volumeCache.clear();
    _metricsCache.clear();
    _progressCache.clear();
    _insightsCache.clear();
    _variationsCache.clear();
  }

  /// Epley formula: e1RM = weight × (1 + reps/30)
  static double estimateE1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  /// Filter sessions by time range (cached).
  List<dynamic> _filterByRange(TimeRange range) {
    final key = range.name;
    if (_filterCache.containsKey(key)) return _filterCache[key]!;

    DateTime cutoff;
    final now = DateTime.now();
    if (range == TimeRange.thisMonth) {
      cutoff = DateTime(now.year, now.month, 1);
    } else if (range == TimeRange.thisYear) {
      cutoff = DateTime(now.year, 1, 1);
    } else {
      cutoff = now.subtract(Duration(days: range.days));
    }
    
    final result = sessions.where((s) {
      final d = DateTime.tryParse(s['date']?.toString() ?? '');
      return d != null && d.isAfter(cutoff);
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return da.compareTo(db);
      });

    _filterCache[key] = result;
    return result;
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

  /// Get strength trend points for a specific lift (cached).
  List<StrengthPoint> getStrengthTrend(String lift, TimeRange range) {
    final key = '$lift-${range.name}';
    if (_strengthCache.containsKey(key)) return _strengthCache[key]!;

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

    _strengthCache[key] = points;
    return points;
  }

  /// Get weekly volume trend (cached).
  List<VolumePoint> getVolumeTrend(TimeRange range, {String? lift}) {
    final key = '${lift ?? 'all'}-${range.name}';
    if (_volumeCache.containsKey(key)) return _volumeCache[key]!;

    final filtered = _filterByRange(range);
    if (filtered.isEmpty) {
      _volumeCache[key] = [];
      return [];
    }

    final Map<String, double> weekVolumes = {};
    final Map<String, DateTime> weekStarts = {};

    for (final session in filtered) {
      final date = DateTime.tryParse(session['date']?.toString() ?? '');
      if (date == null) continue;

      final monday = date.subtract(Duration(days: date.weekday - 1));
      final wk = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      weekStarts.putIfAbsent(wk, () => monday);
      weekVolumes.putIfAbsent(wk, () => 0);

      for (final ex in (session['exercises'] as List? ?? [])) {
        final name = (ex['name']?.toString() ?? '').toLowerCase();
        bool include = false;
        if (lift != null) {
          include = _isLift(name, lift);
        } else {
          if (name.contains('squat') || name.contains('bench') || name.contains('larsen') ||
              name.contains('dead') || name.contains('rdl')) {
            include = true;
          }
        }

        if (include) {
          for (final set in (ex['sets'] as List? ?? [])) {
            final w = (set['weight'] as num?)?.toDouble() ?? 0;
            final r = (set['reps'] as num?)?.toInt() ?? 0;
            final c = (set['sets'] as num?)?.toInt() ?? 1;
            weekVolumes[wk] = weekVolumes[wk]! + (w * r * c);
          }
        }
      }
    }

    final sortedKeys = weekVolumes.keys.toList()..sort();
    final result = sortedKeys.map((wk) {
      final ws = weekStarts[wk]!;
      return VolumePoint(
        weekStart: ws,
        volume: weekVolumes[wk]!,
        label: '${ws.month}/${ws.day}',
      );
    }).toList();

    _volumeCache[key] = result;
    return result;
  }

  /// Top variations for a lift (cached).
  List<Map<String, dynamic>> getTopVariations(String lift, TimeRange range) {
    final key = '$lift-${range.name}';
    if (_variationsCache.containsKey(key)) return _variationsCache[key]!;

    final filtered = _filterByRange(range);
    final Map<String, double> topWeights = {};

    for (final session in filtered) {
      for (final ex in (session['exercises'] as List? ?? [])) {
        final name = ex['name']?.toString() ?? '';
        if (!_isLift(name, lift)) continue;

        double maxW = 0;
        for (final set in (ex['sets'] as List? ?? [])) {
          final w = (set['weight'] as num?)?.toDouble() ?? 0;
          if (w > maxW) maxW = w;
        }

        if (maxW > (topWeights[name] ?? 0)) {
          topWeights[name] = maxW;
        }
      }
    }

    final list = topWeights.entries.map((e) => {'name': e.key, 'weight': e.value}).toList();
    list.sort((a, b) => (b['weight'] as double).compareTo(a['weight'] as double));

    _variationsCache[key] = list;
    return list;
  }

  /// Lift metrics (cached).
  LiftMetrics getLiftMetrics(String lift, TimeRange range) {
    final key = '$lift-${range.name}';
    if (_metricsCache.containsKey(key)) return _metricsCache[key]!;

    final filtered = _filterByRange(range);
    
    double currentMax = 0;
    double est1RM = 0;
    double prevEst1RM = 0;
    double volume7d = 0;
    double prevVolume7d = 0;
    int totalSets = 0;
    int prevTotalSets = 0;

    final now = DateTime.now();
    final d7 = now.subtract(const Duration(days: 7));
    final d14 = now.subtract(const Duration(days: 14));

    for (final session in filtered) {
      final date = DateTime.tryParse(session['date']?.toString() ?? '');
      if (date == null) continue;

      for (final ex in (session['exercises'] as List? ?? [])) {
        final name = ex['name']?.toString() ?? '';
        if (!_isLift(name, lift)) continue;

        for (final set in (ex['sets'] as List? ?? [])) {
          final w = (set['weight'] as num?)?.toDouble() ?? 0;
          final r = (set['reps'] as num?)?.toInt() ?? 0;
          final c = (set['sets'] as num?)?.toInt() ?? 1;
          
          if (w > currentMax) currentMax = w;
          final e1rm = estimateE1RM(w, r);
          
          if (date.isAfter(d7)) {
            if (e1rm > est1RM) est1RM = e1rm;
            volume7d += (w * r * c);
            totalSets += c;
          } else if (date.isAfter(d14)) {
            if (e1rm > prevEst1RM) prevEst1RM = e1rm;
            prevVolume7d += (w * r * c);
            prevTotalSets += c;
          } else {
            if (e1rm > prevEst1RM) prevEst1RM = e1rm;
          }
        }
      }
    }
    
    if (est1RM == 0 && prevEst1RM > 0) est1RM = prevEst1RM;

    final result = LiftMetrics(
      currentMax: currentMax,
      est1RM: est1RM,
      volume7d: volume7d,
      totalSets: totalSets,
      prevVolume7d: prevVolume7d,
      prevTotalSets: prevTotalSets,
      prevEst1RM: prevEst1RM,
    );

    _metricsCache[key] = result;
    return result;
  }

  /// Weekly progress (cached).
  List<LiftProgress> getWeeklyProgress(TimeRange range) {
    final key = range.name;
    if (_progressCache.containsKey(key)) return _progressCache[key]!;

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

      final current = points.last.value;
      final previous = points[points.length - 2].value;
      final change = current - previous;
      final pct = previous > 0 ? (change / previous) * 100 : 0.0;

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

    _progressCache[key] = progress;
    return progress;
  }

  /// Insights (cached).
  List<Insight> getInsights(TimeRange range, {String? lift}) {
    final key = '${lift ?? 'all'}-${range.name}';
    if (_insightsCache.containsKey(key)) return _insightsCache[key]!;

    final insights = <Insight>[];
    final targetLifts = lift != null ? [lift] : ['Squat', 'Bench', 'Deadlift'];
    final progress = getWeeklyProgress(range).where((p) => targetLifts.contains(p.lift)).toList();
    final volumeTrend = getVolumeTrend(range, lift: lift);

    for (final l in targetLifts) {
      if (insights.length >= 3) break;
      final points = getStrengthTrend(l, range);
      if (points.length >= 2) {
        final allValues = points.map((p) => p.value).toList();
        final maxVal = allValues.reduce(math.max);
        if (points.last.value == maxVal && points.last.value > points[points.length - 2].value) {
          insights.add(Insight(
            text: '$l strength is improving!',
            type: InsightType.positive,
            subtext: 'Your estimated 1RM increased recently.',
          ));
        }
      }
    }

    for (final p in progress) {
      if (insights.length >= 3) break;
      if (p.trend == TrendDirection.plateau) {
        insights.add(Insight(
          text: '${p.lift} has plateaued',
          type: InsightType.warning,
          subtext: 'Consider adjusting your programming to break the plateau.',
        ));
      }
    }

    if (volumeTrend.length >= 2 && insights.length < 3) {
      final lastVol = volumeTrend.last.volume;
      final prevVol = volumeTrend[volumeTrend.length - 2].volume;
      if (prevVol > 0) {
        final pct = ((lastVol - prevVol) / prevVol) * 100;
        if (pct > 15) {
          insights.add(Insight(
            text: 'Great volume this month!',
            type: InsightType.positive,
            subtext: 'You\'re training ${pct.toStringAsFixed(0)}% more volume.',
          ));
        } else if (pct < -15) {
          insights.add(Insight(
            text: 'Recovery might be an issue.',
            type: InsightType.warning,
            subtext: 'Your volume dropped ${pct.abs().toStringAsFixed(0)}%. Consider taking an extra rest day.',
          ));
        }
      }
    }

    if (insights.isEmpty) {
      insights.add(Insight(
        text: 'Keep logging sessions.',
        type: InsightType.neutral,
        subtext: 'Log more to unlock deeper insights.',
      ));
    }

    final result = insights.take(3).toList();
    _insightsCache[key] = result;
    return result;
  }
}
