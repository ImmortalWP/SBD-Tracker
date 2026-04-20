import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { HiPlus, HiChevronRight, HiLightningBolt, HiFire, HiTrendingUp, HiClock } from 'react-icons/hi';
import { getStatsOverview, getWorkouts, getMuscleMap } from '../api/api';
import { useAuth } from '../context/AuthContext';
import MuscleMap from '../components/MuscleMap';

export default function Home() {
  const { user } = useAuth();
  const [stats, setStats] = useState(null);
  const [recentWorkouts, setRecentWorkouts] = useState([]);
  const [muscleData, setMuscleData] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [statsRes, workoutsRes, muscleRes] = await Promise.all([
        getStatsOverview(),
        getWorkouts({ limit: 3 }),
        getMuscleMap(7),
      ]);
      setStats(statsRes.data);
      setRecentWorkouts(workoutsRes.data.workouts || []);
      setMuscleData(muscleRes.data);
    } catch (err) {
      console.error('Failed to load home data:', err);
    } finally {
      setLoading(false);
    }
  };

  const formatDuration = (seconds) => {
    if (!seconds) return '0m';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    return h > 0 ? `${h}h ${m}m` : `${m}m`;
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

  const formatVolume = (v) => {
    if (!v) return '0';
    if (v >= 1000) return `${(v / 1000).toFixed(1)}k`;
    return v.toLocaleString();
  };

  return (
    <div className="space-y-5 animate-fade-in pb-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sl-textMuted text-sm">Welcome back</p>
          <h1 className="text-2xl font-extrabold text-sl-text tracking-tight capitalize">
            {user?.username || 'Lifter'} 💪
          </h1>
        </div>
        <Link to="/profile" className="w-10 h-10 rounded-full bg-sl-green/15 flex items-center justify-center text-sl-green font-bold text-sm" id="home-profile">
          {(user?.username || 'U')[0].toUpperCase()}
        </Link>
      </div>

      {/* Start Workout CTA */}
      <Link to="/workout" className="block" id="start-workout-cta">
        <div className="card p-5 bg-gradient-to-r from-sl-green/10 to-sl-green/5 border-sl-green/20 hover:border-sl-green/40 transition-all group">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl bg-sl-green flex items-center justify-center shadow-glow group-hover:shadow-glowStrong transition-shadow">
              <HiPlus className="text-2xl text-white" />
            </div>
            <div className="flex-1">
              <h2 className="text-lg font-bold text-sl-text">Start Workout</h2>
              <p className="text-sm text-sl-textSecondary">Start an empty workout</p>
            </div>
            <HiChevronRight className="text-xl text-sl-textMuted group-hover:text-sl-green transition-colors" />
          </div>
        </div>
      </Link>

      {/* Stats Grid */}
      {loading ? (
        <div className="grid grid-cols-2 gap-3">
          {[1,2,3,4].map(i => <div key={i} className="skeleton h-24 rounded-2xl" />)}
        </div>
      ) : stats && (
        <div className="grid grid-cols-2 gap-3">
          <div className="card p-4">
            <div className="flex items-center gap-2 mb-2">
              <HiFire className="text-sl-amber" />
              <span className="text-xs font-semibold text-sl-textMuted">Streak</span>
            </div>
            <p className="text-2xl font-extrabold text-sl-text">{stats.streak || 0}</p>
            <p className="text-xs text-sl-textMuted">days</p>
          </div>

          <div className="card p-4">
            <div className="flex items-center gap-2 mb-2">
              <HiLightningBolt className="text-sl-green" />
              <span className="text-xs font-semibold text-sl-textMuted">This Week</span>
            </div>
            <p className="text-2xl font-extrabold text-sl-text">{stats.thisWeekWorkouts || 0}</p>
            <p className="text-xs text-sl-textMuted">workouts</p>
          </div>

          <div className="card p-4">
            <div className="flex items-center gap-2 mb-2">
              <HiTrendingUp className="text-sl-blue" />
              <span className="text-xs font-semibold text-sl-textMuted">Week Volume</span>
            </div>
            <p className="text-2xl font-extrabold text-sl-text">{formatVolume(stats.weekVolume)}</p>
            <p className="text-xs text-sl-textMuted">kg</p>
          </div>

          <div className="card p-4">
            <div className="flex items-center gap-2 mb-2">
              <HiClock className="text-sl-purple" />
              <span className="text-xs font-semibold text-sl-textMuted">Total</span>
            </div>
            <p className="text-2xl font-extrabold text-sl-text">{stats.totalWorkouts || 0}</p>
            <p className="text-xs text-sl-textMuted">workouts</p>
          </div>
        </div>
      )}

      {/* Muscle Map */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h2 className="section-title">Muscles Trained (7 days)</h2>
          <Link to="/stats" className="text-xs text-sl-green font-semibold">See Stats →</Link>
        </div>
        <MuscleMap data={muscleData} />
      </div>

      {/* Recent Workouts */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h2 className="section-title">Recent Workouts</h2>
          <Link to="/history" className="text-xs text-sl-green font-semibold">View All →</Link>
        </div>

        {recentWorkouts.length > 0 ? (
          <div className="space-y-2">
            {recentWorkouts.map(w => (
              <Link to={`/workout/${w._id}`} key={w._id} className="card card-hover p-4 flex items-center gap-3 block" id={`recent-${w._id}`}>
                <div className="w-10 h-10 rounded-xl bg-sl-green/10 flex items-center justify-center text-sl-green">
                  <HiLightningBolt />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-sl-text truncate">{w.name || 'Workout'}</p>
                  <p className="text-xs text-sl-textMuted">
                    {formatDate(w.date)} • {w.exercises?.length || 0} exercises • {formatVolume(w.totalVolume)} kg
                  </p>
                </div>
                {w.duration > 0 && (
                  <span className="text-xs text-sl-textMuted font-mono">{formatDuration(w.duration)}</span>
                )}
              </Link>
            ))}
          </div>
        ) : !loading && (
          <div className="card p-8 text-center">
            <p className="text-4xl mb-3">🏋️</p>
            <p className="text-sl-textMuted text-sm mb-4">No workouts yet. Start your first one!</p>
            <Link to="/workout" className="btn-primary inline-flex items-center gap-2" id="first-workout">
              <HiPlus /> Start Workout
            </Link>
          </div>
        )}
      </div>

      {/* Quick Links */}
      <div className="grid grid-cols-2 gap-3">
        <Link to="/programs" className="card card-hover p-4 text-center" id="link-programs">
          <p className="text-2xl mb-1">📋</p>
          <p className="text-sm font-semibold text-sl-text">Programs</p>
          <p className="text-xs text-sl-textMuted">Training plans</p>
        </Link>
        <Link to="/calculators" className="card card-hover p-4 text-center" id="link-calculators">
          <p className="text-2xl mb-1">🧮</p>
          <p className="text-sm font-semibold text-sl-text">Calculators</p>
          <p className="text-xs text-sl-textMuted">1RM, Plates</p>
        </Link>
      </div>
    </div>
  );
}
