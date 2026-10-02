import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_colors.dart';

class PdfExportScreen extends StatefulWidget {
  final List<dynamic> sessions;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic> prs;

  const PdfExportScreen({
    super.key,
    required this.sessions,
    this.profile,
    required this.prs,
  });

  @override
  State<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends State<PdfExportScreen> {
  // ─── State ───
  int? _selectedBlock;
  int? _selectedWeek;
  String _weekMode = 'selected'; // 'selected', 'entire', 'custom'
  DateTime? _customFrom;
  DateTime? _customTo;

  ExerciseFilter _exerciseFilter = ExerciseFilter.sbdPlusAccessories;
  ReportDetail _detailLevel = ReportDetail.complete;

  // Optional data toggles
  bool _includeSetsReps = true;
  bool _includeWeight = true;
  bool _includeRPE = true;
  bool _includeRIR = true;
  bool _includeExerciseNotes = true;
  bool _includeSessionNotes = true;
  bool _includeBodyweight = true;
  bool _includeDuration = true;
  bool _includePRs = true;
  bool _includeSessionRating = true;

  bool _generating = false;
  File? _generatedFile;
  String? _error;

  // Colors
  static const Color _bg = AppColors.bg;
  static const Color _card = AppColors.cardBg;
  static const Color _accent = AppColors.accentBlueLight;
  static const Color _textHigh = AppColors.textPrimary;
  static const Color _textMuted = AppColors.textSecondary;
  static const Color _textDim = AppColors.textMuted;
  static const Color _border = AppColors.borderColor;

  // ─── Derived data ───

  List<int> get _availableBlocks {
    final blocks = <int>{};
    for (final s in widget.sessions) {
      final b = s['block'];
      if (b != null) {
        final bInt = b is int ? b : int.tryParse(b.toString());
        if (bInt != null) blocks.add(bInt);
      }
    }
    final sorted = blocks.toList()..sort();
    return sorted;
  }

  List<int> get _availableWeeks {
    if (_selectedBlock == null) return [];
    final weeks = <int>{};
    for (final s in widget.sessions) {
      final b = s['block'];
      final bInt = b is int ? b : int.tryParse(b?.toString() ?? '');
      if (bInt != _selectedBlock) continue;
      final w = s['week'];
      if (w != null) {
        final wInt = w is int ? w : int.tryParse(w.toString());
        if (wInt != null) weeks.add(wInt);
      }
    }
    final sorted = weeks.toList()..sort();
    return sorted;
  }

  int get _filteredSessionCount {
    return widget.sessions.where((s) {
      if (_weekMode == 'custom') {
        if (_customFrom == null || _customTo == null) return false;
        final date = DateTime.tryParse(s['date']?.toString() ?? '');
        if (date == null) return false;
        return !date.isBefore(_customFrom!) &&
            !date.isAfter(_customTo!.add(const Duration(days: 1)));
      }
      if (_selectedBlock == null) return false;
      final b = s['block'];
      final bInt = b is int ? b : int.tryParse(b?.toString() ?? '');
      if (bInt != _selectedBlock) return false;
      if (_weekMode == 'selected' && _selectedWeek != null) {
        final w = s['week'];
        final wInt = w is int ? w : int.tryParse(w?.toString() ?? '');
        if (wInt != _selectedWeek) return false;
      }
      return true;
    }).length;
  }

  bool get _canGenerate {
    if (_weekMode == 'custom') {
      return _customFrom != null && _customTo != null;
    }
    if (_selectedBlock == null) return false;
    if (_weekMode == 'selected' && _selectedWeek == null) return false;
    return true;
  }

  // ─── Actions ───

  Future<void> _generatePdf() async {
    if (!_canGenerate) return;
    setState(() {
      _generating = true;
      _error = null;
      _generatedFile = null;
    });

    try {
      final auth = context.read<AuthService>();
      final config = PdfExportConfig(
        block: _weekMode == 'custom' ? null : _selectedBlock,
        week: _weekMode == 'selected' ? _selectedWeek : null,
        dateFrom: _weekMode == 'custom' ? _customFrom : null,
        dateTo: _weekMode == 'custom' ? _customTo : null,
        exerciseFilter: _exerciseFilter,
        detailLevel: _detailLevel,
        includedMetrics: {
          if (_includeSetsReps) 'setsReps',
          if (_includeWeight) 'weight',
          if (_includeRPE) 'rpe',
          if (_includeRIR) 'rir',
          if (_includeExerciseNotes) 'exerciseNotes',
          if (_includeSessionNotes) 'sessionNotes',
          if (_includeBodyweight) 'bodyweight',
          if (_includeDuration) 'duration',
          if (_includePRs) 'prs',
          if (_includeSessionRating) 'sessionRating',
        },
      );

      final file = await PdfExportService.generateReport(
        allSessions: widget.sessions,
        config: config,
        username: auth.username ?? 'Athlete',
        profile: widget.profile,
        prs: widget.prs,
      );

      if (mounted) {
        setState(() {
          _generatedFile = file;
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _generating = false;
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_generatedFile == null) return;
    await PdfExportService.shareReport(_generatedFile!);
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_customFrom ?? now) : (_customTo ?? now),
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accent,
              onPrimary: Colors.white,
              surface: _card,
              onSurface: _textHigh,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _customFrom = picked;
        } else {
          _customTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PDF Training Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _textHigh,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _textMuted, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _generatedFile != null
            ? _buildSuccessView()
            : _generating
                ? _buildLoadingView()
                : _buildConfigView(),
      ),
    );
  }

  // ─── Config View ───

  Widget _buildConfigView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        // Training Block
        _buildSectionHeader('TRAINING BLOCK'),
        const SizedBox(height: 10),
        _buildDropdown<int>(
          value: _selectedBlock,
          hint: 'Select Training Block',
          items: _availableBlocks
              .map((b) => DropdownMenuItem(value: b, child: Text('Block $b')))
              .toList(),
          onChanged: (v) {
            setState(() {
              _selectedBlock = v;
              _selectedWeek = null;
            });
          },
        ),
        const SizedBox(height: 20),

        // Week Selection Mode
        _buildSectionHeader('TRAINING WEEK'),
        const SizedBox(height: 10),
        _buildWeekModeSelector(),
        const SizedBox(height: 10),

        if (_weekMode == 'selected') ...[
          _buildDropdown<int>(
            value: _selectedWeek,
            hint: 'Select Week',
            items: _availableWeeks
                .map((w) => DropdownMenuItem(value: w, child: Text('Week $w')))
                .toList(),
            onChanged: (v) => setState(() => _selectedWeek = v),
          ),
        ] else if (_weekMode == 'custom') ...[
          _buildDateRangeSelector(),
        ],

        const SizedBox(height: 20),

        // Exercise Filter
        _buildSectionHeader('EXERCISES'),
        const SizedBox(height: 10),
        _buildExerciseFilterSelector(),
        const SizedBox(height: 20),

        // Detail Level
        _buildSectionHeader('REPORT DETAIL'),
        const SizedBox(height: 10),
        _buildDetailLevelSelector(),
        const SizedBox(height: 20),

        // Optional Data
        _buildSectionHeader('INCLUDE DATA'),
        const SizedBox(height: 10),
        _buildOptionalDataToggles(),
        const SizedBox(height: 24),

        // Session Count Preview
        if (_canGenerate) ...[
          _buildPreviewCard(),
          const SizedBox(height: 16),
        ],

        // Error
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentRed.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.accentRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: AppColors.accentRed, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Generate Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canGenerate ? _generatePdf : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: _accent.withOpacity(0.3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.picture_as_pdf, size: 20),
                const SizedBox(width: 8),
                Text(
                  _canGenerate
                      ? 'Generate PDF Report'
                      : 'Select Block & Week to Continue',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Loading View ───

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: _accent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Generating training report...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textHigh,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This may take a moment for large reports',
            style: TextStyle(fontSize: 13, color: _textMuted),
          ),
        ],
      ),
    );
  }

  // ─── Success View ───

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGreen.withOpacity(0.15),
                border: Border.all(
                    color: AppColors.accentGreen.withOpacity(0.4), width: 2),
              ),
              child: const Icon(Icons.check, color: AppColors.accentGreen, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'PDF generated successfully!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textHigh,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _generatedFile!.path.split('/').last,
              style: const TextStyle(fontSize: 12, color: _textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.download, size: 20),
                label: const Text('Download PDF',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _generatedFile = null),
              child: const Text(
                'Generate Another Report',
                style: TextStyle(color: _accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Component Builders ───

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: _textDim,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: _card,
          hint: Text(hint,
              style: const TextStyle(fontSize: 14, color: _textDim)),
          style: const TextStyle(
              fontSize: 14,
              color: _textHigh,
              fontWeight: FontWeight.w600),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildWeekModeSelector() {
    return Row(
      children: [
        _buildModeChip('Selected Week', 'selected'),
        const SizedBox(width: 8),
        _buildModeChip('Entire Block', 'entire'),
        const SizedBox(width: 8),
        _buildModeChip('Date Range', 'custom'),
      ],
    );
  }

  Widget _buildModeChip(String label, String mode) {
    final selected = _weekMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _weekMode = mode;
          if (mode == 'custom') {
            _selectedBlock = null;
            _selectedWeek = null;
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _accent.withOpacity(0.15) : _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _accent.withOpacity(0.5) : _border,
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _accent : _textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: _textDim),
                  const SizedBox(width: 8),
                  Text(
                    _customFrom != null
                        ? DateFormat('MMM d, yyyy').format(_customFrom!)
                        : 'From',
                    style: TextStyle(
                      fontSize: 13,
                      color: _customFrom != null ? _textHigh : _textDim,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: _textDim),
                  const SizedBox(width: 8),
                  Text(
                    _customTo != null
                        ? DateFormat('MMM d, yyyy').format(_customTo!)
                        : 'To',
                    style: TextStyle(
                      fontSize: 13,
                      color: _customTo != null ? _textHigh : _textDim,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseFilterSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildRadioTile<ExerciseFilter>(
            'SBD Only',
            'Squat, Bench, Deadlift (competition lifts)',
            ExerciseFilter.sbdOnly,
            _exerciseFilter,
            (v) => setState(() => _exerciseFilter = v!),
          ),
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: _border),
          _buildRadioTile<ExerciseFilter>(
            'SBD + Accessories',
            'Competition lifts + all accessory work',
            ExerciseFilter.sbdPlusAccessories,
            _exerciseFilter,
            (v) => setState(() => _exerciseFilter = v!),
          ),
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: _border),
          _buildRadioTile<ExerciseFilter>(
            'All Exercises',
            'Every recorded exercise',
            ExerciseFilter.all,
            _exerciseFilter,
            (v) => setState(() => _exerciseFilter = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLevelSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildRadioTile<ReportDetail>(
            'Summary',
            'Overview tables and metrics only',
            ReportDetail.summary,
            _detailLevel,
            (v) => setState(() => _detailLevel = v!),
          ),
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: _border),
          _buildRadioTile<ReportDetail>(
            'Complete Report',
            'Full session details with every set and rep',
            ReportDetail.complete,
            _detailLevel,
            (v) => setState(() => _detailLevel = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile<T>(
    String title,
    String subtitle,
    T value,
    T groupValue,
    ValueChanged<T?> onChanged,
  ) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _accent : _textDim,
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _accent,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? _textHigh : _textMuted,
                      )),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: _textDim)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalDataToggles() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildToggle('Sets & Reps', _includeSetsReps,
              (v) => setState(() => _includeSetsReps = v)),
          _divider(),
          _buildToggle('Weight', _includeWeight,
              (v) => setState(() => _includeWeight = v)),
          _divider(),
          _buildToggle('RPE', _includeRPE,
              (v) => setState(() => _includeRPE = v)),
          _divider(),
          _buildToggle('RIR', _includeRIR,
              (v) => setState(() => _includeRIR = v)),
          _divider(),
          _buildToggle('Exercise Notes', _includeExerciseNotes,
              (v) => setState(() => _includeExerciseNotes = v)),
          _divider(),
          _buildToggle('Session Notes', _includeSessionNotes,
              (v) => setState(() => _includeSessionNotes = v)),
          _divider(),
          _buildToggle('Bodyweight', _includeBodyweight,
              (v) => setState(() => _includeBodyweight = v)),
          _divider(),
          _buildToggle('Training Duration', _includeDuration,
              (v) => setState(() => _includeDuration = v)),
          _divider(),
          _buildToggle('Personal Records', _includePRs,
              (v) => setState(() => _includePRs = v)),
          _divider(),
          _buildToggle('Session Rating', _includeSessionRating,
              (v) => setState(() => _includeSessionRating = v)),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: _textHigh, fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            activeColor: _accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: _border,
    );
  }

  Widget _buildPreviewCard() {
    final count = _filteredSessionCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics_outlined,
              color: _accent.withOpacity(0.8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count session${count != 1 ? 's' : ''} found',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textHigh,
                  ),
                ),
                Text(
                  _detailLevel == ReportDetail.complete
                      ? 'Complete report with session details'
                      : 'Summary overview report',
                  style: const TextStyle(fontSize: 11, color: _textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
