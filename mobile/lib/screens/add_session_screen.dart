import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Form fields
  final _blockCtrl = TextEditingController();
  final _weekCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _day = 'Sunday';
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _loading = false;
  String _error = '';

  // Previous session for same day (reference)
  Map<String, dynamic>? _prevSession;
  bool _showPrev = true;

  // Timer
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timerTick;
  String _elapsed = '00:00';

  final _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final _mainLifts = ['Squat', 'Bench', 'Deadlift'];

  static const Map<String, List<String>> _secondaryLifts = {
    'Squat': ['Pause Squat', 'Box Squat', 'Tempo Squat', 'Pin Squat'],
    'Bench': ['Pause Bench', 'Close Grip Bench', 'Larsen Press', 'Pin Bench', 'Wide Grip Bench'],
    'Deadlift': ['Pause Deadlift', 'Deficit Deadlift', 'Block Pull', 'RDL'],
  };

  List<String> get _allSecondaryLifts => _secondaryLifts.values.expand((e) => e).toList();

  // Exercises: each has name, category, percentage, and sets
  // Each set has its own TextEditingControllers so keyboard doesn't dismiss
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
      _exercises = (s['exercises'] as List).map((ex) => _exFromData(ex)).toList();
    } else {
      _exercises = [_emptyExercise('main')];
      _loadPrevSession();
      _startTimer();
    }
  }

  // Load most recent session for the same day of week
  Future<void> _loadPrevSession() async {
    try {
      final sessions = await ApiService.getSessions(day: _day);
      if (sessions.isNotEmpty) {
        setState(() => _prevSession = sessions.first);
      }
    } catch (_) {}
  }

  Map<String, dynamic> _exFromData(Map<String, dynamic> ex) {
    final sets = (ex['sets'] as List).map((st) => _setControllers(
      weight: st['weight']?.toString() ?? '',
      sets: st['sets']?.toString() ?? '1',
      reps: st['reps']?.toString() ?? '',
    )).toList();
    return {
      'name': ex['name'] ?? '',
      'category': ex['category'] ?? 'main',
      'percentage': ex['percentage']?.toString() ?? '',
      'pctCtrl': TextEditingController(text: ex['percentage']?.toString() ?? ''),
      'sets': sets,
    };
  }

  Map<String, dynamic> _setControllers({String weight = '', String sets = '1', String reps = ''}) {
    return {
      'weightCtrl': TextEditingController(text: weight),
      'setsCtrl': TextEditingController(text: sets),
      'repsCtrl': TextEditingController(text: reps),
    };
  }

  Map<String, dynamic> _emptyExercise(String category) {
    return {
      'name': '',
      'category': category,
      'percentage': '',
      'pctCtrl': TextEditingController(),
      'sets': [_setControllers(sets: '3', reps: '5')],
    };
  }

  void _startTimer() {
    _stopwatch.start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final mins = _stopwatch.elapsed.inMinutes;
        final secs = _stopwatch.elapsed.inSeconds % 60;
        setState(() => _elapsed = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}');
      }
    });
  }

  void _toggleTimer() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _timerTick?.cancel();
      } else {
        _startTimer();
      }
    });
  }

  // Copy a set from previous session into current
  void _copyFromPrev(Map<String, dynamic> prevEx, int setIdx) {
    final prevSets = prevEx['sets'] as List? ?? [];
    if (setIdx >= prevSets.length) return;
    final prevSet = prevSets[setIdx];

    // Find matching exercise in current session by name
    for (final ex in _exercises) {
      if (ex['name'] == prevEx['name']) {
        final sets = ex['sets'] as List;
        if (setIdx < sets.length) {
          final s = sets[setIdx] as Map<String, dynamic>;
          s['weightCtrl'].text = prevSet['weight']?.toString() ?? '';
          s['setsCtrl'].text = prevSet['sets']?.toString() ?? '1';
          s['repsCtrl'].text = prevSet['reps']?.toString() ?? '';
        }
      }
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (_blockCtrl.text.isEmpty) {
      setState(() => _error = 'Block number is required.');
      return;
    }

    final exercises = <Map<String, dynamic>>[];
    for (final ex in _exercises) {
      final name = (ex['name'] as String).trim();
      if (name.isEmpty) continue;
      final rawSets = ex['sets'] as List;
      final sets = <Map<String, dynamic>>[];
      for (final s in rawSets) {
        final w = s['weightCtrl'].text.trim();
        final r = s['repsCtrl'].text.trim();
        final st = s['setsCtrl'].text.trim();
        if (w.isEmpty || r.isEmpty) continue;
        sets.add({
          'weight': double.tryParse(w) ?? 0,
          'reps': int.tryParse(r) ?? 0,
          'sets': int.tryParse(st) ?? 1,
        });
      }
      if (sets.isEmpty) continue;

      final pct = ex['pctCtrl'].text.trim();
      exercises.add({
        'name': name,
        'category': ex['category'],
        if (pct.isNotEmpty) 'percentage': int.tryParse(pct),
        'sets': sets,
      });
    }

    if (exercises.isEmpty) {
      setState(() => _error = 'Add at least one exercise with sets.');
      return;
    }

    final payload = <String, dynamic>{
      'block': int.tryParse(_blockCtrl.text) ?? 1,
      if (_weekCtrl.text.isNotEmpty) 'week': int.tryParse(_weekCtrl.text),
      'day': _day,
      'date': _date,
      if (_stopwatch.elapsed.inMinutes > 0) 'duration': _stopwatch.elapsed.inMinutes,
      'notes': _notesCtrl.text.trim(),
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
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('ClientException') || msg.contains('Connection') || msg.contains('TimeoutException')) {
        await OfflineQueue.enqueue({
          'type': _isEditing ? 'update' : 'create',
          if (_isEditing) 'sessionId': widget.existingSession!['_id'],
          'data': payload,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('📶 Saved offline — will sync when connected'),
            backgroundColor: AppTheme.accentAmber,
            behavior: SnackBarBehavior.floating,
          ));
          Navigator.pop(context, true);
        }
      } else {
        setState(() => _error = msg.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg950,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Session' : 'Log Session',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentRed))
                : const Text('SAVE', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timer (only for new sessions)
                  if (!_isEditing) ...[
                    _buildTimer(),
                    const SizedBox(height: 16),
                  ],

                  // Error
                  if (_error.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error, style: const TextStyle(color: AppTheme.accentRed, fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Session meta
                  _buildMeta(),
                  const SizedBox(height: 16),

                  // Previous session reference
                  if (_prevSession != null && _showPrev && !_isEditing) ...[
                    _buildPrevSessionPanel(),
                    const SizedBox(height: 16),
                  ],

                  // Exercises
                  const Text('EXERCISES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  ..._exercises.asMap().entries.map((e) => _buildExercise(e.key, e.value)),

                  // Add buttons
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _addBtn('+ Main', 'main', AppTheme.accentRed),
                    _addBtn('+ Secondary', 'secondary', AppTheme.accentBlue),
                    _addBtn('+ Accessory', 'accessory', AppTheme.accentGreen),
                  ]),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 14, color: AppTheme.text200),
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      labelStyle: const TextStyle(fontSize: 13, color: AppTheme.text500),
                      filled: true, fillColor: AppTheme.bg850,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.accentRed.withValues(alpha: 0.1), Colors.transparent]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        const Icon(Icons.timer_outlined, color: AppTheme.accentRed, size: 20),
        const SizedBox(width: 10),
        Text(_elapsed, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.text100, fontFamily: 'monospace', letterSpacing: 2)),
        const Spacer(),
        GestureDetector(
          onTap: _toggleTimer,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _stopwatch.isRunning ? AppTheme.accentRed.withValues(alpha: 0.15) : AppTheme.accentGreen.withValues(alpha: 0.15),
              border: Border.all(color: _stopwatch.isRunning ? AppTheme.accentRed.withValues(alpha: 0.3) : AppTheme.accentGreen.withValues(alpha: 0.3)),
            ),
            child: Icon(_stopwatch.isRunning ? Icons.pause : Icons.play_arrow,
                color: _stopwatch.isRunning ? AppTheme.accentRed : AppTheme.accentGreen, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildMeta() {
    return Column(children: [
      // Block + Week
      Row(children: [
        Expanded(child: _metaField(_blockCtrl, 'Block', '#')),
        const SizedBox(width: 10),
        Expanded(child: _metaField(_weekCtrl, 'Week', '#')),
      ]),
      const SizedBox(height: 10),
      // Day + Date
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _day,
            decoration: _inputDeco('Day'),
            dropdownColor: AppTheme.bg850,
            style: const TextStyle(fontSize: 15, color: AppTheme.text100, fontWeight: FontWeight.w600),
            items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) {
              setState(() => _day = v ?? _day);
              if (!_isEditing) _loadPrevSession();
            },
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(color: AppTheme.bg850, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Date', style: TextStyle(fontSize: 11, color: AppTheme.text500)),
                const SizedBox(height: 2),
                Text(_date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text100)),
              ]),
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _metaField(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text50),
      decoration: _inputDeco(label).copyWith(hintText: hint),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: AppTheme.text500),
      filled: true, fillColor: AppTheme.bg850,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  // Previous session reference panel
  Widget _buildPrevSessionPanel() {
    final prev = _prevSession!;
    final exercises = prev['exercises'] as List? ?? [];
    final block = prev['block'];
    final week = prev['week'];
    final day = prev['day'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
          child: Row(children: [
            const Icon(Icons.history, size: 16, color: AppTheme.accentAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Last $day${week != null ? ' · Week $week' : ''}${block != null ? ' · Block $block' : ''}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentAmber),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: AppTheme.text500),
              onPressed: () => setState(() => _showPrev = false),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ]),
        ),
        const Divider(height: 12, color: AppTheme.bg800),
        // Exercise list
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Column(
            children: exercises.map<Widget>((ex) {
              final sets = ex['sets'] as List? ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(ex['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text100)),
                    ),
                    if (ex['percentage'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text('${ex['percentage']}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: sets.asMap().entries.map<Widget>((entry) {
                      final s = entry.value;
                      final numSets = s['sets'] ?? 1;
                      return GestureDetector(
                        onTap: () => _copyFromPrev(ex, entry.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.bg800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.15)),
                          ),
                          child: Column(children: [
                            Text('${s['weight']} kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.text50, fontFamily: 'monospace')),
                            Text('${numSets > 1 ? '$numSets×' : ''}${s['reps']} reps', style: const TextStyle(fontSize: 11, color: AppTheme.text500)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [
            const Icon(Icons.touch_app, size: 13, color: AppTheme.text600),
            const SizedBox(width: 4),
            const Text('Tap a set to copy it into your current session', style: TextStyle(fontSize: 11, color: AppTheme.text600, fontStyle: FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }

  Widget _addBtn(String label, String category, Color color) {
    return GestureDetector(
      onTap: () => setState(() => _exercises.add(_emptyExercise(category))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }

  Widget _buildExercise(int exIdx, Map<String, dynamic> exercise) {
    final category = exercise['category'] as String;
    final catColor = category == 'main' ? AppTheme.accentRed : category == 'secondary' ? AppTheme.accentBlue : AppTheme.accentGreen;
    final isMain = category == 'main';
    final isSecondary = category == 'secondary';
    final sets = exercise['sets'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bg900,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: catColor, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Exercise header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Row(children: [
            // Name picker
            Expanded(
              child: isMain
                  ? DropdownButtonFormField<String>(
                      value: _mainLifts.contains(exercise['name']) ? exercise['name'] : null,
                      hint: Text('Choose lift', style: TextStyle(color: AppTheme.text500, fontSize: 14)),
                      isExpanded: true,
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      dropdownColor: AppTheme.bg850,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: catColor),
                      items: _mainLifts.map((l) => DropdownMenuItem(value: l, child: Text(l, style: TextStyle(color: catColor, fontWeight: FontWeight.w800)))).toList(),
                      onChanged: (v) => setState(() => exercise['name'] = v ?? ''),
                    )
                  : isSecondary
                      ? DropdownButtonFormField<String>(
                          value: _allSecondaryLifts.contains(exercise['name']) ? exercise['name'] : null,
                          hint: const Text('Choose variation', style: TextStyle(color: AppTheme.text500, fontSize: 14)),
                          isExpanded: true,
                          decoration: const InputDecoration.collapsed(hintText: ''),
                          dropdownColor: AppTheme.bg850,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: catColor),
                          items: _secondaryLifts.entries.expand((e) => [
                            DropdownMenuItem(enabled: false, value: '__${e.key}',
                                child: Text('── ${e.key} ──', style: TextStyle(fontSize: 11, color: catColor.withValues(alpha: 0.5), fontWeight: FontWeight.w800))),
                            ...e.value.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                          ]).toList(),
                          onChanged: (v) { if (v != null && !v.startsWith('__')) setState(() => exercise['name'] = v); },
                        )
                      : TextField(
                          decoration: InputDecoration.collapsed(hintText: 'Exercise name', hintStyle: TextStyle(color: AppTheme.text500)),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: catColor),
                          controller: TextEditingController(text: exercise['name'])
                            ..selection = TextSelection.collapsed(offset: (exercise['name'] as String).length),
                          onChanged: (v) => exercise['name'] = v,
                        ),
            ),
            // %RM for main lifts
            if (isMain) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: exercise['pctCtrl'] as TextEditingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: catColor),
                  decoration: InputDecoration(
                    hintText: '%RM',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.text600),
                    filled: true, fillColor: AppTheme.bg800,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            if (_exercises.length > 1)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppTheme.text600),
                onPressed: () => setState(() {
                  // Dispose controllers
                  (exercise['pctCtrl'] as TextEditingController?)?.dispose();
                  for (final s in exercise['sets'] as List) {
                    (s['weightCtrl'] as TextEditingController?)?.dispose();
                    (s['setsCtrl'] as TextEditingController?)?.dispose();
                    (s['repsCtrl'] as TextEditingController?)?.dispose();
                  }
                  _exercises.removeAt(exIdx);
                }),
                constraints: const BoxConstraints(), padding: EdgeInsets.zero,
              ),
          ]),
        ),

        // Sets table header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            SizedBox(width: 28, child: Text('Set', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.text600, letterSpacing: 0.5))),
            Expanded(flex: 3, child: Text('Weight (kg)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.text600, letterSpacing: 0.5))),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: Text('Sets', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.text600, letterSpacing: 0.5))),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: Text('Reps', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.text600, letterSpacing: 0.5))),
            const SizedBox(width: 32),
          ]),
        ),
        const SizedBox(height: 6),

        // Set rows
        ...sets.asMap().entries.map((entry) => _buildSetRow(entry.key, entry.value, sets, catColor)),

        // Add set
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
          child: GestureDetector(
            onTap: () => setState(() => sets.add(_setControllers(
              weight: sets.isEmpty ? '' : (sets.last['weightCtrl'] as TextEditingController).text,
            ))),
            child: Row(children: [
              Icon(Icons.add_circle_outline, size: 16, color: catColor),
              const SizedBox(width: 6),
              Text('Add Set', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: catColor)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildSetRow(int idx, Map<String, dynamic> set, List sets, Color catColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Row(children: [
        // Set number
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: catColor.withValues(alpha: 0.15),
          ),
          child: Center(child: Text('${idx + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: catColor))),
        ),
        const SizedBox(width: 6),
        // Weight
        Expanded(
          flex: 3,
          child: _setField(
            controller: set['weightCtrl'] as TextEditingController,
            hint: '0',
            isDecimal: true,
            catColor: catColor,
          ),
        ),
        const SizedBox(width: 6),
        // Sets count
        Expanded(
          flex: 2,
          child: _setField(
            controller: set['setsCtrl'] as TextEditingController,
            hint: '1',
            catColor: catColor,
          ),
        ),
        const SizedBox(width: 6),
        // Reps
        Expanded(
          flex: 2,
          child: _setField(
            controller: set['repsCtrl'] as TextEditingController,
            hint: '5',
            catColor: catColor,
          ),
        ),
        SizedBox(
          width: 32,
          child: sets.length > 1
              ? IconButton(
                  icon: const Icon(Icons.remove, size: 16, color: AppTheme.text600),
                  onPressed: () => setState(() {
                    (set['weightCtrl'] as TextEditingController).dispose();
                    (set['setsCtrl'] as TextEditingController).dispose();
                    (set['repsCtrl'] as TextEditingController).dispose();
                    sets.removeAt(idx);
                  }),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                )
              : const SizedBox(),
        ),
      ]),
    );
  }

  Widget _setField({
    required TextEditingController controller,
    required String hint,
    bool isDecimal = false,
    required Color catColor,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: isDecimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: catColor, fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 16, color: AppTheme.text700, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: AppTheme.bg850,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: catColor.withValues(alpha: 0.4), width: 1.5)),
      ),
    );
  }

  @override
  void dispose() {
    _blockCtrl.dispose();
    _weekCtrl.dispose();
    _notesCtrl.dispose();
    _timerTick?.cancel();
    for (final ex in _exercises) {
      (ex['pctCtrl'] as TextEditingController?)?.dispose();
      for (final s in ex['sets'] as List) {
        (s['weightCtrl'] as TextEditingController?)?.dispose();
        (s['setsCtrl'] as TextEditingController?)?.dispose();
        (s['repsCtrl'] as TextEditingController?)?.dispose();
      }
    }
    super.dispose();
  }
}
