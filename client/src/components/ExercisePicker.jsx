import { useState, useEffect, useCallback } from 'react';
import { HiSearch, HiX } from 'react-icons/hi';
import { getExercises } from '../api/api';

const MUSCLE_GROUPS = ['All', 'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Abs', 'Traps', 'Lats', 'Forearms'];
const CATEGORIES = ['All', 'Barbell', 'Dumbbell', 'Machine', 'Cable', 'Bodyweight', 'Band', 'Cardio'];

export default function ExercisePicker({ isOpen, onClose, onSelect }) {
  const [exercises, setExercises] = useState([]);
  const [search, setSearch] = useState('');
  const [muscle, setMuscle] = useState('All');
  const [category, setCategory] = useState('All');
  const [loading, setLoading] = useState(false);

  const loadExercises = useCallback(async () => {
    setLoading(true);
    try {
      const params = {};
      if (search) params.search = search;
      if (muscle !== 'All') params.muscle = muscle;
      if (category !== 'All') params.category = category;
      const res = await getExercises(params);
      setExercises(res.data);
    } catch (err) {
      console.error('Failed to load exercises:', err);
    } finally {
      setLoading(false);
    }
  }, [search, muscle, category]);

  useEffect(() => {
    if (isOpen) {
      const timeout = setTimeout(loadExercises, 300);
      return () => clearTimeout(timeout);
    }
  }, [isOpen, loadExercises]);

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-sl-border">
          <h2 className="text-lg font-bold">Add Exercise</h2>
          <button onClick={onClose} className="btn-icon" id="close-exercise-picker">
            <HiX className="text-xl" />
          </button>
        </div>

        {/* Search */}
        <div className="p-4 pb-2">
          <div className="relative">
            <HiSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-sl-textMuted" />
            <input
              type="text"
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search exercises..."
              className="input-field pl-10"
              autoFocus
              id="exercise-search"
            />
          </div>
        </div>

        {/* Muscle filter */}
        <div className="px-4 pb-2 overflow-x-auto">
          <div className="flex gap-1.5 pb-1">
            {MUSCLE_GROUPS.map(m => (
              <button
                key={m}
                onClick={() => setMuscle(m)}
                className={`whitespace-nowrap px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  muscle === m ? 'bg-sl-green text-white' : 'bg-sl-surface text-sl-textSecondary hover:bg-sl-card'
                }`}
              >
                {m}
              </button>
            ))}
          </div>
        </div>

        {/* Category filter */}
        <div className="px-4 pb-3 overflow-x-auto">
          <div className="flex gap-1.5 pb-1">
            {CATEGORIES.map(c => (
              <button
                key={c}
                onClick={() => setCategory(c)}
                className={`whitespace-nowrap px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  category === c ? 'bg-sl-blue text-white' : 'bg-sl-surface text-sl-textSecondary hover:bg-sl-card'
                }`}
              >
                {c}
              </button>
            ))}
          </div>
        </div>

        {/* Exercise list */}
        <div className="overflow-y-auto max-h-[50vh] px-2 pb-4">
          {loading ? (
            <div className="space-y-2 px-2">
              {[1,2,3,4,5].map(i => (
                <div key={i} className="skeleton h-14 rounded-xl" />
              ))}
            </div>
          ) : exercises.length > 0 ? (
            <div className="space-y-1">
              {exercises.map(ex => (
                <button
                  key={ex._id}
                  onClick={() => { onSelect(ex); onClose(); }}
                  className="w-full text-left px-4 py-3 rounded-xl hover:bg-sl-surface transition-colors flex items-center gap-3"
                  id={`pick-exercise-${ex._id}`}
                >
                  <div className="w-9 h-9 rounded-lg bg-sl-green/10 flex items-center justify-center text-sl-green text-sm font-bold">
                    {ex.name[0]}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-sl-text truncate">{ex.name}</p>
                    <p className="text-xs text-sl-textMuted truncate">
                      {ex.primaryMuscles?.join(', ')} • {ex.category}
                    </p>
                  </div>
                </button>
              ))}
            </div>
          ) : (
            <div className="py-12 text-center text-sl-textMuted text-sm">
              No exercises found
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
