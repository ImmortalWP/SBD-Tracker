import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

/// Goals tracking screen for powerlifting targets.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  static const String _key = 'goals_v1';
  List<Map<String, dynamic>> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _AddGoalSheet(
        onAdd: (goal) {
          setState(() => _goals.insert(0, goal));
          _save();
        },
      ),
    );
  }

  void _toggleGoal(int index) {
    setState(() {
      _goals[index]['completed'] = !(_goals[index]['completed'] ?? false);
      if (_goals[index]['completed'] == true) {
        _goals[index]['completedAt'] = DateTime.now().toIso8601String();
      } else {
        _goals[index].remove('completedAt');
      }
    });
    _save();
  }

  void _deleteGoal(int index) {
    setState(() => _goals.removeAt(index));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final active = _goals.where((g) => g['completed'] != true).toList();
    final completed = _goals.where((g) => g['completed'] == true).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Goals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.accentBlueLight),
            onPressed: _addGoal,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          if (active.isEmpty && completed.isEmpty)
            _buildEmptyState()
          else ...[
            if (active.isNotEmpty) ...[
              const Text('ACTIVE GOALS', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              ...active.map((g) {
                final idx = _goals.indexOf(g);
                return _buildGoalCard(idx, g);
              }).toList(),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('COMPLETED', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              ...completed.map((g) {
                final idx = _goals.indexOf(g);
                return _buildGoalCard(idx, g);
              }).toList(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.flag_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('No Goals Set', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Set a goal to track your powerlifting progress.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _addGoal,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(int index, Map<String, dynamic> goal) {
    final isCompleted = goal['completed'] == true;
    final title = goal['title']?.toString() ?? '';
    final target = goal['target']?.toString() ?? '';
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
    if (targetNum != null && targetNum > 0 && current > 0) {
      progress = (current / targetNum).clamp(0, 1);
    }
    if (isCompleted) progress = 1;

    return Dismissible(
      key: Key('goal_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.accentRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: AppColors.accentRed, size: 20),
      ),
      onDismissed: (_) => _deleteGoal(index),
      child: GestureDetector(
        onTap: () => _toggleGoal(index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.accentGreen.withValues(alpha: 0.05) : AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isCompleted ? AppColors.accentGreen.withValues(alpha: 0.2) : AppColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? AppColors.accentGreen : AppColors.inputBg,
                      border: Border.all(color: isCompleted ? AppColors.accentGreen : AppColors.borderColor, width: 2),
                    ),
                    child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (target.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(target, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: catColor)),
                  ),
                ],
              ),
              if (targetNum != null && !isCompleted) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.inputBg,
                    valueColor: AlwaysStoppedAnimation(catColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${current.toStringAsFixed(1)} / ${targetNum.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace'),
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
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _currentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'GOAL TITLE',
              hintText: 'e.g., Squat 200kg',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _currentCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'CURRENT (kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'TARGET (kg)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            dropdownColor: AppColors.cardBg,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(labelText: 'CATEGORY'),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) { if (v != null) setState(() => _category = v); },
          ),
          const SizedBox(height: 20),
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
