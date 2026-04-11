import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { HiPlusCircle, HiArrowRight } from 'react-icons/hi';
import { getSessions, getPRs } from '../api/sessions';
import StatsPanel from '../components/StatsPanel';
import SessionCard from '../components/SessionCard';

export default function Dashboard() {
  const [sessions, setSessions] = useState([]);
  const [prs, setPrs] = useState({ Squat: 0, Bench: 0, Deadlift: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const [sessRes, prRes] = await Promise.all([getSessions(), getPRs()]);
      setSessions(sessRes.data);
      setPrs(prRes.data);
    } catch (err) {
      console.error('Failed to load dashboard data:', err);
    } finally {
      setLoading(false);
    }
  };

  const recentSessions = sessions.slice(0, 3);

  const handleDelete = (id) => {
    setSessions(sessions.filter((s) => s._id !== id));
  };

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Hero */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-gym-50 tracking-tight">
            Training Dashboard
          </h1>
          <p className="text-gym-400 text-sm mt-1">
            {sessions.length} session{sessions.length !== 1 ? 's' : ''} logged
          </p>
        </div>
        <Link to="/add" className="btn-primary flex items-center gap-2" id="dashboard-add-session">
          <HiPlusCircle className="text-lg" />
          Log Session
        </Link>
      </div>

      {/* PR Cards */}
      <div>
        <h2 className="text-sm font-semibold uppercase tracking-wider text-gym-400 mb-3">
          Personal Records
        </h2>
        <StatsPanel prs={prs} loading={loading} />
      </div>

      {/* Recent Sessions */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gym-400">
            Recent Sessions
          </h2>
          {sessions.length > 3 && (
            <Link
              to="/sessions"
              className="btn-ghost text-xs flex items-center gap-1"
              id="view-all-sessions"
            >
              View all <HiArrowRight className="text-sm" />
            </Link>
          )}
        </div>

        {loading ? (
          <div className="grid gap-4">
            {[1, 2, 3].map((i) => (
              <div key={i} className="card p-5 animate-pulse">
                <div className="flex gap-3 mb-4">
                  <div className="h-6 w-20 bg-gym-800 rounded-lg" />
                  <div className="h-6 w-16 bg-gym-800 rounded-md" />
                </div>
                <div className="space-y-2">
                  <div className="h-4 w-32 bg-gym-800 rounded" />
                  <div className="h-4 w-24 bg-gym-800 rounded" />
                </div>
              </div>
            ))}
          </div>
        ) : recentSessions.length > 0 ? (
          <div className="grid gap-4">
            {recentSessions.map((session) => (
              <SessionCard
                key={session._id}
                session={session}
                onDelete={handleDelete}
              />
            ))}
          </div>
        ) : (
          <div className="card p-8 text-center">
            <div className="text-4xl mb-3">🏋️</div>
            <p className="text-gym-400 text-sm mb-4">No sessions logged yet.</p>
            <Link to="/add" className="btn-primary inline-flex items-center gap-2" id="empty-add-session">
              <HiPlusCircle className="text-lg" />
              Log Your First Session
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
