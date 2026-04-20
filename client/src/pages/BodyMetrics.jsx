import { useState, useEffect } from 'react';
import { HiPlus, HiTrash, HiScale } from 'react-icons/hi';
import { getBodyMetrics, createBodyMetric, deleteBodyMetric } from '../api/api';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

export default function BodyMetrics() {
  const [metrics, setMetrics] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [weight, setWeight] = useState('');
  const [bodyFat, setBodyFat] = useState('');
  const [notes, setNotes] = useState('');

  useEffect(() => { loadMetrics(); }, []);

  const loadMetrics = async () => {
    try {
      const res = await getBodyMetrics();
      setMetrics(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!weight) return;
    try {
      await createBodyMetric({
        weight: Number(weight),
        bodyFat: bodyFat ? Number(bodyFat) : undefined,
        notes,
        date: new Date(),
      });
      setWeight(''); setBodyFat(''); setNotes('');
      setShowForm(false);
      loadMetrics();
    } catch (err) {
      console.error(err);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this entry?')) return;
    try {
      await deleteBodyMetric(id);
      setMetrics(prev => prev.filter(m => m._id !== id));
    } catch (err) {
      console.error(err);
    }
  };

  const chartData = [...metrics].reverse().map(m => ({
    date: new Date(m.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
    weight: m.weight,
    bodyFat: m.bodyFat,
  }));

  const latest = metrics[0];

  return (
    <div className="space-y-5 animate-fade-in">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-extrabold text-sl-text tracking-tight">Body</h1>
        <button onClick={() => setShowForm(!showForm)} className="btn-primary text-xs flex items-center gap-1" id="add-body">
          <HiPlus /> Log
        </button>
      </div>

      {/* Current Stats */}
      {latest && (
        <div className="grid grid-cols-2 gap-3">
          <div className="card p-4">
            <p className="text-xs text-sl-textMuted mb-1">Current Weight</p>
            <p className="text-2xl font-extrabold text-sl-text">{latest.weight} <span className="text-sm text-sl-textMuted">kg</span></p>
          </div>
          {latest.bodyFat && (
            <div className="card p-4">
              <p className="text-xs text-sl-textMuted mb-1">Body Fat</p>
              <p className="text-2xl font-extrabold text-sl-text">{latest.bodyFat}<span className="text-sm text-sl-textMuted">%</span></p>
            </div>
          )}
        </div>
      )}

      {/* Add Form */}
      {showForm && (
        <div className="card p-4 space-y-3 animate-slide-down">
          <h2 className="text-sm font-bold text-sl-text">Log Body Metrics</h2>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="section-title block mb-1">Weight (kg)</label>
              <input type="number" value={weight} onChange={e => setWeight(e.target.value)}
                placeholder="75" className="input-field" id="body-weight" step="0.1" />
            </div>
            <div>
              <label className="section-title block mb-1">Body Fat %</label>
              <input type="number" value={bodyFat} onChange={e => setBodyFat(e.target.value)}
                placeholder="15" className="input-field" id="body-fat" step="0.1" />
            </div>
          </div>
          <input type="text" value={notes} onChange={e => setNotes(e.target.value)}
            placeholder="Notes (optional)" className="input-field" />
          <div className="flex gap-2">
            <button onClick={handleSave} className="btn-primary flex-1" id="save-body">Save</button>
            <button onClick={() => setShowForm(false)} className="btn-secondary">Cancel</button>
          </div>
        </div>
      )}

      {/* Weight Chart */}
      {chartData.length > 1 && (
        <div>
          <h2 className="section-title mb-3">📈 Weight Trend</h2>
          <div className="card p-4 h-48">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData} margin={{ top: 5, right: 10, bottom: 5, left: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a2a" vertical={false} />
                <XAxis dataKey="date" stroke="#666" tick={{ fontSize: 10 }} />
                <YAxis stroke="#666" tick={{ fontSize: 10 }} width={35} domain={['auto', 'auto']} />
                <Tooltip contentStyle={{ backgroundColor: '#1a1a1a', borderColor: '#2a2a2a', borderRadius: '12px', fontSize: '12px' }} />
                <Line type="monotone" dataKey="weight" stroke="#4CAF50" strokeWidth={2.5} dot={{ r: 3, fill: '#4CAF50' }} name="Weight (kg)" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* History */}
      <div>
        <h2 className="section-title mb-3">History</h2>
        {loading ? (
          <div className="space-y-2">{[1,2,3].map(i => <div key={i} className="skeleton h-16 rounded-xl" />)}</div>
        ) : metrics.length > 0 ? (
          <div className="space-y-2">
            {metrics.map(m => (
              <div key={m._id} className="card p-3 flex items-center gap-3">
                <div className="w-9 h-9 rounded-lg bg-sl-green/10 flex items-center justify-center">
                  <HiScale className="text-sl-green" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-3">
                    <span className="text-sm font-bold text-sl-text">{m.weight} kg</span>
                    {m.bodyFat && <span className="text-xs text-sl-textMuted">{m.bodyFat}% BF</span>}
                  </div>
                  <p className="text-xs text-sl-textMuted">
                    {new Date(m.date).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
                    {m.notes && ` • ${m.notes}`}
                  </p>
                </div>
                <button onClick={() => handleDelete(m._id)} className="btn-icon w-8 h-8">
                  <HiTrash className="text-sm text-sl-textMuted" />
                </button>
              </div>
            ))}
          </div>
        ) : (
          <div className="card p-8 text-center">
            <p className="text-sl-textMuted text-sm">No body metrics logged yet</p>
          </div>
        )}
      </div>
    </div>
  );
}
