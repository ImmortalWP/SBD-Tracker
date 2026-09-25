import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

/// Bodyweight tracking screen with history chart and logging.
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
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

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
      _entries.insert(0, {
        'weight': weight,
        'date': DateTime.now().toIso8601String(),
      });
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

  double? get _change {
    if (_currentWeight == null || _previousWeight == null) return null;
    return _currentWeight! - _previousWeight!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Bodyweight', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          // Current weight display
          _buildCurrentWeightCard(),
          const SizedBox(height: 20),
          // Input
          _buildInputSection(),
          const SizedBox(height: 24),
          // Mini chart
          if (_entries.length >= 2) ...[
            _buildMiniChart(),
            const SizedBox(height: 24),
          ],
          // History
          const Text('HISTORY', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          if (_entries.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(30),
              child: Text('No entries yet. Log your first bodyweight above.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ))
          else
            ..._entries.asMap().entries.map((e) => _buildEntryRow(e.key, e.value)).toList(),
        ],
      ),
    );
  }

  Widget _buildCurrentWeightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          const Text('CURRENT', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(
            _currentWeight != null ? '${_currentWeight!.toStringAsFixed(1)} kg' : '— kg',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          if (_change != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _change! > 0 ? Icons.trending_up : _change! < 0 ? Icons.trending_down : Icons.trending_flat,
                  size: 16,
                  color: _change! > 0 ? AppColors.accentRed : _change! < 0 ? AppColors.accentGreen : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_change! > 0 ? '+' : ''}${_change!.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: _change! > 0 ? AppColors.accentRed : _change! < 0 ? AppColors.accentGreen : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: TextField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Enter weight (kg)',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _addEntry(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _addEntry,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniChart() {
    final recent = _entries.take(14).toList().reversed.toList();
    if (recent.length < 2) return const SizedBox();

    final weights = recent.map((e) => (e['weight'] as num).toDouble()).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b) - 1;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 1;
    final range = maxW - minW;

    return Container(
      padding: const EdgeInsets.all(16),
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _WeightChartPainter(weights, minW, range),
      ),
    );
  }

  Widget _buildEntryRow(int index, Map<String, dynamic> entry) {
    final weight = (entry['weight'] as num).toDouble();
    final date = DateTime.tryParse(entry['date']?.toString() ?? '');
    final dateStr = date != null ? DateFormat('EEE, MMM d, yyyy').format(date) : 'Unknown';

    return Dismissible(
      key: Key('bw_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.accentRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete, color: AppColors.accentRed, size: 20),
      ),
      onDismissed: (_) => _deleteEntry(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dateStr, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<double> weights;
  final double minW;
  final double range;

  _WeightChartPainter(this.weights, this.minW, this.range);

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.length < 2 || range <= 0) return;

    final paint = Paint()
      ..color = AppColors.accentBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.accentBlueLight
      ..style = PaintingStyle.fill;

    final path = Path();
    final step = size.width / (weights.length - 1);

    for (int i = 0; i < weights.length; i++) {
      final x = i * step;
      final y = size.height - ((weights[i] - minW) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Draw dots
    for (int i = 0; i < weights.length; i++) {
      final x = i * step;
      final y = size.height - ((weights[i] - minW) / range * size.height);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
