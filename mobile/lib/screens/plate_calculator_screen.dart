import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PlateCalculatorScreen extends StatefulWidget {
  const PlateCalculatorScreen({super.key});

  @override
  State<PlateCalculatorScreen> createState() => _PlateCalculatorScreenState();
}

class _PlateCalculatorScreenState extends State<PlateCalculatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  double _targetWeight = 100;
  double _barWeight = 20;
  final _targetCtrl = TextEditingController(text: '100');
  
  // Available plates in kg (pairs)
  final List<double> _availablePlates = [25, 20, 15, 10, 5, 2.5, 1.25];
  final Map<double, bool> _plateInventory = {
    25: true, 20: true, 15: true, 10: true, 5: true, 2.5: true, 1.25: true,
  };

  // Warm-up
  int _warmupSets = 5;
  final List<double> _defaultWarmupPercentages = [0.0, 0.4, 0.55, 0.7, 0.8, 0.9];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  List<double> _calculatePlates(double totalWeight, double barWeight) {
    double remaining = (totalWeight - barWeight) / 2;
    if (remaining <= 0) return [];
    
    final plates = <double>[];
    final sortedPlates = _availablePlates.where((p) => _plateInventory[p] == true).toList()
      ..sort((a, b) => b.compareTo(a));
    
    for (final plate in sortedPlates) {
      while (remaining >= plate) {
        plates.add(plate);
        remaining -= plate;
      }
    }
    return plates;
  }

  List<Map<String, dynamic>> _generateWarmup(double workWeight) {
    final sets = <Map<String, dynamic>>[];
    final percentages = _defaultWarmupPercentages.take(_warmupSets + 1).toList();
    
    for (int i = 0; i < percentages.length; i++) {
      final pct = percentages[i];
      double weight;
      int reps;
      
      if (pct == 0) {
        weight = _barWeight;
        reps = 10;
      } else {
        weight = (workWeight * pct / 2.5).round() * 2.5;
        if (weight < _barWeight) weight = _barWeight;
        if (pct <= 0.5) reps = 8;
        else if (pct <= 0.65) reps = 5;
        else if (pct <= 0.8) reps = 3;
        else reps = 2;
      }
      
      sets.add({
        'set': i + 1,
        'weight': weight,
        'reps': reps,
        'percentage': (pct * 100).toInt(),
        'plates': _calculatePlates(weight, _barWeight),
      });
    }
    
    // Add working set
    sets.add({
      'set': sets.length + 1,
      'weight': workWeight,
      'reps': 0, // user decides
      'percentage': 100,
      'plates': _calculatePlates(workWeight, _barWeight),
      'isWorking': true,
    });
    
    return sets;
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
        title: const Text('Calculator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.accentBlue,
          labelColor: AppColors.accentBlueLight,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'PLATES'),
            Tab(text: 'WARM-UP'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildWeightInput(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildPlateTab(),
                _buildWarmupTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TARGET WEIGHT', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _stepButton(Icons.remove, () {
                      setState(() {
                        _targetWeight = math.max(_barWeight, _targetWeight - 2.5);
                        _targetCtrl.text = _targetWeight.toString().replaceAll('.0', '');
                      });
                    }),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _targetCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (v) {
                          final w = double.tryParse(v);
                          if (w != null && w >= _barWeight) setState(() => _targetWeight = w);
                        },
                      ),
                    ),
                    const Text(' kg', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    _stepButton(Icons.add, () {
                      setState(() {
                        _targetWeight += 2.5;
                        _targetCtrl.text = _targetWeight.toString().replaceAll('.0', '');
                      });
                    }),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('BAR', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 20, label: Text('20', style: TextStyle(fontSize: 12))),
                  ButtonSegment(value: 25, label: Text('25', style: TextStyle(fontSize: 12))),
                ],
                selected: {_barWeight},
                onSelectionChanged: (v) => setState(() => _barWeight = v.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? AppColors.accentBlue : AppColors.inputBg),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary),
                  side: WidgetStateProperty.all(const BorderSide(color: AppColors.borderColor)),
                  minimumSize: WidgetStateProperty.all(const Size(40, 36)),
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
    );
  }

  Widget _buildPlateTab() {
    final plates = _calculatePlates(_targetWeight, _barWeight);
    final perSide = (_targetWeight - _barWeight) / 2;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Visual barbell
        _buildBarbellVisual(plates),
        const SizedBox(height: 24),
        // Plate breakdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('EACH SIDE', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  Text('${perSide.toString().replaceAll('.0', '')} kg', style: const TextStyle(fontSize: 14, color: AppColors.accentBlueLight, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 16),
              if (plates.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Bar only', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                ))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: plates.map((p) => _buildPlateChip(p)).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Plate inventory toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PLATE INVENTORY', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availablePlates.map((p) => FilterChip(
                  selected: _plateInventory[p] == true,
                  onSelected: (v) => setState(() => _plateInventory[p] = v),
                  label: Text('${p.toString().replaceAll('.0', '')} kg'),
                  selectedColor: AppColors.accentBlueBg,
                  checkmarkColor: AppColors.accentBlueLight,
                  backgroundColor: AppColors.inputBg,
                  side: BorderSide(color: _plateInventory[p] == true ? AppColors.accentBlue.withValues(alpha: 0.3) : AppColors.borderColor),
                  labelStyle: TextStyle(
                    color: _plateInventory[p] == true ? AppColors.accentBlueLight : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarbellVisual(List<double> plates) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left plates (reversed)
          ...plates.reversed.map((p) => _buildPlateVisual(p)),
          // Bar
          Container(
            width: 60, height: 8,
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Right plates
          ...plates.map((p) => _buildPlateVisual(p)),
        ],
      ),
    );
  }

  Widget _buildPlateVisual(double weight) {
    double height;
    Color color;
    if (weight >= 25) { height = 60; color = AppColors.accentRed; }
    else if (weight >= 20) { height = 56; color = AppColors.accentBlue; }
    else if (weight >= 15) { height = 48; color = AppColors.statYellow; }
    else if (weight >= 10) { height = 42; color = AppColors.accentGreen; }
    else if (weight >= 5) { height = 36; color = AppColors.textSecondary; }
    else { height = 28; color = AppColors.textMuted; }

    return Container(
      width: 10, height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildPlateChip(double weight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentBlueBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
      ),
      child: Text(
        '${weight.toString().replaceAll('.0', '')} kg',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accentBlueLight, fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildWarmupTab() {
    final warmupSets = _generateWarmup(_targetWeight);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Warm-up sets slider
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('WARM-UP SETS', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  Text('$_warmupSets sets', style: const TextStyle(fontSize: 14, color: AppColors.accentBlueLight, fontWeight: FontWeight.w600)),
                ],
              ),
              Slider(
                value: _warmupSets.toDouble(),
                min: 2,
                max: 5,
                divisions: 3,
                activeColor: AppColors.accentBlue,
                inactiveColor: AppColors.borderColor,
                onChanged: (v) => setState(() => _warmupSets = v.toInt()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Warm-up progression
        ...warmupSets.map((set) => _buildWarmupSetRow(set)).toList(),
      ],
    );
  }

  Widget _buildWarmupSetRow(Map<String, dynamic> set) {
    final isWorking = set['isWorking'] == true;
    final weight = (set['weight'] as double);
    final reps = set['reps'] as int;
    final pct = set['percentage'] as int;
    final plates = set['plates'] as List<double>;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWorking ? AppColors.accentBlueBg : AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWorking ? AppColors.accentBlue.withValues(alpha: 0.3) : AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isWorking ? AppColors.accentBlue : AppColors.inputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isWorking ? 'W' : '${set['set']}',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: isWorking ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${weight.toString().replaceAll('.0', '')} kg',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: isWorking ? AppColors.accentBlueLight : AppColors.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isWorking)
                      Text('× $reps reps', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    if (isWorking)
                      const Text('Working Set', style: TextStyle(fontSize: 13, color: AppColors.accentBlueLight, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (plates.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    plates.map((p) => '${p.toString().replaceAll('.0', '')}').join(' + '),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace'),
                  ),
                ] else
                  const Text('Bar only', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isWorking ? AppColors.accentBlue.withValues(alpha: 0.15) : AppColors.inputBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$pct%',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: isWorking ? AppColors.accentBlueLight : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
