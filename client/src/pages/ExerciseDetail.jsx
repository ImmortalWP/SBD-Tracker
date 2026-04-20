import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { HiArrowLeft, HiTrendingUp } from 'react-icons/hi';
import { getExercise, getExerciseRecords, getExerciseHistory } from '../api/api';

export default function ExerciseDetail() {
  const { id } = useParams();
  const [exercise, setExercise] = useState(null);
  const [records, setRecords] = useState([]);
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, [id]);

  const loadData = async () => {
    try {
      const [exRes, recRes, histRes] = await Promise.all([
        getExercise(id),
        getExerciseRecords(id),
        getExerciseHistory(id),
      ]);
      setExercise(exRes.data);
      setRecords(recRes.data);
      setHistory(histRes.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (d) => new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });

  if (loading) {
    return (
      <div className="space-y-4 animate-fade-in">
        <div className="skeleton h-8 w-48 rounded-lg" />
        <div className="skeleton h-32 rounded-2xl" />
        <div className="skeleton h-48 rounded-2xl" />
      </div>
    );
  }

  if (!exercise) return <p className="text-sl-textMuted text-center py-12">Exercise not found</p>;

  return (
    <div className="space-y-5 animate-fade-in">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Link to="/exercises" className="btn-icon" id="back-exercises">
          <HiArrowLeft className="text-lg" />
        </Link>
        <div>
          <h1 className="text-xl font-extrabold text-sl-text">{exercise.name}</h1>
          <p className="text-xs text-sl-textMuted">{exercise.category} • {exercise.primaryMuscles?.join(', ')}</p>
        </div>
      </div>

      {/* Info */}
      <div className="card p-4 space-y-3">
        <div>
          <p className="section-title mb-1">Primary Muscles</p>
          <div className="flex gap-1.5 flex-wrap">
            {exercise.primaryMuscles?.map(m => <span key={m} className="badge-green">{m}</span>)}
          </div>
        </div>
        {exercise.secondaryMuscles?.length > 0 && (
          <div>
            <p className="section-title mb-1">Secondary Muscles</p>
            <div className="flex gap-1.5 flex-wrap">
              {exercise.secondaryMuscles.map(m => <span key={m} className="badge-muted">{m}</span>)}
            </div>
          </div>
        )}
        {exercise.equipment && (
          <div>
            <p className="section-title mb-1">Equipment</p>
            <p className="text-sm text-sl-textSecondary">{exercise.equipment}</p>
          </div>
        )}
        {exercise.instructions && (
          <div>
            <p className="section-title mb-1">Instructions</p>
            <p className="text-sm text-sl-textSecondary leading-relaxed">{exercise.instructions}</p>
          </div>
        )}
      </div>

      {/* Personal Records */}
      {records.length > 0 && (
        <div>
          <h2 className="section-title mb-3 flex items-center gap-1">
            🏆 Personal Records
          </h2>
          <div className="card overflow-hidden">
            <div className="grid grid-cols-4 gap-2 p-3 bg-sl-surface text-[10px] font-semibold text-sl-textMuted uppercase">
              <span>Reps</span>
              <span>Weight</span>
              <span>Est. 1RM</span>
              <span>Date</span>
            </div>
            {records.map((r, i) => (
              <div key={i} className="grid grid-cols-4 gap-2 p-3 border-t border-sl-border text-sm">
                <span className="font-mono font-semibold text-sl-green">{r.reps}</span>
                <span className="font-mono font-semibold text-sl-text">{r.weight} kg</span>
                <span className="font-mono text-sl-textSecondary">{r.estimated1rm?.toFixed(1)} kg</span>
                <span className="text-xs text-sl-textMuted">{formatDate(r.date)}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* History */}
      {history.length > 0 && (
        <div>
          <h2 className="section-title mb-3">📊 Recent History</h2>
          <div className="space-y-2">
            {history.map((h, i) => (
              <div key={i} className="card p-3">
                <div className="flex items-center justify-between mb-2">
                  <p className="text-xs font-semibold text-sl-text">{h.workoutName || 'Workout'}</p>
                  <p className="text-xs text-sl-textMuted">{formatDate(h.date)}</p>
                </div>
                <div className="space-y-1">
                  {h.sets?.map((s, j) => (
                    <div key={j} className="flex gap-3 text-xs text-sl-textSecondary font-mono">
                      <span className="text-sl-textMuted w-6">#{s.setNumber || j+1}</span>
                      <span className="font-semibold text-sl-text">{s.weight}kg</span>
                      <span>× {s.reps}</span>
                      {s.rpe && <span className="text-sl-amber">RPE {s.rpe}</span>}
                      {s.completed && <span className="text-sl-green">✓</span>}
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
