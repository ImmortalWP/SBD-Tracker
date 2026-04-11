import { useState, useEffect } from 'react';
import { getSessions } from '../api/sessions';
import SessionCard from '../components/SessionCard';
import SearchBar from '../components/SearchBar';

export default function Sessions() {
  const [sessions, setSessions] = useState([]);
  const [blockFilter, setBlockFilter] = useState('');
  const [dayFilter, setDayFilter] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadSessions();
  }, [blockFilter, dayFilter]);

  const loadSessions = async () => {
    setLoading(true);
    try {
      const params = {};
      if (blockFilter) params.block = blockFilter;
      if (dayFilter) params.day = dayFilter;

      const res = await getSessions(params);
      setSessions(res.data);
    } catch (err) {
      console.error('Failed to load sessions:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = (id) => {
    setSessions(sessions.filter((s) => s._id !== id));
  };

  const clearFilters = () => {
    setBlockFilter('');
    setDayFilter('');
  };

  // Group sessions by block
  const grouped = sessions.reduce((acc, session) => {
    const key = `Block ${session.block}`;
    if (!acc[key]) acc[key] = [];
    acc[key].push(session);
    return acc;
  }, {});

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold text-gym-50 tracking-tight">
            Training Log
          </h1>
          <p className="text-gym-400 text-sm mt-1">
            {sessions.length} session{sessions.length !== 1 ? 's' : ''} found
          </p>
        </div>
        <SearchBar
          blockFilter={blockFilter}
          dayFilter={dayFilter}
          onBlockChange={setBlockFilter}
          onDayChange={setDayFilter}
          onClear={clearFilters}
        />
      </div>

      {loading ? (
        <div className="space-y-4">
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
      ) : Object.keys(grouped).length > 0 ? (
        <div className="space-y-8">
          {Object.entries(grouped).map(([blockName, blockSessions]) => (
            <div key={blockName}>
              <div className="flex items-center gap-3 mb-4">
                <h2 className="text-lg font-bold text-gym-100">{blockName}</h2>
                <div className="flex-1 h-px bg-gym-800" />
                <span className="text-xs text-gym-500">
                  {blockSessions.length} session{blockSessions.length !== 1 ? 's' : ''}
                </span>
              </div>
              <div className="grid gap-4">
                {blockSessions.map((session) => (
                  <SessionCard
                    key={session._id}
                    session={session}
                    onDelete={handleDelete}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="card p-8 text-center">
          <div className="text-4xl mb-3">📋</div>
          <p className="text-gym-400 text-sm">
            {blockFilter || dayFilter
              ? 'No sessions match your filters.'
              : 'No sessions logged yet.'}
          </p>
        </div>
      )}
    </div>
  );
}
