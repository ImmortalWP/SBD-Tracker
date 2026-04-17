import { useState, useEffect } from 'react';
import { getPRs, getAnalytics, getCached } from '../api/sessions';
import StatsPanel from '../components/StatsPanel';
import { HiTrendingUp, HiCollection, HiCube } from 'react-icons/hi';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';

export default function Analytics() {
  const [prs, setPrs] = useState({ Squat: 0, Bench: 0, Deadlift: 0 });
  const [analytics, setAnalytics] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Show cached data instantly
    const cachedPrs = getCached('/sessions/stats/prs');
    const cachedAnalytics = getCached('/sessions/stats/analytics');
    let hasCached = false;
    if (cachedPrs) setPrs(cachedPrs);
    if (cachedAnalytics) {
      setAnalytics(cachedAnalytics);
      hasCached = true;
      setLoading(false);
    }

    // Fetch fresh in background
    loadData(hasCached);
  }, []);

  const loadData = async (hasCached) => {
    if (!hasCached) setLoading(true);
    try {
      const [prRes, anRes] = await Promise.all([getPRs(), getAnalytics()]);
      setPrs(prRes.data);
      setAnalytics(anRes.data);
    } catch (err) {
      console.error('Failed to load analytics:', err);
    } finally {
      setLoading(false);
    }
  };

  const formatVolume = (v) => {
    if (v >= 1000) return `${(v / 1000).toFixed(1)}k`;
    return v.toString();
  };

  return (
    <div className="space-y-8 animate-fade-in">
      <div>
        <h1 className="text-2xl font-extrabold text-gym-50 tracking-tight">
          Analytics
        </h1>
        <p className="text-gym-400 text-sm mt-1">
          Track your progress across blocks.
        </p>
      </div>

      {/* PRs */}
      <div>
        <h2 className="text-sm font-semibold uppercase tracking-wider text-gym-400 mb-3">
          🏆 Personal Records
        </h2>
        <StatsPanel prs={prs} loading={loading} />
      </div>

      {/* Summary cards */}
      {analytics && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="card p-5">
            <div className="flex items-center gap-2 mb-2">
              <span className="text-xl">🏋️</span>
              <span className="text-xs font-semibold uppercase tracking-wider text-gym-400">
                Total Volume
              </span>
            </div>
            <span className="text-3xl font-extrabold text-gym-50">
              {formatVolume(Object.values(analytics.volume || {}).reduce((a, b) => a + b, 0))} kg
            </span>
          </div>
          <div className="card p-5">
            <div className="flex items-center gap-2 mb-2">
              <HiCollection className="text-accent-blue text-lg" />
              <span className="text-xs font-semibold uppercase tracking-wider text-gym-400">
                Total Sessions
              </span>
            </div>
            <span className="text-3xl font-extrabold text-gym-50">
              {analytics.totalSessions}
            </span>
          </div>

          <div className="card p-5">
            <div className="flex items-center gap-2 mb-2">
              <HiCube className="text-accent-amber text-lg" />
              <span className="text-xs font-semibold uppercase tracking-wider text-gym-400">
                Training Blocks
              </span>
            </div>
            <span className="text-3xl font-extrabold text-gym-50">
              {analytics.totalBlocks}
            </span>
          </div>

          <div className="card p-5">
            <div className="flex items-center gap-2 mb-2">
              <HiTrendingUp className="text-accent-green text-lg" />
              <span className="text-xs font-semibold uppercase tracking-wider text-gym-400">
                Avg Sessions/Block
              </span>
            </div>
            <span className="text-3xl font-extrabold text-gym-50">
              {analytics.totalBlocks > 0
                ? (analytics.totalSessions / analytics.totalBlocks).toFixed(1)
                : '—'}
            </span>
          </div>
        </div>
      )}

      {/* Volume breakdown */}
      {analytics && (
        <div>
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gym-400 mb-3">
            📊 Total Volume (kg)
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {Object.entries(analytics.volume || {}).map(([lift, vol]) => {
              const colors = {
                Squat: 'accent-red',
                Bench: 'accent-blue',
                Deadlift: 'accent-amber',
              };
              const color = colors[lift] || 'gym-400';

              return (
                <div key={lift} className="card p-5">
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-sm font-semibold text-gym-200">{lift}</span>
                    <span className={`text-xs font-bold text-${color}`}>
                      {formatVolume(vol)} kg
                    </span>
                  </div>
                  {/* Mini bar */}
                  <div className="h-2 rounded-full bg-gym-800 overflow-hidden">
                    <div
                      className={`h-full rounded-full bg-${color} transition-all duration-700`}
                      style={{
                        width: `${Math.min(
                          (vol / Math.max(...Object.values(analytics.volume), 1)) * 100,
                          100
                        )}%`,
                      }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Sessions per Block */}
      {analytics && analytics.sessionsPerBlock?.length > 0 && (
        <div>
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gym-400 mb-3">
            📅 Sessions per Block
          </h2>
          <div className="card p-5">
            <div className="space-y-3">
              {analytics.sessionsPerBlock.map((item) => (
                <div key={item._id} className="flex items-center gap-3">
                  <span className="badge-block text-xs min-w-[80px] justify-center">
                    Block {item._id}
                  </span>
                  <div className="flex-1 h-3 rounded-full bg-gym-800 overflow-hidden">
                    <div
                      className="h-full rounded-full bg-gradient-to-r from-accent-red to-accent-amber transition-all duration-700"
                      style={{
                        width: `${Math.min(
                          (item.count /
                            Math.max(
                              ...analytics.sessionsPerBlock.map((s) => s.count),
                              1
                            )) *
                            100,
                          100
                        )}%`,
                      }}
                    />
                  </div>
                  <span className="text-sm font-mono font-semibold text-gym-300 min-w-[30px] text-right">
                    {item.count}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Volume Progression Chart */}
      {analytics && analytics.volumeProgression?.length > 0 && (
        <div>
          <h2 className="text-sm font-semibold uppercase tracking-wider text-gym-400 mb-3">
            📈 Volume Progression
          </h2>
          <div className="card p-5 h-80">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={analytics.volumeProgression} margin={{ top: 5, right: 20, bottom: 5, left: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#3f3f46" vertical={false} />
                <XAxis dataKey="block" stroke="#a1a1aa" tickFormatter={(val) => val.replace('Block ', 'B')} />
                <YAxis stroke="#a1a1aa" tickFormatter={formatVolume} width={50} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#18181b', borderColor: '#3f3f46', borderRadius: '8px' }}
                  itemStyle={{ fontSize: '13px', fontWeight: 'bold' }}
                />
                <Legend iconType="circle" wrapperStyle={{ fontSize: '12px', paddingTop: '10px' }} />
                <Line type="monotone" dataKey="Squat" stroke="#ef4444" strokeWidth={3} dot={{ r: 4 }} activeDot={{ r: 6 }} />
                <Line type="monotone" dataKey="Bench" stroke="#3b82f6" strokeWidth={3} dot={{ r: 4 }} activeDot={{ r: 6 }} />
                <Line type="monotone" dataKey="Deadlift" stroke="#f59e0b" strokeWidth={3} dot={{ r: 4 }} activeDot={{ r: 6 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}
    </div>
  );
}
