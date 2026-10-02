import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

// ─── Configuration Model ───

class PdfExportConfig {
  final int? block;
  final int? week; // null = entire block
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ExerciseFilter exerciseFilter;
  final ReportDetail detailLevel;
  final Set<String> includedMetrics;

  PdfExportConfig({
    this.block,
    this.week,
    this.dateFrom,
    this.dateTo,
    this.exerciseFilter = ExerciseFilter.sbdPlusAccessories,
    this.detailLevel = ReportDetail.complete,
    this.includedMetrics = const {},
  });

  bool get isEntireBlock => week == null && block != null && dateFrom == null;
  bool get isCustomRange => dateFrom != null && dateTo != null;
}

enum ExerciseFilter { sbdOnly, sbdPlusAccessories, all }

enum ReportDetail { summary, complete }

// ─── Data Models ───

class _LiftSummary {
  double topWeight = 0;
  int topWeightReps = 0;
  double bestRepSetWeight = 0;
  int bestRepSetReps = 0;
  int totalSets = 0;
  int totalReps = 0;
  double totalVolume = 0;
  double bestE1RM = 0;
  List<double> rpeValues = [];
  List<double> rirValues = [];

  double get averageRPE =>
      rpeValues.isEmpty ? 0 : rpeValues.reduce((a, b) => a + b) / rpeValues.length;
  double get averageRIR =>
      rirValues.isEmpty ? 0 : rirValues.reduce((a, b) => a + b) / rirValues.length;
}

class _RecoverySummary {
  List<double> bodyweights = [];
  List<int> steps = [];
  List<double> sleepHours = [];
  List<double> energy = [];
  List<double> hunger = [];
  List<double> fatigue = [];

  double get avgBodyweight =>
      bodyweights.isEmpty ? 0 : bodyweights.reduce((a, b) => a + b) / bodyweights.length;
  double get bodyweightChange =>
      bodyweights.length < 2 ? 0 : bodyweights.last - bodyweights.first;
}

// ─── PDF Export Service ───

class PdfExportService {
  // Consistent Epley formula
  static double estimateE1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  // SBD exercise name matching
  static String? _getSBDCategory(String name) {
    final n = name.toLowerCase();
    if (n == 'squat' || n == 'barbell squat' || n == 'competition squat') return 'Squat';
    if (n == 'bench' || n == 'bench press' || n == 'barbell bench press' || n == 'competition bench') return 'Bench';
    if (n == 'deadlift' || n == 'competition deadlift') return 'Deadlift';
    return null;
  }

  static bool _isSBDVariation(String name) {
    final n = name.toLowerCase();
    // Squat variations
    if (n.contains('squat') && !n.contains('split')) return true;
    // Bench variations
    if (n.contains('bench') || n.contains('larsen') || n.contains('spoto')) return true;
    // Deadlift variations
    if (n.contains('dead') || n == 'rdl' || n.contains('block pull')) return true;
    return false;
  }

  static bool _isMainSBD(String name) => _getSBDCategory(name) != null;

  // ─── Filter sessions based on config ───

  static List<Map<String, dynamic>> _filterSessions(
      List<dynamic> allSessions, PdfExportConfig config) {
    return allSessions.where((s) {
      final session = s as Map<String, dynamic>;

      if (config.isCustomRange) {
        final date = DateTime.tryParse(session['date']?.toString() ?? '');
        if (date == null) return false;
        return !date.isBefore(config.dateFrom!) &&
            !date.isAfter(config.dateTo!.add(const Duration(days: 1)));
      }

      if (config.block != null) {
        final sBlock = _parseNum(session['block']);
        if (sBlock != config.block) return false;
      }

      if (config.week != null) {
        final sWeek = _parseNum(session['week']);
        if (sWeek != config.week) return false;
      }

      return true;
    }).map((s) => Map<String, dynamic>.from(s as Map)).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return da.compareTo(db);
      });
  }

  static int? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  // ─── Build SBD Summary ───

  static Map<String, _LiftSummary> _buildSBDSummary(
      List<Map<String, dynamic>> sessions) {
    final summaries = <String, _LiftSummary>{
      'Squat': _LiftSummary(),
      'Bench': _LiftSummary(),
      'Deadlift': _LiftSummary(),
    };

    for (final session in sessions) {
      final exercises = session['exercises'] as List? ?? [];
      for (final ex in exercises) {
        final name = ex['name']?.toString() ?? '';
        final category = _getSBDCategory(name);
        if (category == null) continue;
        final summary = summaries[category]!;
        final sets = ex['sets'] as List? ?? [];

        for (final set in sets) {
          final w = (set['weight'] as num?)?.toDouble() ?? 0;
          final r = (set['reps'] as num?)?.toInt() ?? 0;
          final c = (set['sets'] as num?)?.toInt() ?? 1;
          final rpe = (set['rpe'] as num?)?.toDouble();
          final rir = (set['rir'] as num?)?.toDouble();

          if (w <= 0) continue;

          // Use the 'sets' multiplier from Session model
          summary.totalSets += c;
          summary.totalReps += r * c;
          summary.totalVolume += w * r * c;

          if (w > summary.topWeight) {
            summary.topWeight = w;
            summary.topWeightReps = r;
          }

          // Best rep set: highest weight × reps product for display
          if (w >= summary.bestRepSetWeight) {
            if (w > summary.bestRepSetWeight || r > summary.bestRepSetReps) {
              summary.bestRepSetWeight = w;
              summary.bestRepSetReps = r;
            }
          }

          final e1rm = estimateE1RM(w, r);
          if (e1rm > summary.bestE1RM) summary.bestE1RM = e1rm;

          if (rpe != null && rpe > 0) summary.rpeValues.add(rpe);
          if (rir != null) summary.rirValues.add(rir);
        }
      }
    }

    return summaries;
  }

  // ─── Build Recovery Summary ───

  static _RecoverySummary _buildRecoverySummary(
      List<Map<String, dynamic>> sessions,
      Map<String, dynamic>? profile,
      List<dynamic>? weightHistory) {
    final recovery = _RecoverySummary();

    // Extract bodyweight from weight history if available
    if (weightHistory != null) {
      for (final entry in weightHistory) {
        final w = (entry['weight'] as num?)?.toDouble();
        if (w != null && w > 0) recovery.bodyweights.add(w);
      }
    }

    // Session-level recovery data (from Session model fields if they exist)
    for (final session in sessions) {

      final rating = (session['sessionRating'] as num?)?.toDouble();
      if (rating != null && rating > 0) recovery.energy.add(rating);
    }

    return recovery;
  }

  // ─── Compute Progress Comparison ───

  static Map<String, Map<String, double>>? _computeProgressComparison(
      List<dynamic> allSessions, PdfExportConfig config) {
    if (config.week == null || config.block == null) return null;
    final prevWeek = config.week! - 1;
    if (prevWeek < 1) return null;

    final prevConfig = PdfExportConfig(
      block: config.block,
      week: prevWeek,
    );

    final prevSessions = _filterSessions(allSessions, prevConfig);
    if (prevSessions.isEmpty) return null;

    final currentSummary =
        _buildSBDSummary(_filterSessions(allSessions, config));
    final prevSummary = _buildSBDSummary(prevSessions);

    final comparison = <String, Map<String, double>>{};

    for (final lift in ['Squat', 'Bench', 'Deadlift']) {
      final curr = currentSummary[lift]!;
      final prev = prevSummary[lift]!;
      if (curr.totalSets == 0 && prev.totalSets == 0) continue;

      comparison[lift] = {
        'topSetChange': curr.topWeight - prev.topWeight,
        'volumeChange': curr.totalVolume - prev.totalVolume,
        'volumeChangePct': prev.totalVolume > 0
            ? ((curr.totalVolume - prev.totalVolume) / prev.totalVolume) * 100
            : 0,
        'setsChange': (curr.totalSets - prev.totalSets).toDouble(),
        'repsChange': (curr.totalReps - prev.totalReps).toDouble(),
        'e1rmChange': curr.bestE1RM - prev.bestE1RM,
        'rpeChange': curr.averageRPE - prev.averageRPE,
        'currE1RM': curr.bestE1RM,
        'prevE1RM': prev.bestE1RM,
      };
    }

    return comparison.isEmpty ? null : comparison;
  }

  // ─── Find PRs in period ───

  static Map<String, List<Map<String, dynamic>>> _findPRsInPeriod(
      List<Map<String, dynamic>> periodSessions,
      List<dynamic> allSessions) {
    // Build historical best e1RM per lift before the period
    final periodDates = periodSessions
        .map((s) => DateTime.tryParse(s['date']?.toString() ?? ''))
        .where((d) => d != null)
        .toList();
    if (periodDates.isEmpty) return {};

    final periodStart = periodDates.reduce((a, b) => a!.isBefore(b!) ? a : b)!;

    final historicalBest = <String, double>{};
    for (final s in allSessions) {
      final date = DateTime.tryParse(s['date']?.toString() ?? '');
      if (date == null || !date.isBefore(periodStart)) continue;
      for (final ex in (s['exercises'] as List? ?? [])) {
        final name = ex['name']?.toString() ?? '';
        final cat = _getSBDCategory(name);
        if (cat == null) continue;
        for (final set in (ex['sets'] as List? ?? [])) {
          final w = (set['weight'] as num?)?.toDouble() ?? 0;
          final r = (set['reps'] as num?)?.toInt() ?? 0;
          final e1rm = estimateE1RM(w, r);
          if (e1rm > (historicalBest[cat] ?? 0)) historicalBest[cat] = e1rm;
        }
      }
    }

    final prs = <String, List<Map<String, dynamic>>>{};

    for (final session in periodSessions) {
      final date = DateTime.tryParse(session['date']?.toString() ?? '');
      for (final ex in (session['exercises'] as List? ?? [])) {
        final name = ex['name']?.toString() ?? '';
        final cat = _getSBDCategory(name);
        if (cat == null) continue;
        for (final set in (ex['sets'] as List? ?? [])) {
          final w = (set['weight'] as num?)?.toDouble() ?? 0;
          final r = (set['reps'] as num?)?.toInt() ?? 0;
          if (w <= 0) continue;

          final e1rm = estimateE1RM(w, r);
          final prevBest = historicalBest[cat] ?? 0;

          if (w > prevBest || e1rm > prevBest) {
            prs.putIfAbsent(cat, () => []);
            prs[cat]!.add({
              'weight': w,
              'reps': r,
              'e1rm': e1rm,
              'date': date,
              'type': w > prevBest ? 'Weight PR' : 'Estimated 1RM PR',
            });
            // Update so we don't double-count
            if (e1rm > (historicalBest[cat] ?? 0)) historicalBest[cat] = e1rm;
          }
        }
      }
    }

    return prs;
  }

  // ─── PDF COLORS ───

  static const _pdfDark = PdfColor.fromInt(0xFF0B0B0F);
  static const _pdfCard = PdfColor.fromInt(0xFF15151B);
  static const _pdfBorder = PdfColor.fromInt(0xFF2A2A35);
  static const _pdfWhite = PdfColor.fromInt(0xFFF8FAFC);
  static const _pdfMuted = PdfColor.fromInt(0xFFA1A1AA);
  static const _pdfDim = PdfColor.fromInt(0xFF71717A);
  static const _pdfBlue = PdfColor.fromInt(0xFF3B82F6);
  static const _pdfRed = PdfColor.fromInt(0xFFEF4444);
  static const _pdfAmber = PdfColor.fromInt(0xFFF59E0B);
  static const _pdfGreen = PdfColor.fromInt(0xFF22C55E);

  // ─── MAIN GENERATE METHOD ───

  static Future<File> generateReport({
    required List<dynamic> allSessions,
    required PdfExportConfig config,
    required String username,
    Map<String, dynamic>? profile,
    Map<String, dynamic>? prs,
  }) async {
    final sessions = _filterSessions(allSessions, config);
    if (sessions.isEmpty) {
      throw Exception('No training sessions found for the selected period.');
    }

    final sbdSummary = _buildSBDSummary(sessions);
    final recovery = _buildRecoverySummary(
        sessions, profile, (profile?['weightHistory'] as List?));
    final progressComparison =
        _computeProgressComparison(allSessions, config);
    final periodPRs = _findPRsInPeriod(sessions, allSessions);

    // Calculate totals
    double totalVolume = 0;
    int totalWorkingSets = 0;
    for (final s in sessions) {
      for (final ex in (s['exercises'] as List? ?? [])) {
        for (final set in (ex['sets'] as List? ?? [])) {
          final w = (set['weight'] as num?)?.toDouble() ?? 0;
          final r = (set['reps'] as num?)?.toInt() ?? 0;
          final c = (set['sets'] as num?)?.toInt() ?? 1;
          totalVolume += w * r * c;
          totalWorkingSets += c;
        }
      }
    }

    // Date range
    final dates = sessions
        .map((s) => DateTime.tryParse(s['date']?.toString() ?? ''))
        .where((d) => d != null)
        .cast<DateTime>()
        .toList()
      ..sort();
    final dateFrom = dates.first;
    final dateTo = dates.last;
    final dateRangeStr =
        '${DateFormat('MMMM d').format(dateFrom)} – ${DateFormat('MMMM d, yyyy').format(dateTo)}';

    // Block/week labels
    final blockLabel = config.block != null ? 'Block ${config.block}' : '';
    final weekLabel = config.week != null ? 'Week ${config.week}' : '';
    final periodLabel = config.isEntireBlock
        ? '$blockLabel — Complete'
        : config.isCustomRange
            ? 'Custom Range'
            : '$blockLabel${weekLabel.isNotEmpty ? " — $weekLabel" : ""}';

    final pdf = pw.Document(
      title: 'SBD Training Report',
      author: username,
      creator: 'SBD Tracker',
    );

    // ─── Common Styles ───
    final titleStyle = pw.TextStyle(
      fontSize: 28,
      fontWeight: pw.FontWeight.bold,
      color: _pdfBlue,
    );
    final h1 = pw.TextStyle(
        fontSize: 18, fontWeight: pw.FontWeight.bold, color: _pdfWhite);
    final h2 = pw.TextStyle(
        fontSize: 14, fontWeight: pw.FontWeight.bold, color: _pdfWhite);
    final h3 = pw.TextStyle(
        fontSize: 12, fontWeight: pw.FontWeight.bold, color: _pdfMuted);
    final bodyStyle =
        pw.TextStyle(fontSize: 10, color: _pdfWhite);
    final mutedStyle =
        pw.TextStyle(fontSize: 9, color: _pdfMuted);
    final monoStyle = pw.TextStyle(
        fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdfWhite);

    final headerDecoration = pw.BoxDecoration(
      color: _pdfCard,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    );

    // Helper for formatted numbers
    String fmtNum(double v) {
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toStringAsFixed(1);
    }

    String fmtVolume(double v) {
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
      return fmtNum(v);
    }

    // ─── PAGE 1: COVER ───
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(),
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 60),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _pdfBlue, width: 3),
                ),
              ),
              child: pw.Text('SBD TRAINING REPORT', style: titleStyle),
            ),
            pw.SizedBox(height: 30),
            pw.Text(periodLabel, style: h1),
            pw.SizedBox(height: 8),
            pw.Text(dateRangeStr, style: pw.TextStyle(fontSize: 12, color: _pdfMuted)),
            pw.SizedBox(height: 40),
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: headerDecoration,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Athlete', style: h3),
                      pw.Text(username, style: monoStyle),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: _pdfBorder, thickness: 0.5),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Training Sessions', style: h3),
                      pw.Text('${sessions.length}', style: monoStyle),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: _pdfBorder, thickness: 0.5),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Working Sets', style: h3),
                      pw.Text('$totalWorkingSets', style: monoStyle),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: _pdfBorder, thickness: 0.5),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Volume', style: h3),
                      pw.Text('${NumberFormat('#,###').format(totalVolume)} kg',
                          style: monoStyle),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: _pdfBorder, thickness: 0.5),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Report Generated', style: h3),
                      pw.Text(DateFormat('MMMM d, yyyy').format(DateTime.now()),
                          style: mutedStyle),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            // SBD Summary mini row
            pw.Row(
              children: [
                _buildCoverLiftBox('SQUAT', sbdSummary['Squat']!, _pdfRed),
                pw.SizedBox(width: 10),
                _buildCoverLiftBox('BENCH', sbdSummary['Bench']!, _pdfBlue),
                pw.SizedBox(width: 10),
                _buildCoverLiftBox('DEADLIFT', sbdSummary['Deadlift']!, _pdfAmber),
              ],
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                'Generated by SBD Tracker',
                style: pw.TextStyle(fontSize: 8, color: _pdfDim),
              ),
            ),
          ],
        ),
      ),
    );

    // ─── PAGE 2: WEEKLY OVERVIEW TABLE ───
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('SBD Overview', periodLabel),
            pw.SizedBox(height: 16),
            _buildSBDOverviewTable(sbdSummary, fmtNum),
            pw.SizedBox(height: 24),
            // Progress comparison
            if (progressComparison != null) ...[
              pw.Text('PROGRESS COMPARISON (vs Previous Week)',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _pdfMuted,
                      letterSpacing: 1)),
              pw.SizedBox(height: 10),
              ...progressComparison.entries.map(
                (e) => _buildProgressRow(e.key, e.value, fmtNum),
              ),
            ],
            // PRs
            if (periodPRs.isNotEmpty) ...[
              pw.SizedBox(height: 24),
              pw.Text('PERSONAL RECORDS',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _pdfMuted,
                      letterSpacing: 1)),
              pw.SizedBox(height: 10),
              ...periodPRs.entries.map((e) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: headerDecoration,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('${e.key} PRs',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: _pdfWhite)),
                        pw.SizedBox(height: 4),
                        ...e.value.take(3).map((pr) => pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 2),
                              child: pw.Text(
                                '${pr['type']}: ${fmtNum(pr['weight'])} kg × ${pr['reps']} (e1RM: ${fmtNum(pr['e1rm'])} kg)',
                                style: mutedStyle,
                              ),
                            )),
                      ],
                    ),
                  )),
            ],
            // Recovery
            if (config.includedMetrics.contains('bodyweight') ||
                config.includedMetrics.contains('sessionRating')) ...[
              pw.SizedBox(height: 24),
              _buildRecoverySection(recovery, sessions),
            ],
            pw.Spacer(),
            _buildFooter(1),
          ],
        ),
      ),
    );

    // ─── SESSION DETAIL PAGES ───
    if (config.detailLevel == ReportDetail.complete) {
      int pageNum = 2;
      for (final session in sessions) {
        final sessionWidgets = _buildSessionDetailWidgets(
            session, config, fmtNum, h2, h3, bodyStyle, mutedStyle, monoStyle,
            headerDecoration, periodLabel);

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            header: (context) =>
                _buildPageHeader('Session Detail', periodLabel),
            footer: (context) => _buildFooter(pageNum++),
            build: (context) => sessionWidgets,
          ),
        );
      }
    }

    // ─── BLOCK OVERVIEW PAGE (entire block) ───
    if (config.isEntireBlock) {
      final weekNumbers = sessions
          .map((s) => _parseNum(s['week']))
          .where((w) => w != null)
          .cast<int>()
          .toSet()
          .toList()
        ..sort();

      if (weekNumbers.length > 1) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (context) {
              final rows = <pw.TableRow>[];
              // Header row
              rows.add(pw.TableRow(
                children: [
                  _tableCell('Week', isHeader: true),
                  _tableCell('Squat Vol', isHeader: true),
                  _tableCell('Bench Vol', isHeader: true),
                  _tableCell('Deadlift Vol', isHeader: true),
                  _tableCell('Total Vol', isHeader: true),
                  _tableCell('Sessions', isHeader: true),
                ],
              ));

              for (final wk in weekNumbers) {
                final wkSessions = sessions
                    .where((s) => _parseNum(s['week']) == wk)
                    .toList();
                final wkSummary = _buildSBDSummary(wkSessions);
                final wkTotal = wkSummary.values
                    .fold<double>(0, (sum, s) => sum + s.totalVolume);

                rows.add(pw.TableRow(
                  children: [
                    _tableCell('Week $wk'),
                    _tableCell('${fmtVolume(wkSummary['Squat']!.totalVolume)} kg'),
                    _tableCell('${fmtVolume(wkSummary['Bench']!.totalVolume)} kg'),
                    _tableCell(
                        '${fmtVolume(wkSummary['Deadlift']!.totalVolume)} kg'),
                    _tableCell('${fmtVolume(wkTotal)} kg'),
                    _tableCell('${wkSessions.length}'),
                  ],
                ));
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPageHeader('Block Overview', periodLabel),
                  pw.SizedBox(height: 16),
                  pw.Text('WEEKLY PROGRESSION',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _pdfMuted,
                          letterSpacing: 1)),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: _pdfBorder, width: 0.5),
                    children: rows,
                  ),
                  pw.SizedBox(height: 20),
                  // E1RM progression
                  pw.Text('ESTIMATED 1RM PROGRESSION',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _pdfMuted,
                          letterSpacing: 1)),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: _pdfBorder, width: 0.5),
                    children: [
                      pw.TableRow(children: [
                        _tableCell('Week', isHeader: true),
                        _tableCell('Squat e1RM', isHeader: true),
                        _tableCell('Bench e1RM', isHeader: true),
                        _tableCell('Deadlift e1RM', isHeader: true),
                      ]),
                      ...weekNumbers.map((wk) {
                        final wkSessions = sessions
                            .where((s) => _parseNum(s['week']) == wk)
                            .toList();
                        final wkSummary = _buildSBDSummary(wkSessions);
                        return pw.TableRow(children: [
                          _tableCell('Week $wk'),
                          _tableCell(wkSummary['Squat']!.bestE1RM > 0
                              ? '${fmtNum(wkSummary['Squat']!.bestE1RM)} kg'
                              : '—'),
                          _tableCell(wkSummary['Bench']!.bestE1RM > 0
                              ? '${fmtNum(wkSummary['Bench']!.bestE1RM)} kg'
                              : '—'),
                          _tableCell(wkSummary['Deadlift']!.bestE1RM > 0
                              ? '${fmtNum(wkSummary['Deadlift']!.bestE1RM)} kg'
                              : '—'),
                        ]);
                      }),
                    ],
                  ),
                  pw.Spacer(),
                  _buildFooter(0),
                ],
              );
            },
          ),
        );
      }
    }

    // ─── METHODOLOGY FOOTER PAGE ───
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('Methodology', periodLabel),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: headerDecoration,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Calculation Methods',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: _pdfWhite)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                      'Estimated 1RM: Epley Formula — e1RM = weight × (1 + reps ÷ 30)',
                      style: mutedStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Volume: weight × reps × sets (per set entry)',
                      style: mutedStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'e1RM is calculated from working sets only (highest e1RM per session).',
                      style: mutedStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'RPE/RIR values are only shown when recorded by the athlete.',
                      style: mutedStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'All weights displayed in kg unless otherwise noted.',
                      style: mutedStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      '"—" indicates data was not recorded for that field.',
                      style: mutedStyle),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                'End of Report',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfDim),
              ),
            ),
          ],
        ),
      ),
    );

    // ─── SAVE & RETURN ───
    final dir = await getTemporaryDirectory();
    final fileName = _generateFileName(config);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ─── Share/Download ───

  static Future<void> shareReport(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'SBD Training Report',
    );
  }

  // ─── Helper Widgets ───

  static pw.Widget _buildCoverLiftBox(
      String label, _LiftSummary summary, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _pdfCard,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border(top: pw.BorderSide(color: color, width: 2)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                    letterSpacing: 1)),
            pw.SizedBox(height: 6),
            pw.Text(
              summary.topWeight > 0 ? '${summary.topWeight.toStringAsFixed(summary.topWeight == summary.topWeight.roundToDouble() ? 0 : 1)} kg' : '—',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: _pdfWhite),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              summary.bestE1RM > 0
                  ? 'e1RM: ${summary.bestE1RM.toStringAsFixed(1)} kg'
                  : '',
              style: pw.TextStyle(fontSize: 8, color: _pdfMuted),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPageHeader(String title, String subtitle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold, color: _pdfWhite)),
        pw.Text(subtitle,
            style: pw.TextStyle(fontSize: 9, color: _pdfMuted)),
      ],
    );
  }

  static pw.Widget _buildFooter(int pageNum) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('SBD Tracker',
            style: pw.TextStyle(fontSize: 7, color: _pdfDim)),
        pw.Text(
            'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 7, color: _pdfDim)),
      ],
    );
  }

  static pw.Widget _buildSBDOverviewTable(
      Map<String, _LiftSummary> summaries, String Function(double) fmtNum) {
    final headers = ['Metric', 'Squat', 'Bench', 'Deadlift'];
    final metrics = [
      'Top Weight',
      'Best Rep Set',
      'Total Sets',
      'Total Reps',
      'Total Volume',
      'Estimated 1RM',
      'Average RPE',
    ];

    String getValue(String lift, String metric) {
      final s = summaries[lift]!;
      switch (metric) {
        case 'Top Weight':
          return s.topWeight > 0 ? '${fmtNum(s.topWeight)} kg' : '—';
        case 'Best Rep Set':
          return s.bestRepSetWeight > 0
              ? '${fmtNum(s.bestRepSetWeight)} × ${s.bestRepSetReps}'
              : '—';
        case 'Total Sets':
          return s.totalSets > 0 ? '${s.totalSets}' : '—';
        case 'Total Reps':
          return s.totalReps > 0 ? '${s.totalReps}' : '—';
        case 'Total Volume':
          return s.totalVolume > 0
              ? '${NumberFormat('#,###').format(s.totalVolume)} kg'
              : '—';
        case 'Estimated 1RM':
          return s.bestE1RM > 0 ? '${fmtNum(s.bestE1RM)} kg' : '—';
        case 'Average RPE':
          return s.rpeValues.isNotEmpty ? fmtNum(s.averageRPE) : '—';
        default:
          return '—';
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _pdfBorder, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _pdfCard),
          children: headers.map((h) => _tableCell(h, isHeader: true)).toList(),
        ),
        ...metrics.map((metric) => pw.TableRow(
              children: [
                _tableCell(metric, isRowHeader: true),
                _tableCell(getValue('Squat', metric)),
                _tableCell(getValue('Bench', metric)),
                _tableCell(getValue('Deadlift', metric)),
              ],
            )),
      ],
    );
  }

  static pw.Widget _tableCell(String text,
      {bool isHeader = false, bool isRowHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 9,
          fontWeight:
              (isHeader || isRowHeader) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader
              ? _pdfMuted
              : isRowHeader
                  ? _pdfWhite
                  : _pdfWhite,
        ),
        textAlign: isHeader || isRowHeader ? pw.TextAlign.left : pw.TextAlign.right,
      ),
    );
  }

  static pw.Widget _buildProgressRow(
      String lift, Map<String, double> changes, String Function(double) fmtNum) {
    PdfColor arrowColor(double v) => v > 0 ? _pdfGreen : (v < 0 ? _pdfRed : _pdfMuted);
    String arrow(double v) => v > 0 ? '▲' : (v < 0 ? '▼' : '—');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _pdfCard,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(lift,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold, color: _pdfWhite)),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              _progressItem('Top Set', changes['topSetChange']!, 'kg',
                  arrowColor, arrow, fmtNum),
              pw.SizedBox(width: 16),
              _progressItem('Volume', changes['volumeChangePct']!, '%',
                  arrowColor, arrow, fmtNum),
              pw.SizedBox(width: 16),
              _progressItem('e1RM', changes['e1rmChange']!, 'kg',
                  arrowColor, arrow, fmtNum),
              pw.SizedBox(width: 16),
              _progressItem('Avg RPE', changes['rpeChange']!, '',
                  arrowColor, arrow, fmtNum),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _progressItem(
      String label,
      double value,
      String unit,
      PdfColor Function(double) arrowColor,
      String Function(double) arrow,
      String Function(double) fmtNum) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 7, color: _pdfDim)),
          pw.SizedBox(height: 2),
          pw.Text(
            '${arrow(value)} ${fmtNum(value.abs())}$unit',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: arrowColor(value)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRecoverySection(
      _RecoverySummary recovery, List<Map<String, dynamic>> sessions) {
    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: _pdfCard),
      children: [
        _tableCell('Recovery Metric', isHeader: true),
        _tableCell('Average', isHeader: true),
      ],
    ));

    if (recovery.bodyweights.isNotEmpty) {
      rows.add(pw.TableRow(children: [
        _tableCell('Bodyweight', isRowHeader: true),
        _tableCell('${recovery.avgBodyweight.toStringAsFixed(1)} kg'),
      ]));
      if (recovery.bodyweightChange != 0) {
        rows.add(pw.TableRow(children: [
          _tableCell('Bodyweight Change', isRowHeader: true),
          _tableCell(
              '${recovery.bodyweightChange > 0 ? '+' : ''}${recovery.bodyweightChange.toStringAsFixed(1)} kg'),
        ]));
      }
    }

    if (recovery.energy.isNotEmpty) {
      final avg =
          recovery.energy.reduce((a, b) => a + b) / recovery.energy.length;
      rows.add(pw.TableRow(children: [
        _tableCell('Session Rating (avg)', isRowHeader: true),
        _tableCell('${avg.toStringAsFixed(1)}/10'),
      ]));
    }

    if (rows.length <= 1) {
      return pw.Text('No recovery data recorded.',
          style: pw.TextStyle(fontSize: 9, color: _pdfDim));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('RECOVERY & BODY METRICS',
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _pdfMuted,
                letterSpacing: 1)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: _pdfBorder, width: 0.5),
          children: rows,
        ),
      ],
    );
  }

  // ─── Session Detail Widgets ───

  static List<pw.Widget> _buildSessionDetailWidgets(
      Map<String, dynamic> session,
      PdfExportConfig config,
      String Function(double) fmtNum,
      pw.TextStyle h2,
      pw.TextStyle h3,
      pw.TextStyle bodyStyle,
      pw.TextStyle mutedStyle,
      pw.TextStyle monoStyle,
      pw.BoxDecoration headerDecoration,
      String periodLabel) {
    final widgets = <pw.Widget>[];
    final date = DateTime.tryParse(session['date']?.toString() ?? '');
    final dateStr =
        date != null ? DateFormat('EEEE, MMMM d, yyyy').format(date) : '—';
    final day = session['day']?.toString() ?? '—';
    final block = session['block']?.toString() ?? '—';
    final week = session['week']?.toString() ?? '—';
    final notes = session['notes']?.toString().trim() ?? '';
    final note = session['note']?.toString().trim() ?? '';
    final sessionNote = notes.isNotEmpty ? notes : (note.isNotEmpty ? note : '');
    final durationMin = session['durationInMinutes'] ?? session['duration'];
    final rating = (session['sessionRating'] as num?)?.toDouble();
    final intensity = (session['intensity'] as num?)?.toDouble();

    // Session header info
    widgets.add(pw.Container(
      margin: const pw.EdgeInsets.only(top: 10, bottom: 12),
      padding: const pw.EdgeInsets.all(14),
      decoration: headerDecoration,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(dateStr,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: _pdfWhite)),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _infoChip('Block $block'),
              pw.SizedBox(width: 8),
              _infoChip('Week $week'),
              pw.SizedBox(width: 8),
              _infoChip(day),
              if (durationMin != null) ...[
                pw.SizedBox(width: 8),
                _infoChip('$durationMin min'),
              ],
            ],
          ),
          if (rating != null) ...[
            pw.SizedBox(height: 6),
            pw.Text('Session Rating: ${rating.toStringAsFixed(0)}/10',
                style: mutedStyle),
          ],
          if (sessionNote.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1C1C24),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SESSION NOTE',
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: _pdfDim,
                          letterSpacing: 0.8)),
                  pw.SizedBox(height: 4),
                  pw.Text(sessionNote,
                      style: pw.TextStyle(
                          fontSize: 9, color: _pdfMuted, lineSpacing: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    ));

    // Exercises
    final exercises = session['exercises'] as List? ?? [];
    for (final ex in exercises) {
      final exName = ex['name']?.toString() ?? 'Unknown Exercise';
      final exNote = ex['note']?.toString().trim() ?? '';
      final sets = ex['sets'] as List? ?? [];
      final category = ex['category']?.toString() ?? '';

      // Filter by exercise type
      if (config.exerciseFilter == ExerciseFilter.sbdOnly) {
        if (!_isMainSBD(exName) && !_isSBDVariation(exName)) continue;
      }

      // Build set table rows
      final setRows = <pw.TableRow>[];

      // Determine which columns to show based on actual data
      bool hasRpe = false;
      bool hasRir = false;
      bool hasPercentage = false;

      for (final set in sets) {
        if (set['rpe'] != null) hasRpe = true;
        if (set['rir'] != null) hasRir = true;
        if (set['percentage'] != null) hasPercentage = true;
      }

      // Header row
      final headerCells = <pw.Widget>[
        _tableCell('Set', isHeader: true),
        _tableCell('Weight', isHeader: true),
        _tableCell('Sets', isHeader: true),
        _tableCell('Reps', isHeader: true),
      ];
      if (hasPercentage) headerCells.add(_tableCell('%', isHeader: true));
      if (hasRpe) headerCells.add(_tableCell('RPE', isHeader: true));
      if (hasRir) headerCells.add(_tableCell('RIR', isHeader: true));

      setRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: _pdfCard),
        children: headerCells,
      ));

      // Data rows
      int setNum = 0;
      double exTopWeight = 0;
      int exTotalSets = 0;
      int exTotalReps = 0;
      double exVolume = 0;
      double exBestE1rm = 0;
      List<double> exRpeValues = [];

      for (final set in sets) {
        setNum++;
        final w = (set['weight'] as num?)?.toDouble() ?? 0;
        final r = (set['reps'] as num?)?.toInt() ?? 0;
        final c = (set['sets'] as num?)?.toInt() ?? 1;
        final rpe = (set['rpe'] as num?)?.toDouble();
        final rir = (set['rir'] as num?)?.toDouble();
        final pct = (set['percentage'] as num?)?.toDouble();

        if (w > exTopWeight) exTopWeight = w;
        exTotalSets += c;
        exTotalReps += r * c;
        exVolume += w * r * c;
        final e1rm = estimateE1RM(w, r);
        if (e1rm > exBestE1rm) exBestE1rm = e1rm;
        if (rpe != null && rpe > 0) exRpeValues.add(rpe);

        final cells = <pw.Widget>[
          _tableCell('$setNum'),
          _tableCell(w > 0 ? '${fmtNum(w)} kg' : '—'),
          _tableCell('$c'),
          _tableCell('$r'),
        ];
        if (hasPercentage) cells.add(_tableCell(pct != null ? '${fmtNum(pct)}%' : '—'));
        if (hasRpe) cells.add(_tableCell(rpe != null ? '${fmtNum(rpe)}' : '—'));
        if (hasRir) cells.add(_tableCell(rir != null ? '${fmtNum(rir)}' : '—'));

        setRows.add(pw.TableRow(children: cells));
      }

      // Exercise color
      PdfColor exColor = _pdfMuted;
      if (_getSBDCategory(exName) == 'Squat') exColor = _pdfRed;
      if (_getSBDCategory(exName) == 'Bench') exColor = _pdfBlue;
      if (_getSBDCategory(exName) == 'Deadlift') exColor = _pdfAmber;

      widgets.add(pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 3,
                  height: 14,
                  color: exColor,
                ),
                pw.SizedBox(width: 8),
                pw.Text(exName,
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _pdfWhite)),
                if (category.isNotEmpty) ...[
                  pw.SizedBox(width: 6),
                  pw.Text('($category)',
                      style: pw.TextStyle(fontSize: 8, color: _pdfDim)),
                ],
              ],
            ),
            pw.SizedBox(height: 6),
            if (setRows.length > 1)
              pw.Table(
                border: pw.TableBorder.all(color: _pdfBorder, width: 0.5),
                children: setRows,
              ),
            pw.SizedBox(height: 4),
            // Exercise summary line
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1C1C24),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                      '$exTotalSets sets · $exTotalReps reps · ${NumberFormat('#,###').format(exVolume)} kg vol',
                      style: pw.TextStyle(fontSize: 8, color: _pdfMuted)),
                  if (exBestE1rm > 0) ...[
                    pw.Text(
                        '  ·  e1RM: ${fmtNum(exBestE1rm)} kg',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: _pdfBlue,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                  if (exRpeValues.isNotEmpty) ...[
                    pw.Text(
                        '  ·  Avg RPE: ${(exRpeValues.reduce((a, b) => a + b) / exRpeValues.length).toStringAsFixed(1)}',
                        style: pw.TextStyle(fontSize: 8, color: _pdfAmber)),
                  ],
                ],
              ),
            ),
            if (exNote.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('Note: $exNote',
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: _pdfMuted,
                      fontStyle: pw.FontStyle.italic)),
            ],
          ],
        ),
      ));
    }

    return widgets;
  }

  static pw.Widget _infoChip(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF1C1C24),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 8, color: _pdfMuted)),
    );
  }

  // ─── File naming ───

  static String _generateFileName(PdfExportConfig config) {
    if (config.isCustomRange) {
      final from = DateFormat('yyyy-MM-dd').format(config.dateFrom!);
      final to = DateFormat('yyyy-MM-dd').format(config.dateTo!);
      return 'SBD_Training_Report_${from}_to_$to.pdf';
    }
    if (config.isEntireBlock) {
      return 'SBD_Block_${config.block}_Complete_Training_Report.pdf';
    }
    if (config.block != null && config.week != null) {
      return 'SBD_Block_${config.block}_Week_${config.week}_Training_Report.pdf';
    }
    return 'SBD_Training_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
  }
}
