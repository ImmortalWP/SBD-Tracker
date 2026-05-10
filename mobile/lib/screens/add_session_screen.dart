import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/offline_queue.dart';
import '../services/draft_service.dart';
import '../services/analytics_processor.dart';
import '../theme/app_colors.dart';
import '../widgets/pr_celebration_modal.dart';
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

  String _day = 'Monday';
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _loading = false;
  String _error = '';

  int _accumulatedSeconds = 0;
  DateTime? _timerStartTime;
  Timer? _timerTick;
  bool _timerRunning = false;

  Timer? _autoSaveTimer;
  List<dynamic> _allSessionsCache = [];
  Map<String, List<Map<String, dynamic>>> _exerciseHistoryIndex = {};
  Timer? _debounceTimer;
  bool _isDirty = false;
  static int _idCounter = 0;

  final _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final _mainLifts = ['Squat', 'Bench', 'Deadlift'];

  static const Map<String, List<String>> _secondaryLifts = {
    'Squat': ['Pause Squat', 'Box Squat', 'Tempo Squat', 'Pin Squat'],
    'Bench': ['Pause Bench', 'Close Grip Bench', 'Larsen Press', 'Pin Bench', 'Wide Grip Bench'],
    'Deadlift': ['Pause Deadlift', 'Deficit Deadlift', 'Block Pull', 'RDL'],
  };

  List<String> get _allSecondaryLifts => _secondaryLifts.values.expand((e) => e).toList();

  static const Map<String, List<String>> _accessoryLifts = {
    'Back': ['Barbell Row', 'Pendlay Row', 'Lat Pulldown', 'Pull Up', 'Chin Up', 'Cable Row', 'Dumbbell Row', 'T-Bar Row', 'Face Pull', 'Chest Supported Row'],
    'Shoulders': ['OHP', 'Dumbbell Press', 'Lateral Raise', 'Rear Delt Fly', 'Front Raise', 'Overhead Press'],
    'Arms': ['Barbell Curl', 'Dumbbell Curl', 'Hammer Curl', 'Tricep Pushdown', 'Skull Crusher', 'Close Grip Press', 'Overhead Extension', 'Bicep Curl'],
    'Legs': ['Leg Press', 'Leg Extension', 'Leg Curl', 'Hamstring Curl', 'Bulgarian Split Squat', 'Hip Thrust', 'Romanian Deadlift'],
    'Core': ['Plank', 'Ab Wheel', 'Cable Crunch', 'Hanging Leg Raise'],
    'Chest': ['Incline Bench Press', 'Close Grip Bench Press', 'Cable Fly'],
  };

  List<String> get _allAccessoryLifts => _accessoryLifts.values.expand((e) => e).toList();

  List<String> _dynamicAccessories = [];
  bool _isDiscarding = false;

  final List<_ExData> _exercises = [];

  bool get _isEditing => widget.existingSession != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllSessions();
    if (_isEditing) {
      _loadExisting();
    } else {
      _tryLoadDraft();
    }
    if (!_isEditing) {
      _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveDraftSilent());
    }
    _fetchDynamicAccessories();
  }

  Future<void> _loadAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache_dashboard');
      if (cached != null) {
        final data = jsonDecode(cached);
        _allSessionsCache = data['sessions'] ?? [];
        _buildExerciseHistoryIndex();
      }
    } catch (_) {}
  }

  /// Build a lookup index: exerciseName(lowercase) -> list of past sets
  void _buildExerciseHistoryIndex() {
    _exerciseHistoryIndex.clear();
    for (final session in _allSessionsCache) {
      final exercises = session['exercises'] as List? ?? [];
      for (final ex in exercises) {
        final name = (ex['name']?.toString() ?? '').toLowerCase().trim();
        if (name.isEmpty) continue;
        final sets = ex['sets'] as List? ?? [];
        if (sets.isNotEmpty && !_exerciseHistoryIndex.containsKey(name)) {
          _exerciseHistoryIndex[name] = List<Map<String, dynamic>>.from(sets);
        }
      }
    }
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

  void _tryLoadPreviousSessionForDay(String day) {
    if (_isEditing) return; // Don't auto-load if we are explicitly editing an old session
    if (_allSessionsCache.isEmpty) return;

    final pastSessions = _allSessionsCache.where((s) => s['day'] == day).toList();
    if (pastSessions.isEmpty) return;

    // Get the most recent one (they are sorted descending by date from the API)
    final lastSession = pastSessions.first;
    final pastExercises = lastSession['exercises'] as List? ?? [];
    if (pastExercises.isEmpty) return;

    setState(() {
      _exercises.clear();
      for (final ex in pastExercises) {
        _exercises.add(_ExData.fromMap(ex as Map<String, dynamic>));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Loaded from last $day'),
      backgroundColor: AppColors.accentBlueBg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isEditing) _saveDraftSilent();
    }
  }

  void _saveDraftSilent() {
    if (_isEditing || _isDiscarding || !_isDirty) return;
    final hasData = _exercises.any((e) => e.name.isNotEmpty);
    if (hasData) {
      _saveDraft();
      _isDirty = false;
    } else {
      DraftService.clearDraft();
    }
  }

  void _loadExisting() {
    final s = widget.existingSession!;
    _blockCtrl.text = s['block'].toString();
    if (s['week'] != null) _weekCtrl.text = s['week'].toString();
    _day = s['day'] ?? 'Mon';
    if (s['date'] != null) {
      final dt = DateTime.tryParse(s['date'].toString());
      if (dt != null) _date = DateFormat('yyyy-MM-dd').format(dt);
    }
    _notesCtrl.text = s['note'] ?? s['notes'] ?? '';
    
    final exList = s['exercises'] as List? ?? [];
    for (final ex in exList) {
      _exercises.add(_ExData.fromMap(ex as Map<String, dynamic>));
    }
  }

  void _addExercise() {
    setState(() {
      _exercises.add(_ExData.empty('SBD'));
      _isDirty = true;
    });
  }

  Future<void> _tryLoadDraft() async {
    final draft = await DraftService.loadDraft();
    if (draft != null && mounted) {
      if (draft.isNotEmpty) {
        _blockCtrl.text = draft['block']?.toString() ?? '1';
        _weekCtrl.text = draft['week']?.toString() ?? '1';
        _day = draft['day'] ?? 'Monday';
        _date = draft['date'] ?? _date;
        _notesCtrl.text = draft['notes'] ?? '';
        
        _accumulatedSeconds = draft['accumulatedSeconds'] ?? 0;
        _timerRunning = draft['timerRunning'] == true;
        final startTimeStr = draft['timerStartTime'];
        
        if (_timerRunning && startTimeStr != null) {
          _timerStartTime = DateTime.tryParse(startTimeStr);
        } else {
          _timerStartTime = null;
        }

        if (draft.containsKey('elapsedSeconds') && !draft.containsKey('accumulatedSeconds')) {
           _accumulatedSeconds = draft['elapsedSeconds'];
           final lastTickStr = draft['lastTickTime'];
           if (_timerRunning && lastTickStr != null) {
              _timerStartTime = DateTime.tryParse(lastTickStr);
           }
        }

        if (_timerRunning) {
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
    _blockCtrl.text = '1';
    _weekCtrl.text = '1';
    _exercises.add(_ExData.empty('main'));
    _startTimer();
  }

  void _loadExerciseHistory(_ExData ex, String newName) {
    if (newName.trim().isEmpty) {
      ex.pastSets = null;
      if (mounted) setState((){});
      return;
    }

    // O(1) lookup via pre-built index
    final sets = _exerciseHistoryIndex[newName.toLowerCase()];
    if (sets != null && sets.isNotEmpty) {
      ex.pastSets = sets;
      for (final s in ex.sets) s.dispose();
      ex.sets.clear();
      for (final s in sets) {
        final w = (s['weight'] ?? '').toString().replaceAll('.0','');
        final r = (s['reps'] ?? '').toString();
        final c = int.tryParse(s['sets']?.toString() ?? '1') ?? 1;
        for (int i=0; i<c; i++) {
          ex.sets.add(_SetData(
            wCtrl: TextEditingController(text: w),
            sCtrl: TextEditingController(text: '1'),
            rCtrl: TextEditingController(text: r),
          ));
        }
      }
      if (mounted) setState((){});
      return;
    }
    ex.pastSets = null;
    if (mounted) setState((){});
  }

  void _startTimer() {
    _timerRunning = true;
    _timerStartTime ??= DateTime.now();
    _timerTick?.cancel();
    // No setState here - timer display is isolated in _TimerDisplay widget
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {});
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timerTick?.cancel();
      _timerRunning = false;
      if (_timerStartTime != null) {
        _accumulatedSeconds += DateTime.now().difference(_timerStartTime!).inSeconds;
      }
      _timerStartTime = null;
    } else {
      _startTimer();
    }
    if (!_isEditing) _saveDraftSilent();
    setState(() {});
  }

  int get _currentElapsedSeconds {
    if (!_timerRunning || _timerStartTime == null) return _accumulatedSeconds;
    return _accumulatedSeconds + DateTime.now().difference(_timerStartTime!).inSeconds;
  }

  String get _timerDisplay {
    final seconds = _currentElapsedSeconds;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<bool> _onWillPop() async {
    if (_isEditing || _isDiscarding) return true;
    final hasData = _exercises.any((e) => e.name.isNotEmpty);
    _autoSaveTimer?.cancel();
    if (hasData) {
      await _saveDraft();
    } else {
      await DraftService.clearDraft();
    }
    return true;
  }

  Future<void> _discardDraft() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Discard Session?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('All entered data will be lost.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard', style: TextStyle(color: Color(0xFFD95A5A)))),
        ],
      ),
    );
    if (ok == true) {
      _isDiscarding = true;
      _autoSaveTimer?.cancel();
      await DraftService.clearDraft();
      if (mounted) Navigator.pop(context, false);
    }
  }

  Future<void> _saveDraft() async {
    if (_isDiscarding) return;
    await DraftService.saveDraft({
      'block': _blockCtrl.text,
      'week': _weekCtrl.text,
      'day': _day,
      'date': _date,
      'notes': _notesCtrl.text,
      'accumulatedSeconds': _accumulatedSeconds,
      'timerRunning': _timerRunning,
      'timerStartTime': _timerStartTime?.toIso8601String(),
      'exercises': _exercises.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> _submit() async {
    if (_loading) return; // Prevent duplicate submissions

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
        if (w.isEmpty || r.isEmpty) continue;
        sets.add({
          'weight': double.tryParse(w) ?? 0,
          'reps': int.tryParse(r) ?? 0,
          'sets': int.tryParse(s.sCtrl.text.trim()) ?? 1,
        });
      }
      if (sets.isEmpty) continue;
      final pct = ex.pctCtrl.text.trim();
      final note = ex.noteCtrl.text.trim();
      exercises.add({
        'name': ex.name.trim(),
        'category': ex.category,
        if (pct.isNotEmpty) 'percentage': int.tryParse(pct),
        if (note.isNotEmpty) 'note': note,
        'sets': sets,
      });
    }

    if (exercises.isEmpty) {
      setState(() => _error = 'Add at least one exercise with sets.');
      return;
    }

    final durationMin = _currentElapsedSeconds ~/ 60;
    
    int intensity = 0;
    for (final ex in exercises) {
      if (ex['percentage'] != null) {
        final p = ex['percentage'] as int;
        if (p > intensity) intensity = p;
      }
    }

    final payload = <String, dynamic>{
      'block': int.tryParse(_blockCtrl.text) ?? 1,
      if (_weekCtrl.text.isNotEmpty) 'week': int.tryParse(_weekCtrl.text),
      'day': _day,
      'date': _date,
      if (durationMin > 0) 'durationInMinutes': durationMin,
      'note': _notesCtrl.text.trim(),
      if (intensity > 0) 'intensity': intensity,
      'exercises': exercises,
    };

    setState(() { _loading = true; _error = ''; });

    try {
      if (_isEditing) {
        await ApiService.updateSession(widget.existingSession!['_id'], payload);
      } else {
        await ApiService.createSession(payload);
      }
      _isDiscarding = true;
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
        _isDiscarding = true;
        await DraftService.clearDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Saved offline'),
            backgroundColor: AppColors.cardBg, behavior: SnackBarBehavior.floating,
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
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          title: Text(_isEditing ? 'Edit Session' : 'Log Session', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20), onPressed: () async {
            final shouldPop = await _onWillPop();
            if (shouldPop && mounted) Navigator.pop(context);
          }),
          actions: [
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                onPressed: _discardDraft,
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            buildDefaultDragHandles: false,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error.isNotEmpty) ...[
                  Text(_error, style: const TextStyle(color: Color(0xFFD95A5A), fontSize: 13)),
                  const SizedBox(height: 16),
                ],
                _buildTopMetadata(),
              ],
            ),
            footer: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _addCardBtn('Main Lift', 'main', Icons.fitness_center)),
                    const SizedBox(width: 12),
                    Expanded(child: _addCardBtn('Secondary', 'secondary', Icons.bolt)),
                    const SizedBox(width: 12),
                    Expanded(child: _addCardBtn('Accessory', 'accessory', Icons.add_circle_outline)),
                  ]
                ),
                const SizedBox(height: 32),
              ],
            ),
            itemCount: _exercises.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _exercises.removeAt(oldIndex);
                _exercises.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final ex = _exercises[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(ex.id),
                index: index,
                child: _ExerciseCard(
                  index: index,
                  data: ex,
                  mainLifts: _mainLifts,
                  secondaryLifts: _secondaryLifts,
                  accessoryLifts: _accessoryLifts,
                  allAccessoryLifts: _allAccessoryLifts,
                  allSecondaryLifts: _allSecondaryLifts,
                  dynamicAccessories: _dynamicAccessories,
                  canDelete: _exercises.length > 1,
                  onDelete: () => setState(() {
                    ex.dispose();
                    _exercises.removeAt(index);
                  }),
                  onExerciseChanged: (name) => _loadExerciseHistory(ex, name),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopMetadata() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildOutlinedDropdown(Icons.calendar_today, _day, _showMetaEditDialog)),
              const SizedBox(width: 8),
              Expanded(child: _buildOutlinedDropdown(Icons.grid_view, 'Block ${_blockCtrl.text}', _showMetaEditDialog)),
              const SizedBox(width: 8),
              Expanded(child: _buildOutlinedDropdown(Icons.show_chart, 'Week ${_weekCtrl.text}', _showMetaEditDialog)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('E, d MMM yyyy').format(DateTime.tryParse(_date) ?? DateTime.now()), 
                   style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.accentBlueBg, borderRadius: BorderRadius.circular(6)),
                child: Text('${_exercises.isNotEmpty && _exercises.first.name.isNotEmpty ? _exercises.first.name : 'Workout'} Day', 
                            style: const TextStyle(color: AppColors.accentBlue, fontSize: 12, fontWeight: FontWeight.w600)),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildOutlinedDropdown(IconData icon, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          border: Border.all(color: AppColors.borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _toggleTimer,
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.textSecondary, size: 24),
                    const SizedBox(width: 12),
                    _IsolatedTimerDisplay(
                      isRunning: _timerRunning,
                      startTime: _timerStartTime,
                      accumulatedSeconds: _accumulatedSeconds,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, color: AppColors.textSecondary, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Exercises', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text('${_exercises.length}', style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              child: _loading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Finish Session', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMetaEditDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Session Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _numField(_blockCtrl, 'Block')),
              const SizedBox(width: 12),
              Expanded(child: _numField(_weekCtrl, 'Week')),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _day,
              decoration: _deco('Day'),
              dropdownColor: AppColors.cardBg,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _day = v);
                  _tryLoadPreviousSessionForDay(v);
                }
              },
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: AppColors.accentBlue, surface: AppColors.bg)
                      ),
                      child: child!,
                    ));
                if (picked != null) {
                  setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Date', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(_date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () {
                  setState(() {});
                  Navigator.pop(ctx);
                },
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      decoration: _deco(label),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
    filled: true, fillColor: AppColors.inputBg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderColor)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderColor)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentBlue)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  Widget _addCardBtn(String label, String category, IconData icon) {
    return GestureDetector(
      onTap: () => setState(() => _exercises.add(_ExData.empty(category))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accentBlue, size: 24),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _debounceTimer?.cancel();
    if (!_isEditing) {
      _isDirty = true; // Force final save
      _saveDraftSilent();
    }
    _blockCtrl.dispose();
    _weekCtrl.dispose();
    _notesCtrl.dispose();
    _timerTick?.cancel();
    for (final ex in _exercises) ex.dispose();
    super.dispose();
  }
}

class _ExData {
  final String id;
  String name;
  String category;
  List<Map<String, dynamic>>? pastSets;
  final TextEditingController pctCtrl;
  final TextEditingController noteCtrl;
  final List<_SetData> sets;

  _ExData({required this.id, required this.name, required this.category, required this.pctCtrl, required this.noteCtrl, required this.sets, this.pastSets});

  factory _ExData.empty(String category) => _ExData(
    id: 'ex_${_AddSessionScreenState._idCounter++}_${DateTime.now().millisecondsSinceEpoch}',
    name: '', category: category,
    pctCtrl: TextEditingController(),
    noteCtrl: TextEditingController(),
    sets: [_SetData.empty()],
  );

  factory _ExData.fromMap(Map<String, dynamic> m) {
    final sets = <_SetData>[];
    for (var s in (m['sets'] as List? ?? [])) {
      int count = int.tryParse(s['sets']?.toString() ?? '1') ?? 1;
      for (int i = 0; i < count; i++) {
        sets.add(_SetData(
          wCtrl: TextEditingController(text: (s['weight'] ?? '').toString()),
          sCtrl: TextEditingController(text: '1'),
          rCtrl: TextEditingController(text: (s['reps'] ?? '').toString()),
        ));
      }
    }
    if (sets.isEmpty) sets.add(_SetData.empty());
    return _ExData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: m['name'] ?? '',
      category: m['category'] ?? 'main',
      pctCtrl: TextEditingController(text: (m['percentage'] ?? '').toString()),
      noteCtrl: TextEditingController(text: (m['note'] ?? '').toString()),
      sets: sets,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'percentage': pctCtrl.text,
    'note': noteCtrl.text,
    'sets': sets.map((s) => {
      'weight': s.wCtrl.text,
      'sets': s.sCtrl.text,
      'reps': s.rCtrl.text,
    }).toList(),
  };

  void dispose() {
    pctCtrl.dispose();
    noteCtrl.dispose();
    for (final s in sets) s.dispose();
  }
}

class _SetData {
  final TextEditingController wCtrl;
  final TextEditingController sCtrl;
  final TextEditingController rCtrl;
  bool isCompleted;

  _SetData({required this.wCtrl, required this.sCtrl, required this.rCtrl, this.isCompleted = false});

  factory _SetData.empty() => _SetData(
    wCtrl: TextEditingController(),
    sCtrl: TextEditingController(text: '1'),
    rCtrl: TextEditingController(),
  );

  void dispose() { wCtrl.dispose(); sCtrl.dispose(); rCtrl.dispose(); }
}

class _HistorySummary extends StatefulWidget {
  final List<Map<String, dynamic>> pastSets;
  const _HistorySummary({required this.pastSets});

  @override
  State<_HistorySummary> createState() => _HistorySummaryState();
}

class _HistorySummaryState extends State<_HistorySummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.pastSets.isEmpty) return const SizedBox();

    double maxW = 0;
    int maxR = 0;
    int totalSets = 0;

    for (final s in widget.pastSets) {
      final w = double.tryParse(s['weight']?.toString() ?? '0') ?? 0;
      final r = int.tryParse(s['reps']?.toString() ?? '0') ?? 0;
      final c = int.tryParse(s['sets']?.toString() ?? '1') ?? 1;
      totalSets += c;
      if (w > maxW) {
        maxW = w;
        maxR = r;
      }
    }

    final wStr = maxW.toString().replaceAll('.0', '');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LAST SESSION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('$wStr × $maxR', style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Text('($totalSets sets)', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.borderColor), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      const Text('View all', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 4),
                      Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.pastSets.map((s) {
                final w = s['weight']?.toString().replaceAll('.0', '') ?? '0';
                final r = s['reps']?.toString() ?? '0';
                final c = int.tryParse(s['sets']?.toString() ?? '1') ?? 1;
                if (c > 1) return Text('$c × ${w}kg × $r', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'monospace'));
                return Text('${w}kg × $r', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'monospace'));
              }).toList(),
            ),
          ),
        ],
        const Divider(height: 1, color: AppColors.borderColor),
      ],
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final int index;
  final _ExData data;
  final List<String> mainLifts;
  final Map<String, List<String>> secondaryLifts;
  final List<String> allSecondaryLifts;
  final Map<String, List<String>> accessoryLifts;
  final List<String> allAccessoryLifts;
  final List<String> dynamicAccessories;
  final bool canDelete;
  final VoidCallback onDelete;
  final Function(String) onExerciseChanged;
  Timer? debounceTimer;

  _ExerciseCard({
    super.key,
    required this.index,
    required this.data,
    required this.mainLifts,
    required this.secondaryLifts,
    required this.allSecondaryLifts,
    required this.accessoryLifts,
    required this.allAccessoryLifts,
    required this.dynamicAccessories,
    required this.canDelete,
    required this.onDelete,
    required this.onExerciseChanged,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  _ExData get d => widget.data;

  @override
  void dispose() {
    widget.debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accentBlue)),
                  child: Center(child: Text('${widget.index + 1}', style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.w600, fontSize: 13))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildNamePicker(context)),
              const SizedBox(width: 12),
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(color: AppColors.accentBlueBg, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: d.pctCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: AppColors.accentBlue, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: '-',
                          hintStyle: TextStyle(fontSize: 14, color: AppColors.accentBlue),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const Text('%', style: TextStyle(fontSize: 12, color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (widget.canDelete) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  color: AppColors.cardBg,
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                  onSelected: (value) {
                    if (value == 'delete') widget.onDelete();
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete Exercise', style: TextStyle(color: Color(0xFFD95A5A))),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
        
        const Divider(height: 1, color: AppColors.borderColor),

        if (d.pastSets != null && d.pastSets!.isNotEmpty)
           _HistorySummary(pastSets: d.pastSets!),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('LOG SETS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(flex: 1, child: Center(child: Text('SETS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)))),
            SizedBox(width: 8),
            Expanded(flex: 2, child: Center(child: Text('WEIGHT (KG)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)))),
            SizedBox(width: 8),
            Expanded(flex: 2, child: Center(child: Text('REPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)))),
            SizedBox(width: 8),
            SizedBox(width: 44, child: Center(child: Icon(Icons.check, size: 14, color: AppColors.textMuted))),
            SizedBox(width: 40),
          ]),
        ),
        const SizedBox(height: 8),

        ...d.sets.asMap().entries.map((e) => _buildSetRow(e.key, e.value, d)),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GestureDetector(
            onTap: () {
              final lastW = d.sets.isNotEmpty ? d.sets.last.wCtrl.text : '';
              final lastR = d.sets.isNotEmpty ? d.sets.last.rCtrl.text : '';
              setState(() => d.sets.add(_SetData(
                wCtrl: TextEditingController(text: lastW),
                sCtrl: TextEditingController(text: '1'),
                rCtrl: TextEditingController(text: lastR),
              )));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                border: Border.all(color: AppColors.accentBlueBg),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 16, color: AppColors.accentBlue),
                  SizedBox(width: 4),
                  Text('Add Set', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentBlue)),
                ],
              ),
            ),
          ),
        ),

        if (d.category == 'main' || d.category == 'secondary')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: d.noteCtrl,
              maxLines: null,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Add a note for this lift...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentBlue)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildNamePicker(BuildContext context) {
    List<String> options = [];
    if (d.category == 'main') {
      options = widget.mainLifts;
    } else if (d.category == 'secondary') {
      options = widget.allSecondaryLifts;
    } else {
      options = [...widget.allAccessoryLifts, ...widget.dynamicAccessories].toSet().toList();
    }
    
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: d.name),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return options;
        return options.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) {
        setState(() => d.name = selection);
        widget.onExerciseChanged(selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
         return TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            decoration: const InputDecoration(
               hintText: 'Exercise name...',
               hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.normal),
               border: InputBorder.none,
               isDense: true,
               contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
               d.name = v;
               widget.debounceTimer?.cancel();
               widget.debounceTimer = Timer(const Duration(milliseconds: 300), () {
                 widget.onExerciseChanged(v);
               });
            },
         );
      },
      optionsViewBuilder: (context, onSelected, optionsView) {
         return Align(
            alignment: Alignment.topLeft,
            child: Material(
               elevation: 4,
               color: AppColors.inputBg,
               borderRadius: BorderRadius.circular(8),
               child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 96),
                  child: ListView.builder(
                     padding: EdgeInsets.zero,
                     shrinkWrap: true,
                     itemCount: optionsView.length,
                     itemBuilder: (BuildContext context, int index) {
                        final String option = optionsView.elementAt(index);
                        return InkWell(
                           onTap: () => onSelected(option),
                           child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Text(option, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                           ),
                        );
                     },
                  ),
               ),
            ),
         );
      },
    );
  }

  Widget _buildSetRow(int idx, _SetData s, _ExData d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16, right: 0),
      child: Row(children: [
        Expanded(flex: 1, child: _inputField(s.sCtrl, '1', isCompleted: s.isCompleted)),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _inputField(s.wCtrl, 'e.g. 100', decimal: true, isCompleted: s.isCompleted)),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _inputField(s.rCtrl, 'e.g. 5', isCompleted: s.isCompleted)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
             if (s.wCtrl.text.isNotEmpty && s.rCtrl.text.isNotEmpty) {
                setState(() => s.isCompleted = !s.isCompleted);
             }
          },
          child: Container(
            width: 44, height: 42,
            decoration: BoxDecoration(
              color: s.isCompleted ? AppColors.accentBlue : AppColors.inputBg,
              border: Border.all(color: s.isCompleted ? AppColors.accentBlue : AppColors.borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: s.isCompleted ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
          ),
        ),
        SizedBox(
          width: 40,
          child: d.sets.length > 1 ? IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: () {
              setState(() {
                s.dispose();
                d.sets.removeAt(idx);
              });
            },
          ) : const SizedBox(),
        ),
      ]),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, {bool decimal = false, bool isCompleted = false}) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: ctrl,
        enabled: !isCompleted,
        keyboardType: decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
        inputFormatters: decimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
            : [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary, fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
      ),
    );
  }
}

class _IsolatedTimerDisplay extends StatefulWidget {
  final bool isRunning;
  final DateTime? startTime;
  final int accumulatedSeconds;

  const _IsolatedTimerDisplay({
    Key? key,
    required this.isRunning,
    this.startTime,
    required this.accumulatedSeconds,
  }) : super(key: key);

  @override
  State<_IsolatedTimerDisplay> createState() => _IsolatedTimerDisplayState();
}

class _IsolatedTimerDisplayState extends State<_IsolatedTimerDisplay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isRunning) _startTimer();
  }

  @override
  void didUpdateWidget(_IsolatedTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !oldWidget.isRunning) {
      _startTimer();
    } else if (!widget.isRunning && oldWidget.isRunning) {
      _timer?.cancel();
      if (mounted) setState(() {});
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _currentSeconds {
    if (!widget.isRunning || widget.startTime == null) return widget.accumulatedSeconds;
    return widget.accumulatedSeconds + DateTime.now().difference(widget.startTime!).inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _currentSeconds;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.isRunning ? 'Workout Duration' : 'Paused', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Text('$m:$s', style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
      ],
    );
  }
}
