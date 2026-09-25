import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  static const String _key = 'goals_v1';
  List<Map<String, dynamic>> _goals = [];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() => _goals = list.map((e) => Map<String, dynamic>.from(e)).toList());
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_goals));
  }

  void _addGoal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
      builder: (ctx) => _AddGoalSheet(onAdd: (goal) { setState(() => _goals.insert(0, goal)); _save(); }),
    );
  }

  void _toggleGoal(int index) {
    setState(() {
      _goals[index]['completed'] = !(_goals[index]['completed'] ?? false);
      if (_goals[index]['completed'] == true) _goals[index]['completedAt'] = DateTime.now().toIso8601String();
      else _goals[index].remove('completedAt');
    });
    _save();
  }

  void _deleteGoal(int index) { setState(() => _goals.removeAt(index)); _save(); }

  @override
  Widget build(BuildContext context) {
    final active = _goals.where((g) => g['completed'] != true).toList();
    final completed = _goals.where((g) => g['completed'] == true).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Goals', style: AppTypography.h2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded, color: AppColors.accentBlueLight), onPressed: _addGoal),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 40),
        children: [
          if (active.isEmpty && completed.isEmpty) ...[
            const SizedBox(height: 60),
            Center(child: Column(
              children: [
                const Icon(Icons.flag_rounded, size: 40, color: AppColors.textMuted),
                const SizedBox(height: Spacing.base),
                const Text('No goals set', style: AppTypography.bodyMedium),
                const SizedBox(height: Spacing.sm),
                Text('Tap + to add your first goal.', style: AppTypography.bodySmall),
              ],
            )),
          ] else ...[
            if (active.isNotEmpty) ...[
              const Text('ACTIVE', style: AppTypography.sectionHeader),
              const SizedBox(height: Spacing.md),
              ...active.map((g) => _buildGoalRow(_goals.indexOf(g), g)).toList(),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: Spacing.xl),
              const Text('COMPLETED', style: AppTypography.sectionHeader),
              const SizedBox(height: Spacing.md),
              ...completed.map((g) => _buildGoalRow(_goals.indexOf(g), g)).toList(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGoalRow(int index, Map<String, dynamic> goal) {
    final isCompleted = goal['completed'] == true;
    final title = goal['title']?.toString() ?? '';
    final category = goal['category']?.toString() ?? 'General';
    final current = (goal['current'] as num?)?.toDouble() ?? 0;
    final targetNum = (goal['targetValue'] as num?)?.toDouble();

    Color catColor;
    switch (category) {
      case 'Squat': catColor = AppColors.accentRed; break;
      case 'Bench': catColor = AppColors.accentBlue; break;
      case 'Deadlift': catColor = AppColors.accentAmber; break;
      case 'Total': catColor = AppColors.statPurple; break;
      default: catColor = AppColors.accentGreen;
    }

    double progress = 0;
    if (targetNum != null && targetNum > 0 && current > 0) progress = (current / targetNum).clamp(0, 1);
    if (isCompleted) progress = 1;

    return Dismissible(
      key: Key('goal_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        child: const Icon(Icons.delete_outline, color: AppColors.accentRed, size: 18),
      ),
      onDismissed: (_) => _deleteGoal(index),
      child: GestureDetector(
        onTap: () => _toggleGoal(index),
        child: Container(
          margin: const EdgeInsets.only(bottom: Spacing.sm),
          padding: const EdgeInsets.all(Spacing.base),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? AppColors.accentGreen : Colors.transparent,
                      border: Border.all(color: isCompleted ? AppColors.accentGreen : AppColors.textMuted, width: 1.5),
                    ),
                    child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(category, style: AppTypography.labelSmall.copyWith(color: catColor)),
                ],
              ),
              if (targetNum != null && !isCompleted) ...[
                const SizedBox(height: Spacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.elevated,
                    valueColor: AlwaysStoppedAnimation(catColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '${current.toStringAsFixed(0)} / ${targetNum.toStringAsFixed(0)} kg',
                  style: AppTypography.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddGoalSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const _AddGoalSheet({required this.onAdd});
  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _titleCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  String _category = 'General';
  final _categories = ['Squat', 'Bench', 'Deadlift', 'Total', 'Bodyweight', 'General'];

  @override
  void dispose() { _titleCtrl.dispose(); _targetCtrl.dispose(); _currentCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, MediaQuery.of(context).viewInsets.bottom + Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Goal', style: AppTypography.h2),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _titleCtrl,
            style: AppTypography.body,
            decoration: const InputDecoration(labelText: 'GOAL TITLE', hintText: 'e.g., Squat 200kg'),
          ),
          const SizedBox(height: Spacing.md),
          Row(children: [
            Expanded(child: TextField(controller: _currentCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: AppTypography.body, decoration: const InputDecoration(labelText: 'CURRENT (kg)'))),
            const SizedBox(width: Spacing.md),
            Expanded(child: TextField(controller: _targetCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: AppTypography.body, decoration: const InputDecoration(labelText: 'TARGET (kg)'))),
          ]),
          const SizedBox(height: Spacing.md),
          DropdownButtonFormField<String>(
            value: _category,
            dropdownColor: AppColors.cardBg,
            style: AppTypography.body,
            decoration: const InputDecoration(labelText: 'CATEGORY'),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) { if (v != null) setState(() => _category = v); },
          ),
          const SizedBox(height: Spacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_titleCtrl.text.trim().isEmpty) return;
                widget.onAdd({
                  'title': _titleCtrl.text.trim(),
                  'target': _targetCtrl.text.isNotEmpty ? '${_targetCtrl.text} kg target' : '',
                  'targetValue': double.tryParse(_targetCtrl.text),
                  'current': double.tryParse(_currentCtrl.text) ?? 0,
                  'category': _category,
                  'completed': false,
                  'createdAt': DateTime.now().toIso8601String(),
                });
                Navigator.pop(context);
              },
              child: const Text('Add Goal'),
            ),
          ),
        ],
      ),
    );
  }
}
