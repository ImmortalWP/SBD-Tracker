import { GiMuscleUp } from 'react-icons/gi';

const liftIcons = {
  Squat: '🦵',
  Bench: '💪',
  Deadlift: '🏋️',
};

const liftLabels = {
  Squat: 'Squats',
  Bench: 'Bench',
  Deadlift: 'Deadlifts',
};

const liftColors = {
  Squat: 'from-red-500/20 to-red-900/10 border-red-500/20',
  Bench: 'from-blue-500/20 to-blue-900/10 border-blue-500/20',
  Deadlift: 'from-amber-500/20 to-amber-900/10 border-amber-500/20',
};

export default function StatsPanel({ prs, loading }) {
  if (loading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {[1, 2, 3].map((i) => (
          <div key={i} className="card p-5 animate-pulse">
            <div className="h-4 bg-gym-800 rounded w-16 mb-3" />
            <div className="h-8 bg-gym-800 rounded w-24" />
          </div>
        ))}
      </div>
    );
  }

  const lifts = ['Squat', 'Bench', 'Deadlift'];

  return (
    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
      {lifts.map((lift) => (
        <div
          key={lift}
          className={`card p-5 bg-gradient-to-br ${liftColors[lift]} overflow-hidden relative group`}
        >
          {/* Background icon */}
          <div className="absolute -right-3 -bottom-3 opacity-5 group-hover:opacity-10 transition-opacity duration-500">
            <GiMuscleUp className="text-7xl" />
          </div>

          <div className="relative z-10">
            <div className="flex items-center gap-2 mb-2">
              <span className="text-lg">{liftIcons[lift]}</span>
              <span className="text-xs font-semibold uppercase tracking-wider text-gym-400">
                {liftLabels[lift]} PR
              </span>
            </div>
            <div className="flex items-baseline gap-1.5">
              <span className="text-3xl font-extrabold text-gym-50">
                {prs[lift] || '—'}
              </span>
              {prs[lift] > 0 && (
                <span className="text-sm font-medium text-gym-500">kg</span>
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
