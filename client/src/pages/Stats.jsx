import { useState, useEffect } from 'react';
import { HiTrendingUp, HiLightningBolt, HiClock, HiFire } from 'react-icons/hi';
import { getStatsOverview, getPersonalRecords, getVolumeStats, getMuscleMap } from '../api/api';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import MuscleMap from '../components/MuscleMap';

export default function Stats() {
  const [stats, setStats] = useState(null);
  const [prs, setPrs] = useState({});
  const [volumeData, setVolumeData] = useState([]);
  const [muscleData, setMuscleData] = useState({});
  const [loading, setLoading] = useState(true);
  const [muscleRange, setMuscleRange] = useState(7);
  const [volumePeriod, setVolumePeriod] = useState('weekly');
  const [activeSection, setActiveSection] = useState('overview');

  useEffect(() => { loadData(); }, []);

  useEffect(() => {
    getMuscleMap(muscleRange).then(r => setMuscleData(r.data)).catch(console.error);
  }, [muscleRange]);

  useEffect(() => {
    getVolumeStats(volumePeriod).then(r => setVolumeData(r.data)).catch(console.error);
  }, [volumePeriod]);

  const loadData = async () => {
    try {
      const [statsRes, prsRes, volRes, muscleRes] = await Promise.all([
        getStatsOverview(), getPersonalRecords(), getVolumeStats('weekly'), getMuscleMap(7),
      ]);
      setStats(statsRes.data);
      setPrs(prsRes.data);
      setVolumeData(volRes.data);
      setMuscleData(muscleRes.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const formatVolume = (v) => v >= 1000 ? `${(v / 1000).toFixed(1)}k` : (v || 0).toString();
  const formatDuration = (s) => {
    if (!s) return '0h';
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    return h > 0 ? `${h}h ${m}m` : `${m}m`;
  };

  const sections = [
    { id: 'overview', label: 'Overview' },
    { id: 'muscles', label: 'Muscles' },
    { id: 'volume', label: 'Volume' },
    { id: 'records', label: 'Records' },
  ];

  return (
    <div className="space-y-5 animate-fade-in">
      <h1 className="text-2xl font-extrabold text-sl-text tracking-tight">Statistics</h1>

      {/* Section tabs */}
      <div className="flex gap-1 bg-sl-card rounded-xl p-1">
        {sections.map(s => (
          <button key={s.id} onClick={() => setActiveSection(s.id)}
            className={`flex-1 py-2 rounded-lg text-xs font-semibold transition-all ${
              activeSection === s.id ? 'bg-sl-green text-white' : 'text-sl-textMuted'
            }`}>{s.label}</button>
        ))}
      </div>

      {loading ? (
        <div className="space-y-3">{[1,2,3].map(i => <div key={i} className="skeleton h-24 rounded-2xl" />)}</div>
      ) : (
        <>
          {/* OVERVIEW */}
          {activeSection === 'overview' && stats && (
            <div className="space-y-4 animate-fade-in">
              <div className="grid grid-cols-2 gap-3">
                <div className="card p-4">
                  <div className="flex items-center gap-2 mb-1">
                    <HiLightningBolt className="text-sl-green" />
                    <span className="text-[10px] font-semibold text-sl-textMuted uppercase">Total Workouts</span>
                  </div>
                  <p className="text-2xl font-extrabold">{stats.totalWorkouts}</p>
                </div>
                <div className="card p-4">
                  <div className="flex items-center gap-2 mb-1">
                    <HiFire className="text-sl-amber" />
                    <span className="text-[10px] font-semibold text-sl-textMuted uppercase">Streak</span>
                  </div>
                  <p className="text-2xl font-extrabold">{stats.streak} <span className="text-sm text-sl-textMuted">days</span></p>
                </div>
                <div className="card p-4">
                  <div className="flex items-center gap-2 mb-1">
                    <HiTrendingUp className="text-sl-blue" />
                    <span className="text-[10px] font-semibold text-sl-textMuted uppercase">Total Volume</span>
                  </div>
                  <p className="text-2xl font-extrabold">{formatVolume(stats.totalVolume)} <span className="text-sm text-sl-textMuted">kg</span></p>
                </div>
                <div className="card p-4">
                  <div className="flex items-center gap-2 mb-1">
                    <HiClock className="text-sl-purple" />
                    <span className="text-[10px] font-semibold text-sl-textMuted uppercase">Total Time</span>
                  </div>
                  <p className="text-2xl font-extrabold">{formatDuration(stats.totalDuration)}</p>
                </div>
              </div>
              <div className="card p-4">
                <p className="section-title mb-1">This Week</p>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-sl-textSecondary">{stats.thisWeekWorkouts} workouts</span>
                  <span className="text-sm font-semibold text-sl-green">{formatVolume(stats.weekVolume)} kg volume</span>
                </div>
              </div>
            </div>
          )}

          {/* MUSCLES */}
          {activeSection === 'muscles' && (
            <div className="space-y-4 animate-fade-in">
              <div className="flex gap-2">
                {[7, 14, 30].map(d => (
                  <button key={d} onClick={() => setMuscleRange(d)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold ${
                      muscleRange === d ? 'bg-sl-green text-white' : 'bg-sl-card text-sl-textMuted'
                    }`}>{d} days</button>
                ))}
              </div>
              <MuscleMap data={muscleData} />
            </div>
          )}

          {/* VOLUME */}
          {activeSection === 'volume' && (
            <div className="space-y-4 animate-fade-in">
              <div className="flex gap-2">
                {['daily', 'weekly', 'monthly'].map(p => (
                  <button key={p} onClick={() => setVolumePeriod(p)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold capitalize ${
                      volumePeriod === p ? 'bg-sl-green text-white' : 'bg-sl-card text-sl-textMuted'
                    }`}>{p}</button>
                ))}
              </div>
              {volumeData.length > 0 ? (
                <div className="card p-4 h-64">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={volumeData} margin={{ top: 5, right: 10, bottom: 5, left: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#2a2a2a" vertical={false} />
                      <XAxis dataKey="_id" stroke="#666" tick={{ fontSize: 10 }}
                        tickFormatter={v => v?.replace(/^\d{4}-/, '').substring(0, 5)} />
                      <YAxis stroke="#666" tick={{ fontSize: 10 }} tickFormatter={formatVolume} width={40} />
                      <Tooltip contentStyle={{ backgroundColor: '#1a1a1a', borderColor: '#2a2a2a', borderRadius: '12px', fontSize: '12px' }} />
                      <Line type="monotone" dataKey="totalVolume" stroke="#4CAF50" strokeWidth={2.5} dot={{ r: 3, fill: '#4CAF50' }} name="Volume (kg)" />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <div className="card p-8 text-center text-sl-textMuted text-sm">No volume data yet</div>
              )}
              {volumeData.length > 0 && (
                <div className="card p-4">
                  <p className="section-title mb-2">Workout Frequency</p>
                  <div className="card p-4 h-48">
                    <ResponsiveContainer width="100%" height="100%">
                      <LineChart data={volumeData} margin={{ top: 5, right: 10, bottom: 5, left: 0 }}>
                        <CartesianGrid strokeDasharray="3 3" stroke="#2a2a2a" vertical={false} />
                        <XAxis dataKey="_id" stroke="#666" tick={{ fontSize: 10 }}
                          tickFormatter={v => v?.replace(/^\d{4}-/, '').substring(0, 5)} />
                        <YAxis stroke="#666" tick={{ fontSize: 10 }} width={25} />
                        <Tooltip contentStyle={{ backgroundColor: '#1a1a1a', borderColor: '#2a2a2a', borderRadius: '12px', fontSize: '12px' }} />
                        <Line type="monotone" dataKey="workoutCount" stroke="#42A5F5" strokeWidth={2.5} dot={{ r: 3, fill: '#42A5F5' }} name="Workouts" />
                      </LineChart>
                    </ResponsiveContainer>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* RECORDS */}
          {activeSection === 'records' && (
            <div className="space-y-3 animate-fade-in">
              {Object.keys(prs).length > 0 ? (
                Object.entries(prs).map(([name, data]) => (
                  <div key={name} className="card p-4">
                    <h3 className="text-sm font-bold text-sl-text mb-2">{name}</h3>
                    <div className="grid grid-cols-3 gap-2">
                      {data.records?.slice(0, 6).map((r, i) => (
                        <div key={i} className="bg-sl-surface rounded-lg p-2 text-center">
                          <p className="text-[10px] text-sl-textMuted">{r.reps}RM</p>
                          <p className="text-sm font-bold text-sl-green">{r.weight}<span className="text-[10px] text-sl-textMuted">kg</span></p>
                        </div>
                      ))}
                    </div>
                  </div>
                ))
              ) : (
                <div className="card p-8 text-center">
                  <p className="text-4xl mb-3">🏆</p>
                  <p className="text-sl-textMuted text-sm">Complete workouts to track PRs</p>
                </div>
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}
