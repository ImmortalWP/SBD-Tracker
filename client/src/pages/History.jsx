import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { HiClock, HiLightningBolt, HiTrash, HiTrendingUp } from 'react-icons/hi';
import { getWorkouts, deleteWorkout } from '../api/api';

export default function History() {
  const [workouts, setWorkouts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [total, setTotal] = useState(0);

  useEffect(() => { loadWorkouts(); }, []);

  const loadWorkouts = async () => {
    try {
      const res = await getWorkouts({ limit: 100 });
      setWorkouts(res.data.workouts || []);
      setTotal(res.data.total || 0);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this workout?')) return;
    try {
      await deleteWorkout(id);
      setWorkouts(prev => prev.filter(w => w._id !== id));
    } catch (err) {
      console.error(err);
    }
  };

  const formatDate = (d) => {
    const date = new Date(d);
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    if (date.toDateString() === today.toDateString()) return 'Today';
    if (date.toDateString() === yesterday.toDateString()) return 'Yesterday';
    return date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  };

  const formatDuration = (s) => {
    if (!s) return '';
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    return h > 0 ? `${h}h ${m}m` : `${m}m`;
  };

  const formatVolume = (v) => v >= 1000 ? `${(v / 1000).toFixed(1)}k` : (v || 0).toString();

  // Group by date
  const grouped = {};
  workouts.forEach(w => {
    const key = new Date(w.date).toLocaleDateString('en-US', { year: 'numeric', month: 'long' });
    if (!grouped[key]) grouped[key] = [];
    grouped[key].push(w);
  });

  return (
    <div className="space-y-5 animate-fade-in">
      <div>
        <h1 className="text-2xl font-extrabold text-sl-text tracking-tight">History</h1>
        <p className="text-sl-textMuted text-sm">{total} workouts logged</p>
      </div>

      {loading ? (
        <div className="space-y-3">
          {[1,2,3,4].map(i => <div key={i} className="skeleton h-20 rounded-2xl" />)}
        </div>
      ) : Object.keys(grouped).length > 0 ? (
        Object.entries(grouped).map(([month, monthWorkouts]) => (
          <div key={month}>
            <h2 className="section-title mb-3">{month}</h2>
            <div className="space-y-2">
              {monthWorkouts.map(w => (
                <div key={w._id} className="card p-4">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 rounded-xl bg-sl-green/10 flex items-center justify-center text-sl-green shrink-0">
                      <HiLightningBolt />
                    </div>
                    <Link to={`/workout/${w._id}`} className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-sl-text">{w.name || 'Workout'}</p>
                      <p className="text-xs text-sl-textMuted mt-0.5">{formatDate(w.date)}</p>
                      <div className="flex gap-3 mt-1.5 text-xs text-sl-textSecondary">
                        <span>{w.exercises?.length || 0} exercises</span>
                        <span>{w.totalSets || 0} sets</span>
                        <span className="flex items-center gap-0.5">
                          <HiTrendingUp className="text-sl-green" /> {formatVolume(w.totalVolume)} kg
                        </span>
                        {w.duration > 0 && (
                          <span className="flex items-center gap-0.5">
                            <HiClock /> {formatDuration(w.duration)}
                          </span>
                        )}
                      </div>
                      {/* Exercise names preview */}
                      <p className="text-[11px] text-sl-textMuted mt-1 truncate">
                        {w.exercises?.map(e => e.name).join(' • ')}
                      </p>
                    </Link>
                    <button onClick={() => handleDelete(w._id)} className="btn-icon w-8 h-8 shrink-0" id={`del-${w._id}`}>
                      <HiTrash className="text-sm text-sl-textMuted" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))
      ) : (
        <div className="card p-8 text-center">
          <p className="text-4xl mb-3">📋</p>
          <p className="text-sl-textMuted text-sm">No workouts yet.</p>
        </div>
      )}
    </div>
  );
}
