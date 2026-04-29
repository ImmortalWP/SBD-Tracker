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

class _AddSessionScreenState extends State<AddSessionScreen> with WidgetsBindingObserver {
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
  DateTime? _lastTickTime;

  // Auto-save
  Timer? _autoSaveTimer;

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
    'Shoulders': ['OHP', 'Dumbbell Press', 'Lateral Raise', 'Rear Delt Fly', 'Front Raise'],
    'Arms': ['Barbell Curl', 'Dumbbell Curl', 'Hammer Curl', 'Tricep Pushdown', 'Skull Crusher', 'Close Grip Press', 'Overhead Extension'],
    'Legs': ['Leg Press', 'Leg Extension', 'Leg Curl', 'Bulgarian Split Squat', 'Hip Thrust'],
    'Core': ['Plank', 'Ab Wheel', 'Cable Crunch', 'Hanging Leg Raise'],
  };

  List<String> get _allAccessoryLifts => _accessoryLifts.values.expand((e) => e).toList();

  List<String> _dynamicAccessories = [];

  // Each exercise: { name, category, pctCtrl, sets: [ {wCtrl, sCtrl, rCtrl} ] }
  final List<_ExData> _exercises = [];

  bool get _isEditing => widget.existingSession != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isEditing) {
      _loadExisting();
    } else {
      _tryLoadDraft();
    }
    // Auto-save draft every 5 seconds
    if (!_isEditing) {
      _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveDraftSilent());
    }
    _fetchDynamicAccessories();
  }

  Future<void> _fetchDynamicAccessories() async {
    try {
      final sessions = await ApiService.getSessions();
      final Set<String> uniqueAccessories = {};
      for (final session in sessions) {
        final exercises = session['exercises'] as List? ?? [];
        for (final ex in exercises) {
          if (ex['category'] == 'accessory' && ex['name'] != null) {
            final name = ex['name'].toString().trim();
            if (name.isNotEmpty) {
              // Check case-insensitive
              bool exists = uniqueAccessories.any((e) => e.toLowerCase() == name.toLowerCase());
              bool inStatic = _allAccessoryLifts.any((e) => e.toLowerCase() == name.toLowerCase());
              if (!exists && !inStatic) {
                uniqueAccessories.add(name);
              }
            }
          }
        }
      }
      if (mounted && uniqueAccessories.isNotEmpty) {
        setState(() {
          _dynamicAccessories = uniqueAccessories.toList()..sort();
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_isEditing) _saveDraftSilent();
    }
  }

  void _saveDraftSilent() {
    if (_isEditing) return;
    final hasData = _blockCtrl.text.isNotEmpty || _exercises.any((e) => e.name.isNotEmpty);
    if (hasData) _saveDraft();
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
        final wasRunning = draft['timerRunning'] == true;
        final lastTickStr = draft['lastTickTime'];
        
        if (wasRunning && lastTickStr != null) {
          final lastTick = DateTime.tryParse(lastTickStr);
          if (lastTick != null) {
            _elapsedSeconds += DateTime.now().difference(lastTick).inSeconds;
          }
          _startTimer();
        } else if (wasRunning) {
          _startTimer();
        }

        final exList = draft['exercises'] as List? ?? [];
        for (final ex in exList) {
          _exercises.add(_ExData.fromMap(ex));
        }
        setState(() {});
        return;
      }
    }

    // Fresh session
    _exercises.add(_ExData.empty('main'));
    _startTimer();
  }

  Future<void> _onDayChanged(String newDay) async {
    setState(() => _day = newDay);
    if (_isEditing) return; // Don't auto-load if editing an existing session

    // Check if current session is empty
    bool isEmpty = _exercises.isEmpty || (_exercises.length == 1 && _exercises.first.name.trim().isEmpty);

    if (!isEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.bg850,
          title: Text('Load $newDay Workout?'),
          content: const Text('This will overwrite your current exercises with the most recent ones from this day.', style: TextStyle(color: AppTheme.text400)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.text500)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Load', style: TextStyle(color: AppTheme.accentGreen)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _loading = true);

    try {
      final sessions = await ApiService.getSessions(day: newDay);
      if (sessions.isNotEmpty) {
        sessions.sort((a, b) {
          final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
          final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
          return db.compareTo(da);
        });

        final mostRecent = sessions.first;
        final exList = mostRecent['exercises'] as List? ?? [];
        if (exList.isNotEmpty) {
          for (final ex in _exercises) {
            ex.dispose();
          }
          _exercises.clear();
          
          for (final ex in exList) {
            _exercises.add(_ExData.fromMap(ex));
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Loaded previous $newDay workout'),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ));
          }
        }
      }
    } catch (e) {
      // Ignore errors silently
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timerRunning = true;
    _lastTickTime = DateTime.now();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (_lastTickTime != null) {
        _elapsedSeconds += now.difference(_lastTickTime!).inSeconds;
      } else {
        _elapsedSeconds++;
      }
      _lastTickTime = now;
      if (mounted) setState(() {});
    });
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timerTick?.cancel();
      _timerRunning = false;
      _lastTickTime = null;
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
    final hasData = _blockCtrl.text.isNotEmpty || _exercises.any((e) => e.name.isNotEmpty);
    if (hasData) {
      await _saveDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('💾 Session saved as draft'),
          backgroundColor: AppTheme.accentAmber,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
    }
    return true;
  }

  Future<void> _discardDraft() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg850,
        title: const Text('Discard Session?'),
        content: const Text('All entered data will be permanently lost.', style: TextStyle(color: AppTheme.text400)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.text500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DraftService.clearDraft();
      if (mounted) Navigator.pop(context, false);
    }
  }

  Future<void> _saveDraft() async {
    await DraftService.saveDraft({
      'block': _blockCtrl.text,
      'week': _weekCtrl.text,
      'day': _day,
      'date': _date,
      'notes': _notesCtrl.text,
      'elapsedSeconds': _elapsedSeconds,
      'timerRunning': _timerRunning,
      'lastTickTime': _lastTickTime?.toIso8601String(),
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
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.text500, size: 20),
                tooltip: 'Discard session',
                onPressed: _discardDraft,
              ),
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
                if (_error.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.accentRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(_error, style: const TextStyle(color: AppTheme.accentRed, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                ],

                _buildMetaRow(),
                const SizedBox(height: 32),

                // Each exercise as its own StatefulWidget - this is the key fix
                ..._exercises.asMap().entries.map((entry) => _ExerciseCard(
                  key: ValueKey(entry.value.id),
                  data: entry.value,
                  mainLifts: _mainLifts,
                  secondaryLifts: _secondaryLifts,
                  accessoryLifts: _accessoryLifts,
                  allAccessoryLifts: _allAccessoryLifts,
                  allSecondaryLifts: _allSecondaryLifts,
                  dynamicAccessories: _dynamicAccessories,
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

  Widget _buildMetaRow() {
    String metaText = 'Block ${_blockCtrl.text.isEmpty ? '-' : _blockCtrl.text} • '
        'Week ${_weekCtrl.text.isEmpty ? '-' : _weekCtrl.text} • '
        '${_day ?? 'Day'} • $_date';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!_isEditing) ...[
          GestureDetector(
            onTap: _toggleTimer,
            child: Text(
              _timerDisplay,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _timerRunning ? AppTheme.accentGreen : AppTheme.text500,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('•', style: TextStyle(color: AppTheme.text600)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: GestureDetector(
            onTap: _showMetaEditDialog,
            child: Text(
              metaText,
              style: const TextStyle(fontSize: 14, color: AppTheme.text400, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  void _showMetaEditDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg900,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Session Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.text100)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _numField(_blockCtrl, 'Block')),
              const SizedBox(width: 10),
              Expanded(child: _numField(_weekCtrl, 'Week')),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _day,
              decoration: _deco('Day'),
              dropdownColor: AppTheme.bg850,
              style: const TextStyle(fontSize: 15, color: AppTheme.text100, fontWeight: FontWeight.w600),
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) {
                if (v != null) {
                  _onDayChanged(v);
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (picked != null) {
                  setState(() {
                    _date = DateFormat('yyyy-MM-dd').format(picked);
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(color: AppTheme.bg850, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Date', style: TextStyle(fontSize: 11, color: AppTheme.text500)),
                  const SizedBox(height: 2),
                  Text(_date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text100)),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  setState(() {});
                  Navigator.pop(ctx);
                },
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
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
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    // Final safety-net save on dispose
    if (!_isEditing) _saveDraftSilent();
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
  final List<String> dynamicAccessories;
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
    required this.dynamicAccessories,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNamePicker(),
                  if (d.category == 'main' || d.category == 'secondary') ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: TextField(
                            controller: d.pctCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontSize: 14, color: AppTheme.text400, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              hintText: '%RM',
                              hintStyle: TextStyle(fontSize: 14, color: AppTheme.text600),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const Text('%', style: TextStyle(fontSize: 14, color: AppTheme.text600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (widget.canDelete)
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: AppTheme.text600),
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
        ]),
        const SizedBox(height: 16),

        // Column headers
        const Padding(
          padding: EdgeInsets.only(left: 30),
          child: Row(children: [
            Expanded(flex: 3, child: Text('Wt (kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text500))),
            SizedBox(width: 6),
            Expanded(flex: 2, child: Text('Sets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text500))),
            SizedBox(width: 6),
            Expanded(flex: 2, child: Text('Reps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text500))),
            SizedBox(width: 32),
          ]),
        ),
        const SizedBox(height: 8),

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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Icon(Icons.add, size: 16, color: _color),
              const SizedBox(width: 8),
              Text('Add Set', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _color)),
            ]),
          ),
        ),
      ]),
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
    final isKnown = widget.allAccessoryLifts.contains(d.name) || widget.dynamicAccessories.contains(d.name);
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
              if (widget.dynamicAccessories.isNotEmpty) ...[
                const DropdownMenuItem(enabled: false, value: '__hdr_History',
                    child: Text('── Recent ──', style: TextStyle(fontSize: 11, color: AppTheme.accentGreen, fontWeight: FontWeight.w800))),
                ...widget.dynamicAccessories.map((v) => DropdownMenuItem(value: v, child: Text(v))),
              ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        // Set number
        SizedBox(
          width: 24,
          child: Center(child: Text('${idx + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text500))),
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
                  icon: const Icon(Icons.remove, size: 18, color: AppTheme.text600),
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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text100, fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 16, color: AppTheme.text700),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.bg800)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.bg800)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.text500)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
    );
  }
}
