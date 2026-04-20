import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { HiChevronRight, HiLightningBolt } from 'react-icons/hi';
import { getPrograms } from '../api/api';

const DIFFICULTY_COLORS = { Beginner: 'badge-green', Intermediate: 'badge-blue', Advanced: 'badge-red' };
const CATEGORY_ICONS = {
  Strength: '🏋️', Hypertrophy: '💪', Powerlifting: '🔴', Bodybuilding: '🏆',
  General: '⚡', Powerbuilding: '🔥', Beginner: '🌱', Athletic: '🏃',
};

export default function Programs() {
  const [programs, setPrograms] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadPrograms();
  }, []);

  const loadPrograms = async () => {
    try {
      const res = await getPrograms();
      setPrograms(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-5 animate-fade-in">
      <div>
        <h1 className="text-2xl font-extrabold text-sl-text tracking-tight">Programs</h1>
        <p className="text-sl-textMuted text-sm">Evidence-based training programs</p>
      </div>

      {loading ? (
        <div className="space-y-3">
          {[1,2,3].map(i => <div key={i} className="skeleton h-28 rounded-2xl" />)}
        </div>
      ) : programs.length > 0 ? (
        <div className="space-y-3">
          {programs.map(p => (
            <Link to={`/programs/${p._id}`} key={p._id} className="card card-hover p-4 flex items-start gap-3 block" id={`prog-${p._id}`}>
              <div className="w-12 h-12 rounded-xl bg-sl-green/10 flex items-center justify-center text-2xl shrink-0">
                {CATEGORY_ICONS[p.category] || '📋'}
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="text-sm font-bold text-sl-text">{p.name}</h3>
                <p className="text-xs text-sl-textMuted mt-0.5 line-clamp-2">{p.description}</p>
                <div className="flex items-center gap-2 mt-2">
                  <span className={DIFFICULTY_COLORS[p.difficulty] || 'badge-muted'}>{p.difficulty}</span>
                  <span className="text-xs text-sl-textMuted">{p.weeks} weeks • {p.daysPerWeek} days/week</span>
                </div>
              </div>
              <HiChevronRight className="text-sl-textMuted mt-1 shrink-0" />
            </Link>
          ))}
        </div>
      ) : (
        <div className="card p-8 text-center">
          <p className="text-4xl mb-3">📋</p>
          <p className="text-sl-textMuted text-sm">No programs available</p>
        </div>
      )}
    </div>
  );
}
