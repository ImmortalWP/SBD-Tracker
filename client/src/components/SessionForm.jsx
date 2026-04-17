import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { HiPlus, HiTrash, HiCheck } from 'react-icons/hi';
import { createSession, updateSession } from '../api/sessions';

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MAIN_LIFTS = ['Squat', 'Bench', 'Deadlift'];
const SECONDARY_LIFT_GROUPS = {
  Squat: ['Pause Squat', 'Tempo Squat', 'Pin Squat', 'Box Squat'],
  Bench: ['Pause Bench', 'Close Grip Larsen', 'Pin Bench'],
  Deadlift: ['Pause Deadlift', 'Deficit Deadlift']
};

const emptySet = () => ({ weight: '', sets: '1', reps: '' });
const emptyExercise = (category = 'main') => ({
  name: category === 'main' ? '' : '',
  category,
  sets: [emptySet()],
});

export default function SessionForm({ existingSession }) {
  const navigate = useNavigate();
  const isEditing = Boolean(existingSession);

  const [block, setBlock] = useState('');
  const [percentage, setPercentage] = useState('');
  const [day, setDay] = useState('Sunday');
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [exercises, setExercises] = useState([emptyExercise('main')]);
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  const getDuration = () => {
    if (!startTime) return null;
    const refDate = date || new Date().toISOString().split('T')[0];
    const end = endTime ? new Date(`${refDate}T${endTime}`) : now;
    const start = new Date(`${refDate}T${startTime}`);
    let diffMs = end - start;
    if (diffMs < 0) diffMs += 24 * 60 * 60 * 1000;
    if (isNaN(diffMs)) return '00:00:00';
    const totalSeconds = Math.floor(diffMs / 1000);
    const h = Math.floor(totalSeconds / 3600);
    const m = Math.floor((totalSeconds % 3600) / 60);
    const s = totalSeconds % 60;
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const handleStartWorkout = () => {
    const dt = new Date();
    setStartTime(dt.toTimeString().split(' ')[0]);
  };

  const handleEndWorkout = () => {
    const dt = new Date();
    setEndTime(dt.toTimeString().split(' ')[0]);
  };

  // Pre-fill form when editing
  useEffect(() => {
    if (existingSession) {
      setBlock(existingSession.block.toString());
      setPercentage(existingSession.percentage ? existingSession.percentage.toString() : '');
      setDay(existingSession.day);
      setDate(
        existingSession.date
          ? new Date(existingSession.date).toISOString().split('T')[0]
          : ''
      );
      setStartTime(existingSession.startTime || '');
      setEndTime(existingSession.endTime || '');
      setExercises(
        existingSession.exercises.map((ex) => ({
          name: ex.name,
          category: ex.category,
          sets: ex.sets.map((s) => ({
            weight: s.weight.toString(),
            sets: s.sets.toString(),
            reps: s.reps.toString(),
          })),
        }))
      );
      setNotes(existingSession.notes || '');
    }
  }, [existingSession]);

  // --- Exercise handlers ---
  const addExercise = (category = 'main') => {
    setExercises([...exercises, emptyExercise(category)]);
  };

  const removeExercise = (exIdx) => {
    setExercises(exercises.filter((_, i) => i !== exIdx));
  };

  const updateExerciseField = (exIdx, field, value) => {
    const updated = [...exercises];
    updated[exIdx] = { ...updated[exIdx], [field]: value };
    setExercises(updated);
  };

  // --- Set handlers ---
  const addSet = (exIdx) => {
    const updated = [...exercises];
    updated[exIdx].sets = [...updated[exIdx].sets, emptySet()];
    setExercises(updated);
  };

  const removeSet = (exIdx, setIdx) => {
    const updated = [...exercises];
    updated[exIdx].sets = updated[exIdx].sets.filter((_, i) => i !== setIdx);
    setExercises(updated);
  };

  const updateSetField = (exIdx, setIdx, field, value) => {
    const updated = [...exercises];
    updated[exIdx].sets = [...updated[exIdx].sets];
    updated[exIdx].sets[setIdx] = { ...updated[exIdx].sets[setIdx], [field]: value };
    setExercises(updated);
  };

  // --- Submit ---
  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    // Validate
    if (!block || !day) {
      setError('Block number and day are required.');
      return;
    }

    // Build payload
    const payload = {
      block: Number(block),
      percentage: percentage ? Number(percentage) : undefined,
      day,
      date: date || undefined,
      startTime: startTime || undefined,
      endTime: endTime || undefined,
      notes,
      exercises: exercises
        .filter((ex) => ex.name.trim())
        .map((ex) => ({
          name: ex.name.trim(),
          category: ex.category,
          sets: ex.sets
            .filter((s) => s.weight && s.reps)
            .map((s) => ({
              weight: Number(s.weight),
              sets: Number(s.sets) || 1,
              reps: Number(s.reps),
            })),
        }))
        .filter((ex) => ex.sets.length > 0),
    };

    if (payload.exercises.length === 0) {
      setError('Add at least one exercise with sets.');
      return;
    }

    setLoading(true);
    try {
      if (isEditing) {
        await updateSession(existingSession._id, payload);
      } else {
        await createSession(payload);
      }
      navigate('/sessions');
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to save session.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6 max-w-2xl">
      {error && (
        <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
          {error}
        </div>
      )}

      {/* Timer / Time tracking */}
      <div className="card p-4 flex items-center justify-between border-gym-700 bg-gym-900/50">
        <div className="flex gap-4 items-center">
          <div>
            <label className="block text-xs font-semibold uppercase text-gym-400 mb-1">Start</label>
            <input type="time" step="1" value={startTime} onChange={e => setStartTime(e.target.value)} className="input-base py-1.5 w-auto" />
          </div>
          <div>
            <label className="block text-xs font-semibold uppercase text-gym-400 mb-1">End</label>
            <input type="time" step="1" value={endTime} onChange={e => setEndTime(e.target.value)} className="input-base py-1.5 w-auto" />
          </div>
        </div>
        
        <div className="flex flex-col items-end">
          <div className="font-mono text-xl font-bold tracking-wider text-accent-red drop-shadow-md">
            {startTime ? getDuration() : '00:00:00'}
          </div>
          {!startTime && (
            <button type="button" onClick={handleStartWorkout} className="text-xs btn-primary py-1 px-3 mt-1">Start Timer</button>
          )}
          {startTime && !endTime && (
            <button type="button" onClick={handleEndWorkout} className="text-xs btn-secondary py-1 px-3 mt-1 border-accent-blue text-accent-blue">End Workout</button>
          )}
        </div>
      </div>

      {/* Block / Percentage / Day / Date row */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div>
          <label className="block text-xs font-semibold uppercase tracking-wider text-gym-400 mb-1.5">
            Block #
          </label>
          <input
            type="number"
            value={block}
            onChange={(e) => setBlock(e.target.value)}
            placeholder="1"
            className="input-base"
            id="input-block"
            min="1"
            required
          />
        </div>
        <div>
          <label className="block text-xs font-semibold uppercase tracking-wider text-gym-400 mb-1.5">
            Intensity %
          </label>
          <input
            type="number"
            value={percentage}
            onChange={(e) => setPercentage(e.target.value)}
            placeholder="75"
            className="input-base"
            id="input-percentage"
            min="0"
            max="100"
            step="1"
          />
        </div>
        <div>
          <label className="block text-xs font-semibold uppercase tracking-wider text-gym-400 mb-1.5">
            Day
          </label>
          <select
            value={day}
            onChange={(e) => setDay(e.target.value)}
            className="input-base cursor-pointer"
            id="input-day"
          >
            {DAYS.map((d) => (
              <option key={d} value={d}>{d}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs font-semibold uppercase tracking-wider text-gym-400 mb-1.5">
            Date
          </label>
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="input-base"
            id="input-date"
          />
        </div>
      </div>

      {/* Exercises */}
      <div className="space-y-5">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-semibold uppercase tracking-wider text-gym-300">
            Exercises
          </h3>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => addExercise('main')}
              className="btn-secondary text-xs flex items-center gap-1"
              id="add-main-exercise"
            >
              <HiPlus className="text-sm" /> Main Lift
            </button>
            <button
              type="button"
              onClick={() => addExercise('secondary')}
              className="btn-secondary text-xs flex items-center gap-1"
              id="add-secondary-exercise"
            >
              <HiPlus className="text-sm" /> Secondary
            </button>
            <button
              type="button"
              onClick={() => addExercise('accessory')}
              className="btn-secondary text-xs flex items-center gap-1"
              id="add-accessory-exercise"
            >
              <HiPlus className="text-sm" /> Accessory
            </button>
          </div>
        </div>

        {exercises.map((ex, exIdx) => (
          <div
            key={exIdx}
            className="card p-4 space-y-3 animate-fade-in"
          >
            {/* Exercise header */}
            <div className="flex items-center gap-3">
              <div className="flex-1">
                {ex.category === 'main' ? (
                  <select
                    value={ex.name}
                    onChange={(e) => updateExerciseField(exIdx, 'name', e.target.value)}
                    className="input-base"
                    id={`exercise-name-${exIdx}`}
                  >
                    <option value="">Select main lift...</option>
                    {MAIN_LIFTS.map((l) => (
                      <option key={l} value={l}>{l}</option>
                    ))}
                  </select>
                ) : ex.category === 'secondary' ? (
                  <select
                    value={ex.name}
                    onChange={(e) => updateExerciseField(exIdx, 'name', e.target.value)}
                    className="input-base"
                    id={`exercise-name-${exIdx}`}
                  >
                    <option value="">Select secondary lift...</option>
                    {Object.entries(SECONDARY_LIFT_GROUPS).map(([group, lifts]) => (
                      <optgroup key={group} label={group}>
                        {lifts.map((l) => (
                          <option key={l} value={l}>{l}</option>
                        ))}
                      </optgroup>
                    ))}
                  </select>
                ) : (
                  <input
                    type="text"
                    value={ex.name}
                    onChange={(e) => updateExerciseField(exIdx, 'name', e.target.value)}
                    placeholder="Exercise name (e.g., Lat Pulldown)"
                    className="input-base"
                    id={`exercise-name-${exIdx}`}
                  />
                )}
              </div>
              <span className={ex.category === 'main' ? 'badge-main' : ex.category === 'secondary' ? 'badge-secondary' : 'badge-accessory'}>
                {ex.category}
              </span>
              {exercises.length > 1 && (
                <button
                  type="button"
                  onClick={() => removeExercise(exIdx)}
                  className="btn-danger p-1.5"
                  title="Remove exercise"
                  id={`remove-exercise-${exIdx}`}
                >
                  <HiTrash className="text-sm" />
                </button>
              )}
            </div>

            {/* Sets */}
            <div className="space-y-2">
              <div className="grid grid-cols-[auto_1fr_1fr_1fr_auto] gap-2 text-xs font-semibold uppercase tracking-wider text-gym-500 px-1">
                <span className="w-6">#</span>
                <span>Weight (kg)</span>
                <span>Sets</span>
                <span>Reps</span>
                <span className="w-8" />
              </div>
              {ex.sets.map((set, setIdx) => (
                <div
                  key={setIdx}
                  className="grid grid-cols-[auto_1fr_1fr_1fr_auto] gap-2 items-center animate-fade-in"
                >
                  <span className="text-xs text-gym-600 font-mono w-6 text-center">
                    {setIdx + 1}
                  </span>
                  <input
                    type="number"
                    value={set.weight}
                    onChange={(e) => updateSetField(exIdx, setIdx, 'weight', e.target.value)}
                    placeholder="70"
                    className="input-base text-center font-mono"
                    id={`set-weight-${exIdx}-${setIdx}`}
                    min="0"
                    step="0.5"
                  />
                  <input
                    type="number"
                    value={set.sets}
                    onChange={(e) => updateSetField(exIdx, setIdx, 'sets', e.target.value)}
                    placeholder="1"
                    className="input-base text-center font-mono"
                    id={`set-sets-${exIdx}-${setIdx}`}
                    min="1"
                  />
                  <input
                    type="number"
                    value={set.reps}
                    onChange={(e) => updateSetField(exIdx, setIdx, 'reps', e.target.value)}
                    placeholder="6"
                    className="input-base text-center font-mono"
                    id={`set-reps-${exIdx}-${setIdx}`}
                    min="1"
                  />
                  <button
                    type="button"
                    onClick={() => removeSet(exIdx, setIdx)}
                    className="btn-danger p-1.5 w-8"
                    title="Remove set"
                    id={`remove-set-${exIdx}-${setIdx}`}
                    disabled={ex.sets.length <= 1}
                  >
                    <HiTrash className="text-xs" />
                  </button>
                </div>
              ))}
              <button
                type="button"
                onClick={() => addSet(exIdx)}
                className="btn-ghost text-xs flex items-center gap-1 mt-1"
                id={`add-set-${exIdx}`}
              >
                <HiPlus className="text-sm" /> Add Set
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Notes */}
      <div>
        <label className="block text-xs font-semibold uppercase tracking-wider text-gym-400 mb-1.5">
          Notes (optional)
        </label>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="How did the session feel? Any PRs?"
          className="input-base min-h-[80px] resize-y"
          id="input-notes"
          rows={3}
        />
      </div>

      {/* Actions */}
      <div className="flex items-center gap-3 pt-2">
        <button
          type="submit"
          disabled={loading}
          className="btn-primary flex items-center gap-2"
          id="submit-session"
        >
          <HiCheck className="text-base" />
          {loading ? 'Saving...' : isEditing ? 'Update Session' : 'Log Session'}
        </button>
        <button
          type="button"
          onClick={() => navigate(-1)}
          className="btn-secondary"
          id="cancel-session"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}
