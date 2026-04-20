import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { HiSearch, HiPlus } from 'react-icons/hi';
import { getExercises } from '../api/api';

const MUSCLE_TABS = ['All', 'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core'];
const MUSCLE_MAP = {
  All: null,
  Chest: 'Chest',
  Back: 'Back',
  Shoulders: 'Shoulders',
  Arms: 'Biceps',
  Legs: 'Quads',
  Core: 'Abs',
};

export default function Exercises() {
  const [exercises, setExercises] = useState([]);
  const [search, setSearch] = useState('');
  const [activeTab, setActiveTab] = useState('All');
  const [loading, setLoading] = useState(true);

  const loadExercises = useCallback(async () => {
    setLoading(true);
    try {
      const params = {};
      if (search) params.search = search;
      const muscle = MUSCLE_MAP[activeTab];
      if (muscle) params.muscle = muscle;
      const res = await getExercises(params);
      setExercises(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [search, activeTab]);

  useEffect(() => {
    const timeout = setTimeout(loadExercises, 250);
    return () => clearTimeout(timeout);
  }, [loadExercises]);

  // Group by first letter
  const grouped = {};
  exercises.forEach(ex => {
    const letter = ex.name[0].toUpperCase();
    if (!grouped[letter]) grouped[letter] = [];
    grouped[letter].push(ex);
  });

  const getCategoryColor = (cat) => {
    const colors = {
      Barbell: 'text-sl-red', Dumbbell: 'text-sl-blue', Machine: 'text-sl-purple',
      Cable: 'text-sl-cyan', Bodyweight: 'text-sl-green', Band: 'text-sl-amber',
      Cardio: 'text-sl-amber', Stretching: 'text-sl-green',
    };
    return colors[cat] || 'text-sl-textMuted';
  };

  return (
    <div className="space-y-4 animate-fade-in">
      <h1 className="text-2xl font-extrabold text-sl-text tracking-tight">Exercises</h1>

      {/* Search */}
      <div className="relative">
        <HiSearch className="absolute left-3.5 top-1/2 -translate-y-1/2 text-sl-textMuted" />
        <input
          type="text" value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search exercises..."
          className="input-field pl-10"
          id="exercise-search"
        />
      </div>

      {/* Muscle group tabs */}
      <div className="flex gap-1.5 overflow-x-auto pb-1 -mx-1 px-1">
        {MUSCLE_TABS.map(tab => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
              activeTab === tab ? 'bg-sl-green text-white' : 'bg-sl-card text-sl-textSecondary hover:bg-sl-cardHover'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* List */}
      {loading ? (
        <div className="space-y-2">
          {[1,2,3,4,5,6].map(i => <div key={i} className="skeleton h-16 rounded-xl" />)}
        </div>
      ) : Object.keys(grouped).length > 0 ? (
        <div className="space-y-4">
          {Object.entries(grouped).sort().map(([letter, exs]) => (
            <div key={letter}>
              <p className="text-xs font-bold text-sl-green mb-2 px-1">{letter}</p>
              <div className="space-y-1">
                {exs.map(ex => (
                  <Link to={`/exercises/${ex._id}`} key={ex._id}
                    className="flex items-center gap-3 px-3 py-3 rounded-xl hover:bg-sl-card transition-colors"
                    id={`ex-${ex._id}`}
                  >
                    <div className="w-9 h-9 rounded-lg bg-sl-surface flex items-center justify-center text-sl-green text-sm font-bold shrink-0">
                      {ex.name[0]}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-sl-text truncate">{ex.name}</p>
                      <p className="text-xs text-sl-textMuted truncate">
                        <span className={getCategoryColor(ex.category)}>{ex.category}</span>
                        {' • '}{ex.primaryMuscles?.join(', ')}
                      </p>
                    </div>
                  </Link>
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="card p-8 text-center">
          <p className="text-sl-textMuted text-sm">No exercises found</p>
        </div>
      )}

      <p className="text-center text-xs text-sl-textMuted pb-4">{exercises.length} exercises</p>
    </div>
  );
}
