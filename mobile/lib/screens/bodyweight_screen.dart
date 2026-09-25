import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class BodyweightScreen extends StatefulWidget {
  const BodyweightScreen({super.key});
  @override
  State<BodyweightScreen> createState() => _BodyweightScreenState();
}

class _BodyweightScreenState extends State<BodyweightScreen> {
  static const String _key = 'bodyweight_log_v1';
  final _weightCtrl = TextEditingController();
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() { super.initState(); _loadData(); }

  @override
  void dispose() { _weightCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() => _entries = list.map((e) => Map<String, dynamic>.from(e)).toList());
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_entries));
  }

  void _addEntry() {
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (weight == null || weight <= 0 || weight > 500) return;
    setState(() {
      _entries.insert(0, { 'weight': weight, 'date': DateTime.now().toIso8601String() });
      _weightCtrl.clear();
    });
    _save();
  }

  void _deleteEntry(int index) {
    setState(() => _entries.removeAt(index));
    _save();
  }

  double? get _currentWeight => _entries.isNotEmpty ? (_entries.first['weight'] as num).toDouble() : null;
  double? get _previousWeight => _entries.length > 1 ? (_entries[1]['weight'] as num).toDouble() : null;
  double? get _change => (_currentWeight != null && _previousWeight != null) ? _currentWeight! - _previousWeight! : null;

  double? get _sevenDayAvg {
    if (_entries.isEmpty) return null;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = _entries.where((e) {
      final dt = DateTime.tryParse(e['date']?.toString() ?? '');
      return dt != null && dt.isAfter(cutoff);
    }).toList();
    if (recent.isEmpty) return null;
    final sum = recent.fold<double>(0, (acc, e) => acc + (e['weight'] as num).toDouble());
    return sum / recent.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Bodyweight', style: AppTypography.h2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 40),
        children: [
          // Current weight
          Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Column(
              children: [
                Text(
                  _currentWeight != null ? '${_currentWeight!.toStringAsFixed(1)}' : '—',
                  style: AppTypography.displayLarge.copyWith(fontSize: 44),
                ),
                Text('kg', style: AppTypography.bodyMedium),
                if (_change != null) ...[
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '${_change! > 0 ? '+' : ''}${_change!.toStringAsFixed(1)} kg',
                    style: AppTypography.mono.copyWith(
                      color: _change! > 0 ? AppColors.accentAmber : _change! < 0 ? AppColors.accentGreen : AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (_sevenDayAvg != null) ...[
                  const SizedBox(height: Spacing.md),
                  Text('7-day avg: ${_sevenDayAvg!.toStringAsFixed(1)} kg', style: AppTypography.labelSmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // Input
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Weight (kg)',
                      hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.base, vertical: Spacing.md),
                    ),
                    onSubmitted: (_) => _addEntry(),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              GestureDetector(
                onTap: _addEntry,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          // Mini chart
          if (_entries.length >= 2) ...[
            const SizedBox(height: Spacing.xl),
            Container(
              height: 120,
              padding: const EdgeInsets.all(Spacing.base),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: CustomPaint(
                size: Size.infinite,
                painter: _WeightChartPainter(_entries.take(14).toList().reversed.toList()),
              ),
            ),
          ],
          const SizedBox(height: Spacing.xl),
          // History
          const Text('HISTORY', style: AppTypography.sectionHeader),
          const SizedBox(height: Spacing.md),
          if (_entries.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(Spacing.xxl),
              child: Text('No entries yet.', style: AppTypography.bodySmall),
            ))
          else
            ..._entries.asMap().entries.map((e) {
              final entry = e.value;
              final weight = (entry['weight'] as num).toDouble();
              final date = DateTime.tryParse(entry['date']?.toString() ?? '');
              final dateStr = date != null ? DateFormat('EEE, MMM d').format(date) : '';
              return Dismissible(
                key: Key('bw_${e.key}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: Spacing.lg),
                  child: const Icon(Icons.delete_outline, color: AppColors.accentRed, size: 18),
                ),
                onDismissed: (_) => _deleteEntry(e.key),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateStr, style: AppTypography.bodySmall),
                      Text('${weight.toStringAsFixed(1)} kg', style: AppTypography.mono.copyWith(fontSize: 14)),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> entries;
  _WeightChartPainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;
    final weights = entries.map((e) => (e['weight'] as num).toDouble()).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b) - 1;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 1;
    final range = maxW - minW;
    if (range <= 0) return;

    final paint = Paint()..color = AppColors.accentBlue..strokeWidth = 2..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = AppColors.accentBlueLight..style = PaintingStyle.fill;
    final path = Path();
    final step = size.width / (weights.length - 1);

    for (int i = 0; i < weights.length; i++) {
      final x = i * step;
      final y = size.height - ((weights[i] - minW) / range * size.height);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
    for (int i = 0; i < weights.length; i++) {
      final x = i * step;
      final y = size.height - ((weights[i] - minW) / range * size.height);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
