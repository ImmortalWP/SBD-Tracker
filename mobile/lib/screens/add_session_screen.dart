import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/offline_queue.dart';
import '../services/draft_service.dart';
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
  int _elapsedSeconds = 0;
  Timer? _timerTick;
  bool _timerRunning = false;

  final _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final _mainLifts = ['Squat', 'Bench', 'Deadlift'];

  static const Map<String, List<String>> _secondaryLifts = {
    'Squat': ['Pause Squat', 'Box Squat', 'Tempo Squat', 'Pin Squat'],
    'Bench': ['Pause Bench', 'Close Grip Bench', 'Larsen Press', 'Pin Bench', 'Wide Grip Bench'],
    'Deadlift': ['Pause Deadlift', 'Deficit Deadlift', 'Block Pull', 'RDL'],
  };

  List<String> get _allSecondaryLifts => _secondaryLifts.values.expand((e) => e).toList();

  static const Map<String, List<String>> _accessoryLifts = {
    'Back': ['Barbell Row', 'Pendlay Row', 'Lat Pulldown', 'Pull Up', 'Chin Up', 'Cable Row', 'Dumbbell Row', 'T-Bar Row', 'Face Pull'],
    'Shoulders': ['OHP', 'Dumbbell Press', 'Lateral Raise', 'Rear Delt Fly', 'Front Raise', 'Arnold Press'],
    'Arms': ['Barbell Curl', 'Dumbbell Curl', 'Hammer Curl', 'Tricep Pushdown', 'Skull Crusher', 'Close Grip Press', 'Overhead Extension'],
    'Legs': ['Leg Press', 'Leg Extension', 'Leg Curl', 'Bulgarian Split Squat', 'Lunges', 'Hip Thrust', 'Calf Raise', 'Good Morning'],
    'Core': ['Plank', 'Ab Wheel', 'Cable Crunch', 'Hanging Leg Raise', 'Russian Twist'],
  };

  List<String> get _allAccessoryLifts => _accessoryLifts.values.expand((e) => e).toList();

  // Each exercise: { name, category, pctCtrl, sets: [ {wCtrl, sCtrl, rCtrl} ] }
  final List<_ExData> _exercises = [];

  bool get _isEditing => widget.existingSession != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExisting();
    } else {
      _tryLoadDraft();
    }
  }

  void _loadExisting() {
    final s = widget.existingSession!;
    _blockCtrl.text = s['block'].toString();
    if (s['week'] != null) _weekCtrl.text = s['week'].toString();
    _day = s['day'] ?? 'Sunday';
    if (s['date'] != null) _date = s['date'].toString().substring(0, 10);
    _notesCtrl.text = s['notes'] ?? '';
    for (final ex in (s['exercises'] as List)) {
      _exercises.add(_ExData.fromMap(ex));
    }
  }

  Future<void> _tryLoadDraft() async {
    final draft = await DraftService.loadDraft();
    if (draft != null && mounted) {
      final resume = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.bg850,
          title: const Text('Resume Session?'),
          content: const Text('You have an in-progress session. Resume it?', style: TextStyle(color: AppTheme.text400)),
          actions: [
            TextButton(
              onPressed: () { DraftService.clearDraft(); Navigator.pop(ctx, false); },
              child: const Text('Discard', style: TextStyle(color: AppTheme.text500)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Resume', style: TextStyle(color: AppTheme.accentGreen)),
            ),
          ],
        ),
      );

      if (resume == true && draft.isNotEmpty) {
        _blockCtrl.text = draft['block']?.toString() ?? '';
        _weekCtrl.text = draft['week']?.toString() ?? '';
        _day = draft['day'] ?? 'Sunday';
        _date = draft['date'] ?? _date;
        _notesCtrl.text = draft['notes'] ?? '';
        _elapsedSeconds = draft['elapsedSeconds'] ?? 0;
        final exList = draft['exercises'] as List? ?? [];
        for (final ex in exList) {
          _exercises.add(_ExData.fromMap(ex));
        }
        setState(() {});
        _startTimer();
        return;
      }
    }

    // Fresh session
    _exercises.add(_ExData.empty('main'));
    _startTimer();
  }

  void _startTimer() {
    _timerRunning = true;
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timerTick?.cancel();
      _timerRunning = false;
    } else {
      _startTimer();
    }
    setState(() {});
  }

  String get _timerDisplay {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Save draft when going back
  Future<bool> _onWillPop() async {
    if (_isEditing) return true;
    // Only save draft if something was entered
    final hasData = _blockCtrl.text.isNotEmpty || _exercises.any((e) => e.name.isNotEmpty);
    if (hasData) {
      await _saveDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('💾 Session saved as draft — timer keeps running'),
          backgroundColor: AppTheme.accentAmber,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
    }
    return true;
  }

  Future<void> _saveDraft() async {
    await DraftService.saveDraft({
      'block': _blockCtrl.text,
      'week': _weekCtrl.text,
      'day': _day,
      'date': _date,
      'notes': _notesCtrl.text,
      'elapsedSeconds': _elapsedSeconds,
      'exercises': _exercises.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> _submit() async {
    if (_blockCtrl.text.isEmpty) {
      setState(() => _error = 'Block number is required.');
      return;
    }

    final exercises = <Map<String, dynamic>>[];
    for (final ex in _exercises) {
      if (ex.name.trim().isEmpty) continue;
      final sets = <Map<String, dynamic>>[];
      for (final s in ex.sets) {
        final w = s.wCtrl.text.trim();
        final r = s.rCtrl.text.trim();
        final st = s.sCtrl.text.trim();
        if (w.isEmpty || r.isEmpty) continue;
        sets.add({
          'weight': double.tryParse(w) ?? 0,
          'reps': int.tryParse(r) ?? 0,
          'sets': int.tryParse(st) ?? 1,
        });
      }
      if (sets.isEmpty) continue;
      final pct = ex.pctCtrl.text.trim();
      exercises.add({
        'name': ex.name.trim(),
        'category': ex.category,
        if (pct.isNotEmpty) 'percentage': int.tryParse(pct),
        'sets': sets,
      });
    }

    if (exercises.isEmpty) {
      setState(() => _error = 'Add at least one exercise with sets.');
      return;
    }

    final durationMin = _elapsedSeconds ~/ 60;
    final payload = <String, dynamic>{
      'block': int.tryParse(_blockCtrl.text) ?? 1,
      if (_weekCtrl.text.isNotEmpty) 'week': int.tryParse(_weekCtrl.text),
      'day': _day,
      'date': _date,
      if (durationMin > 0) 'duration': durationMin,
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
      await DraftService.clearDraft();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('ClientException') || msg.contains('Connection') || msg.contains('Timeout')) {
        await OfflineQueue.enqueue({
          'type': _isEditing ? 'update' : 'create',
          if (_isEditing) 'sessionId': widget.existingSession!['_id'],
          'data': payload,
        });
        await DraftService.clearDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('📶 Saved offline — will sync when connected'),
            backgroundColor: AppTheme.accentAmber, behavior: SnackBarBehavior.floating,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg950,
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Session' : 'Log Session'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () async {
            final shouldPop = await _onWillPop();
            if (shouldPop && mounted) Navigator.pop(context);
          }),
          actions: [
            TextButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentRed))
                  : const Text('SAVE', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timer
                if (!_isEditing) _buildTimer(),
                if (!_isEditing) const SizedBox(height: 14),

                if (_error.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.accentRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(_error, style: const TextStyle(color: AppTheme.accentRed, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Meta fields
                _buildMetaFields(),
                const SizedBox(height: 16),

                const Text('EXERCISES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text500, letterSpacing: 1)),
                const SizedBox(height: 8),

                // Each exercise as its own StatefulWidget - this is the key fix
                ..._exercises.asMap().entries.map((entry) => _ExerciseCard(
                  key: ValueKey(entry.value.id),
                  data: entry.value,
                  mainLifts: _mainLifts,
                  secondaryLifts: _secondaryLifts,
                  accessoryLifts: _accessoryLifts,
                  allAccessoryLifts: _allAccessoryLifts,
                  allSecondaryLifts: _allSecondaryLifts,
                  canDelete: _exercises.length > 1,
                  onDelete: () => setState(() {
                    entry.value.dispose();
                    _exercises.removeAt(entry.key);
                  }),
                )),

                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _addBtn('+ Main', 'main', AppTheme.accentRed),
                  _addBtn('+ Secondary', 'secondary', AppTheme.accentBlue),
                  _addBtn('+ Accessory', 'accessory', AppTheme.accentGreen),
                ]),
                const SizedBox(height: 16),

                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14, color: AppTheme.text200),
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    filled: true, fillColor: AppTheme.bg850,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        Text(_timerDisplay, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.text100, fontFamily: 'monospace', letterSpacing: 2)),
        const Spacer(),
        GestureDetector(
          onTap: _toggleTimer,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _timerRunning ? AppTheme.accentRed.withValues(alpha: 0.15) : AppTheme.accentGreen.withValues(alpha: 0.15),
            ),
            child: Icon(_timerRunning ? Icons.pause : Icons.play_arrow,
                color: _timerRunning ? AppTheme.accentRed : AppTheme.accentGreen, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildMetaFields() {
    return Column(children: [
      Row(children: [
        Expanded(child: _numField(_blockCtrl, 'Block')),
        const SizedBox(width: 10),
        Expanded(child: _numField(_weekCtrl, 'Week')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _day,
            decoration: _deco('Day'),
            dropdownColor: AppTheme.bg850,
            style: const TextStyle(fontSize: 15, color: AppTheme.text100, fontWeight: FontWeight.w600),
            items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => _day = v ?? _day,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: context,
                  initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                  firstDate: DateTime(2020), lastDate: DateTime(2030));
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

  Widget _numField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text50),
      decoration: _deco(label),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12, color: AppTheme.text500),
    filled: true, fillColor: AppTheme.bg850,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  Widget _addBtn(String label, String category, Color color) {
    return GestureDetector(
      onTap: () => setState(() => _exercises.add(_ExData.empty(category))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
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
      ex.dispose();
    }
    super.dispose();
  }
}

// ────────────────────────────────────────
// Exercise data model with unique ID
// ────────────────────────────────────────
class _ExData {
  final String id;
  String name;
  String category;
  final TextEditingController pctCtrl;
  final List<_SetData> sets;

  _ExData({required this.id, required this.name, required this.category, required this.pctCtrl, required this.sets});

  factory _ExData.empty(String category) => _ExData(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    name: '', category: category,
    pctCtrl: TextEditingController(),
    sets: [_SetData.empty()],
  );

  factory _ExData.fromMap(Map<String, dynamic> m) {
    final sets = (m['sets'] as List? ?? []).map((s) => _SetData(
      wCtrl: TextEditingController(text: (s['weight'] ?? '').toString()),
      sCtrl: TextEditingController(text: (s['sets'] ?? '1').toString()),
      rCtrl: TextEditingController(text: (s['reps'] ?? '').toString()),
    )).toList();
    if (sets.isEmpty) sets.add(_SetData.empty());
    return _ExData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: m['name'] ?? '',
      category: m['category'] ?? 'main',
      pctCtrl: TextEditingController(text: (m['percentage'] ?? '').toString()),
      sets: sets,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'percentage': pctCtrl.text,
    'sets': sets.map((s) => {
      'weight': s.wCtrl.text,
      'sets': s.sCtrl.text,
      'reps': s.rCtrl.text,
    }).toList(),
  };

  void dispose() {
    pctCtrl.dispose();
    for (final s in sets) s.dispose();
  }
}

class _SetData {
  final TextEditingController wCtrl;
  final TextEditingController sCtrl;
  final TextEditingController rCtrl;

  _SetData({required this.wCtrl, required this.sCtrl, required this.rCtrl});

  factory _SetData.empty() => _SetData(
    wCtrl: TextEditingController(),
    sCtrl: TextEditingController(text: '3'),
    rCtrl: TextEditingController(text: '5'),
  );

  void dispose() { wCtrl.dispose(); sCtrl.dispose(); rCtrl.dispose(); }
}

// ────────────────────────────────────────
// SEPARATE StatefulWidget for each exercise card
// This is the KEY fix: setState within this widget
// does NOT rebuild sibling exercise cards or their TextFields
// ────────────────────────────────────────
class _ExerciseCard extends StatefulWidget {
  final _ExData data;
  final List<String> mainLifts;
  final Map<String, List<String>> secondaryLifts;
  final List<String> allSecondaryLifts;
  final Map<String, List<String>> accessoryLifts;
  final List<String> allAccessoryLifts;
  final bool canDelete;
  final VoidCallback onDelete;

  const _ExerciseCard({
    super.key,
    required this.data,
    required this.mainLifts,
    required this.secondaryLifts,
    required this.allSecondaryLifts,
    required this.accessoryLifts,
    required this.allAccessoryLifts,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  _ExData get d => widget.data;

  Color get _color {
    switch (d.category) {
      case 'main': return AppTheme.accentRed;
      case 'secondary': return AppTheme.accentBlue;
      default: return AppTheme.accentGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bg900,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _color, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header: exercise picker + %RM + delete
          Row(children: [
            Expanded(child: _buildNamePicker()),
            if (d.category == 'main') ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: d.pctCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _color),
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
            if (widget.canDelete)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppTheme.text600),
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
          ]),
          const SizedBox(height: 10),

          // Column headers
          const Padding(
            padding: EdgeInsets.only(left: 30),
            child: Row(children: [
              Expanded(flex: 3, child: Text('Wt (kg)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.text600))),
              SizedBox(width: 6),
              Expanded(flex: 2, child: Text('Sets', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.text600))),
              SizedBox(width: 6),
              Expanded(flex: 2, child: Text('Reps', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.text600))),
              SizedBox(width: 32),
            ]),
          ),
          const SizedBox(height: 4),

          // Set rows
          ...d.sets.asMap().entries.map((e) => _buildSetRow(e.key, e.value)),

          // Add set
          GestureDetector(
            onTap: () {
              final lastW = d.sets.isNotEmpty ? d.sets.last.wCtrl.text : '';
              setState(() => d.sets.add(_SetData(
                wCtrl: TextEditingController(text: lastW),
                sCtrl: TextEditingController(text: '1'),
                rCtrl: TextEditingController(),
              )));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(Icons.add_circle_outline, size: 16, color: _color),
                const SizedBox(width: 6),
                Text('Add Set', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _color)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNamePicker() {
    if (d.category == 'main') {
      return DropdownButtonFormField<String>(
        value: widget.mainLifts.contains(d.name) ? d.name : null,
        hint: const Text('Select lift', style: TextStyle(color: AppTheme.text500, fontSize: 14)),
        isExpanded: true,
        decoration: const InputDecoration.collapsed(hintText: ''),
        dropdownColor: AppTheme.bg850,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _color),
        items: widget.mainLifts.map((l) => DropdownMenuItem(value: l,
            child: Text(l, style: TextStyle(color: _color, fontWeight: FontWeight.w800)))).toList(),
        onChanged: (v) => setState(() => d.name = v ?? ''),
      );
    }
    if (d.category == 'secondary') {
      return DropdownButtonFormField<String>(
        value: widget.allSecondaryLifts.contains(d.name) ? d.name : null,
        hint: const Text('Select variation', style: TextStyle(color: AppTheme.text500, fontSize: 14)),
        isExpanded: true,
        decoration: const InputDecoration.collapsed(hintText: ''),
        dropdownColor: AppTheme.bg850,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _color),
        items: widget.secondaryLifts.entries.expand((e) => [
          DropdownMenuItem(enabled: false, value: '__${e.key}',
              child: Text('── ${e.key} ──', style: TextStyle(fontSize: 11, color: _color.withValues(alpha: 0.5), fontWeight: FontWeight.w800))),
          ...e.value.map((v) => DropdownMenuItem(value: v, child: Text(v))),
        ]).toList(),
        onChanged: (v) { if (v != null && !v.startsWith('__')) setState(() => d.name = v); },
      );
    }
    // Accessory: grouped dropdown with custom option
    final isKnown = widget.allAccessoryLifts.contains(d.name);
    final isCustom = d.name.isNotEmpty && !isKnown && d.name != '__custom__';
    return isCustom
        ? Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration.collapsed(hintText: 'Exercise name', hintStyle: TextStyle(color: AppTheme.text500)),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _color),
                controller: TextEditingController(text: d.name)..selection = TextSelection.collapsed(offset: d.name.length),
                onChanged: (v) => d.name = v,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.list, size: 18, color: AppTheme.text500),
              onPressed: () => setState(() => d.name = ''),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              tooltip: 'Switch to dropdown',
            ),
          ])
        : DropdownButtonFormField<String>(
            value: isKnown ? d.name : null,
            hint: const Text('Select exercise', style: TextStyle(color: AppTheme.text500, fontSize: 14)),
            isExpanded: true,
            decoration: const InputDecoration.collapsed(hintText: ''),
            dropdownColor: AppTheme.bg850,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _color),
            items: [
              ...widget.accessoryLifts.entries.expand((e) => [
                DropdownMenuItem(enabled: false, value: '__hdr_${e.key}',
                    child: Text('── ${e.key} ──', style: TextStyle(fontSize: 11, color: _color.withValues(alpha: 0.5), fontWeight: FontWeight.w800))),
                ...e.value.map((v) => DropdownMenuItem(value: v, child: Text(v))),
              ]),
              const DropdownMenuItem(value: '__custom__',
                  child: Text('✏️  Type custom...', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic))),
            ],
            onChanged: (v) {
              if (v == '__custom__') {
                setState(() => d.name = ' ');  // trigger text field mode
              } else if (v != null && !v.startsWith('__')) {
                setState(() => d.name = v);
              }
            },
          );
  }

  Widget _buildSetRow(int idx, _SetData s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        // Set number
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _color.withValues(alpha: 0.15)),
          child: Center(child: Text('${idx + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _color))),
        ),
        const SizedBox(width: 6),
        Expanded(flex: 3, child: _inputField(s.wCtrl, '0', decimal: true)),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _inputField(s.sCtrl, '3')),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _inputField(s.rCtrl, '5')),
        SizedBox(
          width: 32,
          child: d.sets.length > 1
              ? IconButton(
                  icon: const Icon(Icons.remove, size: 16, color: AppTheme.text600),
                  onPressed: () => setState(() { s.dispose(); d.sets.removeAt(idx); }),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                )
              : const SizedBox(),
        ),
      ]),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, {bool decimal = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
      inputFormatters: decimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _color, fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 16, color: AppTheme.text700),
        filled: true, fillColor: AppTheme.bg850,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _color.withValues(alpha: 0.4), width: 1.5),
        ),
      ),
    );
  }
}
