import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/offline_queue.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AddSessionScreen extends StatefulWidget {
  final Map<String, dynamic>? existingSession;
  const AddSessionScreen({super.key, this.existingSession});

  @override
  State<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final _blockCtrl = TextEditingController();
  final _weekCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _day = 'Sunday';
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _loading = false;
  String _error = '';

  // Timer
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsed = '00:00';

  final _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final _mainLifts = ['Squat', 'Bench', 'Deadlift'];

  static const Map<String, List<String>> _secondaryLifts = {
    'Squat': ['Pause Squat', 'Box Squat', 'Tempo Squat', 'Pin Squat'],
    'Bench': ['Pause Bench', 'Close Grip Bench', 'Larsen Press', 'Pin Bench', 'Wide Grip Bench'],
    'Deadlift': ['Pause Deadlift', 'Deficit Deadlift', 'Block Pull', 'RDL'],
  };

  List<String> get _allSecondaryLifts => _secondaryLifts.values.expand((e) => e).toList();

  List<Map<String, dynamic>> _exercises = [];
  bool get _isEditing => widget.existingSession != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.existingSession!;
      _blockCtrl.text = s['block'].toString();
      if (s['week'] != null) _weekCtrl.text = s['week'].toString();
      _day = s['day'] ?? 'Sunday';
      if (s['date'] != null) _date = s['date'].toString().substring(0, 10);
      _notesCtrl.text = s['notes'] ?? '';
      _exercises = (s['exercises'] as List).map((ex) {
        return {
          'name': ex['name'],
          'category': ex['category'],
          'percentage': ex['percentage']?.toString() ?? '',
          'sets': (ex['sets'] as List).map((st) {
            return {'weight': st['weight'].toString(), 'sets': st['sets'].toString(), 'reps': st['reps'].toString()};
          }).toList(),
        };
      }).toList();
    } else {
      _exercises = [_emptyExercise('main')];
      // Auto-start timer for new sessions
      _startTimer();
    }
  }

  void _startTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          final mins = _stopwatch.elapsed.inMinutes;
          final secs = _stopwatch.elapsed.inSeconds % 60;
          _elapsed = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        });
      }
    });
  }

  void _toggleTimer() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _timer?.cancel();
    } else {
      _startTimer();
    }
    setState(() {});
  }

  Map<String, dynamic> _emptyExercise(String category) {
    return {
      'name': '',
      'category': category,
      'percentage': '',
      'sets': [{'weight': '', 'sets': '1', 'reps': ''}],
    };
  }

  Future<void> _submit() async {
    if (_blockCtrl.text.isEmpty || _day.isEmpty) {
      setState(() => _error = 'Block and day are required.');
      return;
    }

    final exercises = _exercises
        .where((ex) => (ex['name'] as String).trim().isNotEmpty)
        .map((ex) => {
              'name': (ex['name'] as String).trim(),
              'category': ex['category'],
              if ((ex['percentage'] as String).isNotEmpty)
                'percentage': int.tryParse(ex['percentage']),
              'sets': (ex['sets'] as List)
                  .where((s) => s['weight'].toString().isNotEmpty && s['reps'].toString().isNotEmpty)
                  .map((s) => {
                        'weight': num.parse(s['weight'].toString()),
                        'sets': int.tryParse(s['sets'].toString()) ?? 1,
                        'reps': int.parse(s['reps'].toString()),
                      })
                  .toList(),
            })
        .where((ex) => (ex['sets'] as List).isNotEmpty)
        .toList();

    if (exercises.isEmpty) {
      setState(() => _error = 'Add at least one exercise with sets.');
      return;
    }

    // Calculate duration from timer
    final durationMins = _stopwatch.elapsed.inMinutes;

    final payload = {
      'block': int.parse(_blockCtrl.text),
      if (_weekCtrl.text.isNotEmpty) 'week': int.parse(_weekCtrl.text),
      'day': _day,
      'date': _date,
      if (durationMins > 0) 'duration': durationMins,
      'notes': _notesCtrl.text,
      'exercises': exercises,
    };

    setState(() { _loading = true; _error = ''; });
    try {
      if (_isEditing) {
        await ApiService.updateSession(widget.existingSession!['_id'], payload);
      } else {
        await ApiService.createSession(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final errMsg = e.toString();
      if (errMsg.contains('SocketException') || errMsg.contains('ClientException') || errMsg.contains('TimeoutException') || errMsg.contains('Connection')) {
        await OfflineQueue.enqueue({
          'type': _isEditing ? 'update' : 'create',
          if (_isEditing) 'sessionId': widget.existingSession!['_id'],
          'data': payload,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved offline! Will sync when connected.'), backgroundColor: AppTheme.accentAmber, behavior: SnackBarBehavior.floating),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() => _error = errMsg.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Session' : 'Log Session'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accentRed.withValues(alpha: 0.12), AppTheme.accentAmber.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppTheme.accentRed, size: 22),
                  const SizedBox(width: 12),
                  Text(_elapsed,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace', letterSpacing: 2),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleTimer,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _stopwatch.isRunning ? AppTheme.accentRed.withValues(alpha: 0.2) : AppTheme.accentGreen.withValues(alpha: 0.2),
                        border: Border.all(color: _stopwatch.isRunning ? AppTheme.accentRed.withValues(alpha: 0.4) : AppTheme.accentGreen.withValues(alpha: 0.4)),
                      ),
                      child: Icon(
                        _stopwatch.isRunning ? Icons.pause : Icons.play_arrow,
                        color: _stopwatch.isRunning ? AppTheme.accentRed : AppTheme.accentGreen,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_error.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2)),
                ),
                child: Text(_error, style: const TextStyle(color: AppTheme.accentRed, fontSize: 13)),
              ),

            // Block, Week row
            Row(
              children: [
                Expanded(
                  child: TextField(controller: _blockCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'BLOCK #')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(controller: _weekCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'WEEK #')),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Day, Date
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _day,
                    decoration: const InputDecoration(labelText: 'DAY'),
                    dropdownColor: AppTheme.bg900,
                    items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setState(() => _day = v ?? _day),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                        firstDate: DateTime(2020), lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: InputDecoration(labelText: 'DATE', hintText: _date),
                        controller: TextEditingController(text: _date),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Exercises
            const Text('EXERCISES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text400, letterSpacing: 1)),
            const SizedBox(height: 10),
            ..._exercises.asMap().entries.map((entry) => _buildExercise(entry.key, entry.value)),

            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _addExerciseBtn('Main', 'main', AppTheme.accentRed),
                _addExerciseBtn('Secondary', 'secondary', AppTheme.accentBlue),
                _addExerciseBtn('Accessory', 'accessory', AppTheme.accentGreen),
              ],
            ),
            const SizedBox(height: 16),

            TextField(controller: _notesCtrl, maxLines: 3,
                decoration: const InputDecoration(labelText: 'NOTES', hintText: 'Optional session notes...')),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'UPDATE SESSION' : 'SAVE SESSION'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _addExerciseBtn(String label, String category, Color color) {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _exercises.add(_emptyExercise(category))),
      icon: Icon(Icons.add, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildExercise(int exIdx, Map<String, dynamic> exercise) {
    final category = exercise['category'] as String;
    final catColor = category == 'main' ? AppTheme.accentRed : category == 'secondary' ? AppTheme.accentBlue : AppTheme.accentGreen;
    final sets = exercise['sets'] as List;
    final isMain = category == 'main';
    final isSecondary = category == 'secondary';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge + remove
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: catColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(category.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: catColor, letterSpacing: 0.5)),
                ),
                const Spacer(),
                if (_exercises.length > 1)
                  IconButton(icon: const Icon(Icons.close, size: 18, color: AppTheme.text500),
                      onPressed: () => setState(() => _exercises.removeAt(exIdx)),
                      constraints: const BoxConstraints(), padding: EdgeInsets.zero),
              ],
            ),
            const SizedBox(height: 8),

            // Exercise name + %RM on same row for main lifts
            if (isMain)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _mainLifts.contains(exercise['name']) ? exercise['name'] : null,
                      decoration: const InputDecoration(labelText: 'EXERCISE', isDense: true),
                      dropdownColor: AppTheme.bg900,
                      items: _mainLifts.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) => setState(() => exercise['name'] = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '%RM', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                      controller: TextEditingController(text: exercise['percentage']),
                      onChanged: (v) => exercise['percentage'] = v,
                    ),
                  ),
                ],
              )
            else if (isSecondary)
              DropdownButtonFormField<String>(
                value: _allSecondaryLifts.contains(exercise['name']) ? exercise['name'] : null,
                decoration: const InputDecoration(labelText: 'VARIATION', isDense: true),
                dropdownColor: AppTheme.bg900, isExpanded: true,
                items: _secondaryLifts.entries.expand((mainLift) => [
                  DropdownMenuItem(enabled: false, value: '__header_${mainLift.key}',
                    child: Text('── ${mainLift.key} ──', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: catColor.withValues(alpha: 0.6)))),
                  ...mainLift.value.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))),
                ]).toList(),
                onChanged: (v) { if (v != null && !v.startsWith('__header_')) setState(() => exercise['name'] = v); },
              )
            else
              TextField(
                decoration: const InputDecoration(labelText: 'EXERCISE NAME', isDense: true),
                controller: TextEditingController(text: exercise['name'])..selection = TextSelection.collapsed(offset: (exercise['name'] as String).length),
                onChanged: (v) => exercise['name'] = v,
              ),
            const SizedBox(height: 10),

            // Sets
            const Row(children: [
              Expanded(flex: 3, child: Text('Weight', style: TextStyle(fontSize: 10, color: AppTheme.text500, fontWeight: FontWeight.w600))),
              SizedBox(width: 6),
              Expanded(flex: 2, child: Text('Sets', style: TextStyle(fontSize: 10, color: AppTheme.text500, fontWeight: FontWeight.w600))),
              SizedBox(width: 6),
              Expanded(flex: 2, child: Text('Reps', style: TextStyle(fontSize: 10, color: AppTheme.text500, fontWeight: FontWeight.w600))),
              SizedBox(width: 30),
            ]),
            const SizedBox(height: 6),
            ...sets.asMap().entries.map((sEntry) {
              final sIdx = sEntry.key;
              final set = sEntry.value as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(flex: 3, child: TextField(keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'kg', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      controller: TextEditingController(text: set['weight'].toString() == '0' ? '' : set['weight'].toString()),
                      onChanged: (v) => set['weight'] = v)),
                  const SizedBox(width: 6),
                  Expanded(flex: 2, child: TextField(keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '#', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      controller: TextEditingController(text: set['sets'].toString()),
                      onChanged: (v) => set['sets'] = v)),
                  const SizedBox(width: 6),
                  Expanded(flex: 2, child: TextField(keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '#', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      controller: TextEditingController(text: set['reps'].toString() == '0' ? '' : set['reps'].toString()),
                      onChanged: (v) => set['reps'] = v)),
                  SizedBox(width: 30, child: sets.length > 1
                      ? IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppTheme.text500),
                          onPressed: () => setState(() => sets.removeAt(sIdx)), constraints: const BoxConstraints(), padding: EdgeInsets.zero)
                      : const SizedBox()),
                ]),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => sets.add({'weight': '', 'sets': '1', 'reps': ''})),
              icon: Icon(Icons.add, size: 16, color: catColor),
              label: Text('Add Set', style: TextStyle(fontSize: 12, color: catColor)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _blockCtrl.dispose();
    _weekCtrl.dispose();
    _notesCtrl.dispose();
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
