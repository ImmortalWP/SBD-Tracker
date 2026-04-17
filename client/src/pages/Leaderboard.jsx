import { useState, useEffect } from 'react';
import { HiTrophy } from 'react-icons/hi2';
import { GiTrophy, GiPodium, GiMuscleUp } from 'react-icons/gi';
import { getLeaderboard } from '../api/sessions';
import { useAuth } from '../context/AuthContext';

const RANK_STYLES = [
  {
    bg: 'bg-gradient-to-r from-yellow-500/20 via-yellow-400/10 to-yellow-500/20',
    border: 'border-yellow-500/30',
    badge: 'bg-yellow-500 text-gym-950',
    glow: 'shadow-[0_0_30px_rgba(234,179,8,0.15)]',
    icon: '🥇',
  },
  {
    bg: 'bg-gradient-to-r from-gray-400/15 via-gray-300/10 to-gray-400/15',
    border: 'border-gray-400/30',
    badge: 'bg-gray-400 text-gym-950',
    glow: 'shadow-[0_0_20px_rgba(156,163,175,0.1)]',
    icon: '🥈',
  },
  {
    bg: 'bg-gradient-to-r from-amber-700/15 via-amber-600/10 to-amber-700/15',
    border: 'border-amber-700/30',
    badge: 'bg-amber-700 text-white',
    glow: 'shadow-[0_0_20px_rgba(180,83,9,0.1)]',
    icon: '🥉',
  },
];

const LIFT_COLORS = {
  Squat: { text: 'text-red-400', bg: 'bg-red-500/10', border: 'border-red-500/20' },
  Bench: { text: 'text-blue-400', bg: 'bg-blue-500/10', border: 'border-blue-500/20' },
  Deadlift: { text: 'text-amber-400', bg: 'bg-amber-500/10', border: 'border-amber-500/20' },
};

export default function Leaderboard() {
  const [leaderboard, setLeaderboard] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedLift, setSelectedLift] = useState('total');
  const { user } = useAuth();

  useEffect(() => {
    loadLeaderboard();
  }, []);

  const loadLeaderboard = async () => {
    setLoading(true);
    try {
      const res = await getLeaderboard();
      setLeaderboard(res.data);
    } catch (err) {
      console.error('Failed to load leaderboard:', err);
    } finally {
      setLoading(false);
    }
  };

  const getSorted = () => {
    if (selectedLift === 'total') {
      return [...leaderboard].sort((a, b) => b.total - a.total);
    }
    return [...leaderboard].sort((a, b) => b[selectedLift] - a[selectedLift]);
  };

  const sorted = getSorted();

  const filterButtons = [
    { key: 'total', label: 'Total', emoji: '🏆' },
    { key: 'Squat', label: 'Squat', emoji: '🦵' },
    { key: 'Bench', label: 'Bench', emoji: '💪' },
    { key: 'Deadlift', label: 'Deadlift', emoji: '🏋️' },
  ];

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-gym-50 tracking-tight flex items-center gap-3">
            <span className="text-3xl">🏆</span> Leaderboard
          </h1>
          <p className="text-gym-400 text-sm mt-1">
            Who lifts the heaviest? Compare PRs across all lifters.
          </p>
        </div>
      </div>

      {/* Filter Buttons */}
      <div className="flex gap-2 flex-wrap">
        {filterButtons.map(({ key, label, emoji }) => (
          <button
            key={key}
            onClick={() => setSelectedLift(key)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all duration-200 ${
              selectedLift === key
                ? 'bg-accent-red/15 text-accent-red border border-accent-red/25'
                : 'bg-gym-800/50 text-gym-400 border border-gym-700/50 hover:text-gym-200 hover:border-gym-600'
            }`}
            id={`filter-${key}`}
          >
            <span>{emoji}</span>
            {label}
          </button>
        ))}
      </div>

      {/* Leaderboard */}
      {loading ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="card p-6 animate-pulse">
              <div className="flex items-center gap-4">
                <div className="w-10 h-10 bg-gym-800 rounded-full" />
                <div className="flex-1 space-y-2">
                  <div className="h-5 w-28 bg-gym-800 rounded" />
                  <div className="h-4 w-40 bg-gym-800 rounded" />
                </div>
                <div className="h-8 w-20 bg-gym-800 rounded" />
              </div>
            </div>
          ))}
        </div>
      ) : sorted.length === 0 ? (
        <div className="card p-12 text-center">
          <div className="text-5xl mb-4">🏋️</div>
          <p className="text-gym-400 text-sm">
            No lifters on the board yet. Log some sessions to get started!
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {sorted.map((entry, idx) => {
            const rankStyle = idx < 3 ? RANK_STYLES[idx] : null;
            const isCurrentUser = entry.username === user?.username;
            const displayValue =
              selectedLift === 'total' ? entry.total : entry[selectedLift];

            return (
              <div
                key={entry.userId}
                className={`card p-5 transition-all duration-300 ${
                  rankStyle
                    ? `${rankStyle.bg} border ${rankStyle.border} ${rankStyle.glow}`
                    : ''
                } ${isCurrentUser ? 'ring-1 ring-accent-red/30' : ''}`}
              >
                <div className="flex items-center gap-4">
                  {/* Rank */}
                  <div className="flex-shrink-0">
                    {rankStyle ? (
                      <span className="text-3xl">{rankStyle.icon}</span>
                    ) : (
                      <span className="w-10 h-10 rounded-full bg-gym-800 border border-gym-700 flex items-center justify-center text-sm font-bold text-gym-400 font-mono">
                        {idx + 1}
                      </span>
                    )}
                  </div>

                  {/* User Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-base font-bold text-gym-50 truncate">
                        {entry.username}
                      </span>
                      {isCurrentUser && (
                        <span className="text-[10px] font-bold uppercase tracking-wider px-1.5 py-0.5 rounded bg-accent-red/15 text-accent-red border border-accent-red/20">
                          You
                        </span>
                      )}
                    </div>

                    {/* Individual Lifts */}
                    <div className="flex items-center gap-3 mt-1.5 flex-wrap">
                      {['Squat', 'Bench', 'Deadlift'].map((lift) => (
                        <span
                          key={lift}
                          className={`inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded ${
                            LIFT_COLORS[lift].bg
                          } ${LIFT_COLORS[lift].text} border ${
                            LIFT_COLORS[lift].border
                          } ${
                            selectedLift === lift ? 'ring-1 ring-current' : ''
                          }`}
                        >
                          <span className="font-semibold">{lift[0]}:</span>
                          <span className="font-mono">
                            {entry[lift] > 0 ? `${entry[lift]}kg` : '—'}
                          </span>
                        </span>
                      ))}
                    </div>
                  </div>

                  {/* Total / Selected Lift Value */}
                  <div className="flex-shrink-0 text-right">
                    <div
                      className={`text-2xl sm:text-3xl font-extrabold font-mono ${
                        idx === 0
                          ? 'text-yellow-400'
                          : idx === 1
                          ? 'text-gray-300'
                          : idx === 2
                          ? 'text-amber-600'
                          : 'text-gym-100'
                      }`}
                    >
                      {displayValue > 0 ? displayValue : '—'}
                    </div>
                    <span className="text-[10px] font-semibold uppercase tracking-wider text-gym-500">
                      {displayValue > 0 ? 'kg' : ''}{' '}
                      {selectedLift === 'total' ? 'total' : selectedLift}
                    </span>
                  </div>
                </div>

                {/* Progress bar relative to #1 */}
                {sorted[0] && displayValue > 0 && (
                  <div className="mt-3 h-1.5 rounded-full bg-gym-800/50 overflow-hidden">
                    <div
                      className={`h-full rounded-full transition-all duration-700 ease-out ${
                        idx === 0
                          ? 'bg-gradient-to-r from-yellow-500 to-yellow-400'
                          : idx === 1
                          ? 'bg-gradient-to-r from-gray-400 to-gray-300'
                          : idx === 2
                          ? 'bg-gradient-to-r from-amber-700 to-amber-600'
                          : 'bg-gradient-to-r from-accent-red to-accent-amber'
                      }`}
                      style={{
                        width: `${Math.max(
                          (displayValue /
                            (selectedLift === 'total'
                              ? sorted[0].total
                              : sorted[0][selectedLift])) *
                            100,
                          5
                        )}%`,
                      }}
                    />
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Summary Card */}
      {!loading && sorted.length >= 2 && (
        <div className="card p-5 bg-gym-900/50 border-gym-700/50">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-lg">📊</span>
            <span className="text-xs font-semibold uppercase tracking-wider text-gym-400">
              Quick Stats
            </span>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-center">
            <div>
              <p className="text-xs text-gym-500 mb-1">Lifters</p>
              <p className="text-xl font-extrabold text-gym-50">{sorted.length}</p>
            </div>
            <div>
              <p className="text-xs text-gym-500 mb-1">Highest Total</p>
              <p className="text-xl font-extrabold text-yellow-400 font-mono">
                {sorted[0]?.total || 0}
                <span className="text-xs text-gym-500 ml-0.5">kg</span>
              </p>
            </div>
            <div>
              <p className="text-xs text-gym-500 mb-1">Heaviest Squat</p>
              <p className="text-xl font-extrabold text-red-400 font-mono">
                {Math.max(...sorted.map((e) => e.Squat))}
                <span className="text-xs text-gym-500 ml-0.5">kg</span>
              </p>
            </div>
            <div>
              <p className="text-xs text-gym-500 mb-1">Heaviest Deadlift</p>
              <p className="text-xl font-extrabold text-amber-400 font-mono">
                {Math.max(...sorted.map((e) => e.Deadlift))}
                <span className="text-xs text-gym-500 ml-0.5">kg</span>
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
