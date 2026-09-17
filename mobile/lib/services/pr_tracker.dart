import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks personal records (PRs) locally and detects when a new PR is hit.
///
/// PR Types:
///   - Weight PR: Heaviest weight lifted for any rep count
///   - Rep PR: Most reps at a given weight
///   - Volume PR: Most volume (weight × reps × sets) in a single session for a lift
///   - Estimated 1RM PR: Highest estimated 1RM (Epley formula)
class PRTracker {
  static const String _prKey = 'pr_history_v1';

  /// Check a completed session for new PRs.
  /// Returns a list of PR achievements (empty if no new PRs).
  static Future<List<PRAchievement>> checkForPRs(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prKey);
    final prHistory = stored != null ? Map<String, dynamic>.from(jsonDecode(stored)) : <String, dynamic>{};
    
    final achievements = <PRAchievement>[];
    final exercises = session['exercises'] as List? ?? [];
    final sessionDate = session['date']?.toString() ?? DateTime.now().toIso8601String();

    for (final ex in exercises) {
      final name = (ex['name']?.toString() ?? '').trim();
      if (name.isEmpty) continue;
      final nameKey = name.toLowerCase();
      final sets = ex['sets'] as List? ?? [];

      // Initialize PR record for this exercise
      prHistory.putIfAbsent(nameKey, () => {
        'name': name,
        'maxWeight': 0.0,
        'maxWeight_date': '',
        'maxEst1RM': 0.0,
        'maxEst1RM_date': '',
        'bestVolume': 0.0,
        'bestVolume_date': '',
      });
      final record = Map<String, dynamic>.from(prHistory[nameKey]);

      double sessionVolume = 0;

      for (final set in sets) {
        final weight = (set['weight'] as num?)?.toDouble() ?? 0;
        final reps = (set['reps'] as num?)?.toInt() ?? 0;
        final setCount = (set['sets'] as num?)?.toInt() ?? 1;

        if (weight <= 0 || reps <= 0) continue;

        // Weight PR
        final prevMax = (record['maxWeight'] as num?)?.toDouble() ?? 0;
        if (weight > prevMax) {
          record['maxWeight'] = weight;
          record['maxWeight_date'] = sessionDate;
          achievements.add(PRAchievement(
            exerciseName: name,
            type: PRType.weight,
            value: weight,
            previousValue: prevMax,
            date: sessionDate,
          ));
        }

        // Estimated 1RM PR (Epley: weight × (1 + reps/30))
        if (reps <= 10) { // Only meaningful for low-rep sets
          final est1rm = weight * (1 + reps / 30.0);
          final prevEst = (record['maxEst1RM'] as num?)?.toDouble() ?? 0;
          if (est1rm > prevEst) {
            record['maxEst1RM'] = est1rm;
            record['maxEst1RM_date'] = sessionDate;
            if (prevEst > 0) {
              achievements.add(PRAchievement(
                exerciseName: name,
                type: PRType.estimated1RM,
                value: est1rm,
                previousValue: prevEst,
                date: sessionDate,
              ));
            }
          }
        }

        sessionVolume += weight * reps * setCount;
      }

      // Volume PR (per exercise per session)
      if (sessionVolume > 0) {
        final prevVol = (record['bestVolume'] as num?)?.toDouble() ?? 0;
        if (sessionVolume > prevVol && prevVol > 0) {
          record['bestVolume'] = sessionVolume;
          record['bestVolume_date'] = sessionDate;
          achievements.add(PRAchievement(
            exerciseName: name,
            type: PRType.volume,
            value: sessionVolume,
            previousValue: prevVol,
            date: sessionDate,
          ));
        } else if (prevVol == 0) {
          record['bestVolume'] = sessionVolume;
          record['bestVolume_date'] = sessionDate;
        }
      }

      prHistory[nameKey] = record;
    }

    // Save updated PR history
    await prefs.setString(_prKey, jsonEncode(prHistory));

    // Deduplicate: only keep the most significant PR per exercise
    final deduped = <String, PRAchievement>{};
    for (final a in achievements) {
      final key = '${a.exerciseName}_${a.type.name}';
      if (!deduped.containsKey(key) || a.value > deduped[key]!.value) {
        deduped[key] = a;
      }
    }

    // Sort: weight PRs first (most exciting), then est1RM, then volume
    final result = deduped.values.toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
    
    return result;
  }

  /// Get all stored PR records.
  static Future<Map<String, dynamic>> getAllPRs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prKey);
    if (stored == null) return {};
    return Map<String, dynamic>.from(jsonDecode(stored));
  }

  /// Get PR for a specific exercise.
  static Future<Map<String, dynamic>?> getExercisePR(String exerciseName) async {
    final all = await getAllPRs();
    return all[exerciseName.toLowerCase()] as Map<String, dynamic>?;
  }
}

enum PRType { weight, estimated1RM, volume }

class PRAchievement {
  final String exerciseName;
  final PRType type;
  final double value;
  final double previousValue;
  final String date;

  PRAchievement({
    required this.exerciseName,
    required this.type,
    required this.value,
    required this.previousValue,
    required this.date,
  });

  double get improvement => value - previousValue;
  double get improvementPercent => previousValue > 0 ? (improvement / previousValue) * 100 : 0;

  String get typeLabel {
    switch (type) {
      case PRType.weight: return 'Weight PR';
      case PRType.estimated1RM: return 'Est. 1RM PR';
      case PRType.volume: return 'Volume PR';
    }
  }

  String get formattedValue {
    switch (type) {
      case PRType.weight: return '${value.toStringAsFixed(1).replaceAll('.0', '')} kg';
      case PRType.estimated1RM: return '${value.toStringAsFixed(1)} kg';
      case PRType.volume: return '${value.toStringAsFixed(0)} kg';
    }
  }
}
