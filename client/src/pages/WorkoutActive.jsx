import { useState, useEffect, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { HiPlus, HiTrash, HiCheck, HiX, HiClock, HiDotsVertical, HiChevronDown } from 'react-icons/hi';
import { createWorkout, updateWorkout, getWorkout } from '../api/api';
import ExercisePicker from '../components/ExercisePicker';
import RestTimer from '../components/RestTimer';

const emptySet = (n = 1) => ({ setNumber: n, weight: '', reps: '', rpe: '', isWarmup: false, isDropset: false, completed: false });

export default function WorkoutActive() {
  const navigate = useNavigate();
  const { id } = useParams();
  const isEditing = Boolean(id);

  const [name, setName] = useState('Workout');
  const [exercises, setExercises] = useState([]);
  const [notes, setNotes] = useState('');
  const [showPicker, setShowPicker] = useState(false);
  const [showTimer, setShowTimer] = useState(false);
  const [startTime] = useState(() => new Date());
  const [elapsed, setElapsed] = useState(0);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [newPRs, setNewPRs] = useState([]);
  const [showPRToast, setShowPRToast] = useState(false);
  const timerRef = useRef(null);

  // Workout timer
  useEffect(() => {
    if (!isEditing) {
      timerRef.current = setInterval(() => {
        setElapsed(Math.floor((Date.now() - startTime.getTime()) / 1000));
      }, 1000);
    }
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, [startTime, isEditing]);

  // Load existing workout
  useEffect(() => {
    if (isEditing) {
      loadWorkout();
    }
  }, [id]);

  const loadWorkout = async () => {
    setLoading(true);
    try {
      const res = await getWorkout(id);
      const w = res.data;
      setName(w.name || 'Workout');
      setNotes(w.notes || '');
      setExercises(w.exercises.map(ex => ({
        exerciseId: ex.exerciseId,
        name: ex.name,
        notes: ex.notes || '',
        sets: ex.sets.map(s => ({
          ...s,
          weight: s.weight?.toString() || '',
          reps: s.reps?.toString() || '',
          rpe: s.rpe?.toString() || '',
        })),
      })));
    } catch (err) {
      console.error('Failed to load workout:', err);
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (s) => {
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const sec = s % 60;
    if (h > 0) return `${h}:${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
    return `${m}:${sec.toString().padStart(2, '0')}`;
  };

  // Add exercise from picker
  const handleAddExercise = (exercise) => {
    setExercises(prev => [...prev, {
      exerciseId: exercise._id,
      name: exercise.name,
      notes: '',
      sets: [emptySet(1)],
    }]);
  };

  const removeExercise = (idx) => {
    setExercises(prev => prev.filter((_, i) => i !== idx));
  };

  const addSet = (exIdx) => {
    setExercises(prev => {
      const updated = [...prev];
      const lastSet = updated[exIdx].sets[updated[exIdx].sets.length - 1];
      updated[exIdx] = {
        ...updated[exIdx],
        sets: [...updated[exIdx].sets, {
          ...emptySet(updated[exIdx].sets.length + 1),
          weight: lastSet?.weight || '',
          reps: lastSet?.reps || '',
        }],
      };
      return updated;
    });
  };

  const removeSet = (exIdx, setIdx) => {
    setExercises(prev => {
      const updated = [...prev];
      updated[exIdx] = {
        ...updated[exIdx],
        sets: updated[exIdx].sets.filter((_, i) => i !== setIdx)
          .map((s, i) => ({ ...s, setNumber: i + 1 })),
      };
      return updated;
    });
  };

  const updateSet = (exIdx, setIdx, field, value) => {
    setExercises(prev => {
      const updated = [...prev];
      updated[exIdx] = { ...updated[exIdx], sets: [...updated[exIdx].sets] };
      updated[exIdx].sets[setIdx] = { ...updated[exIdx].sets[setIdx], [field]: value };
      return updated;
    });
  };

  const toggleComplete = (exIdx, setIdx) => {
    const set = exercises[exIdx].sets[setIdx];
    if (!set.completed && (!set.weight || !set.reps)) return;
    updateSet(exIdx, setIdx, 'completed', !set.completed);
    if (!set.completed) {
      setShowTimer(true);
    }
  };

  const updateExerciseNotes = (exIdx, val) => {
    setExercises(prev => {
      const updated = [...prev];
      updated[exIdx] = { ...updated[exIdx], notes: val };
      return updated;
    });
  };

  // Save / Finish
  const handleFinish = async () => {
    const payload = {
      name,
      date: startTime.toISOString(),
      duration: elapsed,
      startTime: startTime.toISOString(),
      endTime: new Date().toISOString(),
      notes,
      exercises: exercises
        .filter(ex => ex.sets.some(s => s.completed))
        .map(ex => ({
          exerciseId: ex.exerciseId,
          name: ex.name,
          notes: ex.notes,
          sets: ex.sets
            .filter(s => s.weight && s.reps)
            .map(s => ({
              ...s,
              weight: Number(s.weight) || 0,
              reps: Number(s.reps) || 0,
              rpe: s.rpe ? Number(s.rpe) : undefined,
            })),
        }))
        .filter(ex => ex.sets.length > 0),
    };

    if (payload.exercises.length === 0) return;

    setSaving(true);
    try {
      let res;
      if (isEditing) {
        res = await updateWorkout(id, payload);
      } else {
        res = await createWorkout(payload);
      }
      if (res.data.newPRs?.length > 0) {
        setNewPRs(res.data.newPRs);
        setShowPRToast(true);
        setTimeout(() => navigate('/history'), 2000);
      } else {
        navigate('/history');
      }
    } catch (err) {
      console.error('Failed to save workout:', err);
    } finally {
      setSaving(false);
    }
  };

  const handleDiscard = () => {
    if (exercises.length > 0 && exercises.some(e => e.sets.some(s => s.completed))) {
      if (!confirm('Discard this workout?')) return;
    }
    navigate('/');
  };

  if (loading) {
    return (
      <div className="space-y-4 animate-fade-in">
        {[1,2,3].map(i => <div key={i} className="skeleton h-32 rounded-2xl" />)}
      </div>
    );
  }

  return (
    <div className="animate-fade-in -mx-4 -my-4">
      {/* PR Toast */}
      {showPRToast && (
        <div className="toast flex items-center gap-2 bg-sl-amber/20 border-sl-amber/30">
          <span className="text-xl">🏆</span>
          <div>
            <p className="font-bold text-sl-amber">New PR!</p>
            {newPRs.map((pr, i) => (
              <p key={i} className="text-xs text-sl-textSecondary">{pr.exercise}: {pr.weight}kg × {pr.reps}</p>
            ))}
          </div>
        </div>
      )}

      {/* Header */}
      <div className="sticky top-0 z-30 bg-sl-bg/95 backdrop-blur-xl border-b border-sl-border px-4 py-3">
        <div className="flex items-center justify-between max-w-lg mx-auto">
          <button onClick={handleDiscard} className="text-sl-red text-sm font-semibold" id="discard-workout">
            {isEditing ? 'Cancel' : 'Discard'}
          </button>
          <div className="text-center">
            <input
              type="text"
              value={name}
              onChange={e => setName(e.target.value)}
              className="bg-transparent text-center text-sm font-bold text-sl-text focus:outline-none w-40"
              id="workout-name"
            />
            {!isEditing && (
              <div className="flex items-center justify-center gap-1 text-sl-green">
                <HiClock className="text-xs" />
                <span className="text-xs font-mono font-semibold">{formatTime(elapsed)}</span>
              </div>
            )}
          </div>
          <button onClick={handleFinish} disabled={saving} className="text-sl-green text-sm font-bold" id="finish-workout">
            {saving ? '...' : 'Finish'}
          </button>
        </div>
      </div>

      {/* Exercises */}
      <div className="px-4 py-4 max-w-lg mx-auto space-y-4">
        {exercises.map((ex, exIdx) => (
          <div key={exIdx} className="card p-4 animate-fade-in">
            {/* Exercise name */}
            <div className="flex items-center justify-between mb-1">
              <h3 className="text-sm font-bold text-sl-green">{ex.name}</h3>
              <button onClick={() => removeExercise(exIdx)} className="btn-icon w-8 h-8" id={`remove-ex-${exIdx}`}>
                <HiTrash className="text-sm text-sl-red" />
              </button>
            </div>

            {/* Exercise notes */}
            <input
              type="text"
              value={ex.notes}
              onChange={e => updateExerciseNotes(exIdx, e.target.value)}
              placeholder="Add notes..."
              className="w-full text-xs text-sl-textMuted bg-transparent border-none focus:outline-none mb-3 placeholder:text-sl-textMuted/50"
            />

            {/* Set header */}
            <div className="grid grid-cols-[32px_1fr_1fr_60px_36px] gap-2 mb-1 px-1">
              <span className="text-[10px] font-semibold text-sl-textMuted text-center">SET</span>
              <span className="text-[10px] font-semibold text-sl-textMuted text-center">KG</span>
              <span className="text-[10px] font-semibold text-sl-textMuted text-center">REPS</span>
              <span className="text-[10px] font-semibold text-sl-textMuted text-center">RPE</span>
              <span className="text-[10px] font-semibold text-sl-textMuted text-center">✓</span>
            </div>

            {/* Sets */}
            {ex.sets.map((set, setIdx) => (
              <div key={setIdx} className={`set-row grid grid-cols-[32px_1fr_1fr_60px_36px] gap-2 ${set.completed ? 'completed' : ''}`}>
                <div className="flex items-center justify-center">
                  {set.isWarmup ? (
                    <span className="text-xs font-bold text-sl-amber">W</span>
                  ) : (
                    <span className="text-xs font-mono text-sl-textMuted">{set.setNumber}</span>
                  )}
                </div>
                <input
                  type="number"
                  value={set.weight}
                  onChange={e => updateSet(exIdx, setIdx, 'weight', e.target.value)}
                  placeholder="0"
                  className="input-compact"
                  id={`set-w-${exIdx}-${setIdx}`}
                />
                <input
                  type="number"
                  value={set.reps}
                  onChange={e => updateSet(exIdx, setIdx, 'reps', e.target.value)}
                  placeholder="0"
                  className="input-compact"
                  id={`set-r-${exIdx}-${setIdx}`}
                />
                <input
                  type="number"
                  value={set.rpe}
                  onChange={e => updateSet(exIdx, setIdx, 'rpe', e.target.value)}
                  placeholder="—"
                  className="input-compact text-[11px]"
                  min="1" max="10"
                  id={`set-rpe-${exIdx}-${setIdx}`}
                />
                <button
                  onClick={() => toggleComplete(exIdx, setIdx)}
                  className={`w-9 h-9 rounded-lg flex items-center justify-center transition-all ${
                    set.completed ? 'bg-sl-green text-white' : 'bg-sl-surface text-sl-textMuted hover:bg-sl-border'
                  }`}
                  id={`set-done-${exIdx}-${setIdx}`}
                >
                  <HiCheck className="text-sm" />
                </button>
              </div>
            ))}

            {/* Add set / options */}
            <div className="flex items-center gap-2 mt-2">
              <button onClick={() => addSet(exIdx)} className="btn-ghost text-xs flex items-center gap-1 flex-1 justify-center" id={`add-set-${exIdx}`}>
                <HiPlus className="text-sm" /> Add Set
              </button>
            </div>
          </div>
        ))}

        {/* Add Exercise Button */}
        <button onClick={() => setShowPicker(true)} className="btn-secondary w-full flex items-center justify-center gap-2" id="add-exercise-btn">
          <HiPlus /> Add Exercise
        </button>

        {/* Notes */}
        <div>
          <textarea
            value={notes}
            onChange={e => setNotes(e.target.value)}
            placeholder="Workout notes..."
            className="input-field min-h-[60px] resize-y text-sm"
            id="workout-notes"
            rows={2}
          />
        </div>

        {/* Timer toggle */}
        <button onClick={() => setShowTimer(true)} className="btn-ghost w-full flex items-center justify-center gap-2 text-sl-green" id="show-timer">
          <HiClock /> Rest Timer
        </button>
      </div>

      {/* Exercise Picker */}
      <ExercisePicker
        isOpen={showPicker}
        onClose={() => setShowPicker(false)}
        onSelect={handleAddExercise}
      />

      {/* Rest Timer */}
      <RestTimer
        isOpen={showTimer}
        onClose={() => setShowTimer(false)}
        defaultSeconds={90}
      />
    </div>
  );
}
