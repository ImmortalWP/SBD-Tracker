export default function MuscleMap({ data = {} }) {
  const getColor = (value) => {
    if (!value || value === 0) return '#1a1a1a';
    if (value <= 3) return '#1B5E20';
    if (value <= 6) return '#2E7D32';
    if (value <= 10) return '#388E3C';
    if (value <= 15) return '#4CAF50';
    if (value <= 20) return '#66BB6A';
    return '#A5D6A7';
  };

  const getOpacity = (value) => {
    if (!value || value === 0) return 0.3;
    return Math.min(0.4 + (value / 25) * 0.6, 1);
  };

  // Combine some groups for display
  const chest = (data.Chest || 0);
  const back = (data.Back || 0) + (data.Lats || 0);
  const shoulders = (data.Shoulders || 0) + (data.Traps || 0);
  const biceps = (data.Biceps || 0);
  const triceps = (data.Triceps || 0);
  const forearms = (data.Forearms || 0);
  const abs = (data.Abs || 0) + (data.Obliques || 0);
  const quads = (data.Quads || 0);
  const hamstrings = (data.Hamstrings || 0);
  const glutes = (data.Glutes || 0);
  const calves = (data.Calves || 0);

  const muscles = [
    { name: 'Chest', sets: chest, y: 18 },
    { name: 'Back', sets: back, y: 22 },
    { name: 'Shoulders', sets: shoulders, y: 14 },
    { name: 'Biceps', sets: biceps, y: 24 },
    { name: 'Triceps', sets: triceps, y: 24 },
    { name: 'Forearms', sets: forearms, y: 32 },
    { name: 'Core', sets: abs, y: 30 },
    { name: 'Quads', sets: quads, y: 42 },
    { name: 'Hamstrings', sets: hamstrings, y: 44 },
    { name: 'Glutes', sets: glutes, y: 36 },
    { name: 'Calves', sets: calves, y: 56 },
  ];

  return (
    <div className="card p-5">
      <div className="grid grid-cols-2 gap-x-6 gap-y-2">
        {/* Front view label */}
        <div className="text-center text-xs font-semibold text-sl-textMuted mb-1">FRONT</div>
        <div className="text-center text-xs font-semibold text-sl-textMuted mb-1">BACK</div>

        {/* Front body */}
        <div className="flex flex-col items-center gap-1">
          {/* Head */}
          <div className="w-8 h-8 rounded-full bg-sl-border" />
          {/* Shoulders */}
          <div className="flex gap-0.5 items-start -mt-1">
            <div className="w-5 h-6 rounded-lg" style={{ backgroundColor: getColor(shoulders), opacity: getOpacity(shoulders) }} />
            {/* Chest */}
            <div className="flex flex-col items-center gap-0.5">
              <div className="w-12 h-6 rounded-lg" style={{ backgroundColor: getColor(chest), opacity: getOpacity(chest) }} />
              {/* Abs */}
              <div className="w-10 h-10 rounded-lg" style={{ backgroundColor: getColor(abs), opacity: getOpacity(abs) }} />
            </div>
            <div className="w-5 h-6 rounded-lg" style={{ backgroundColor: getColor(shoulders), opacity: getOpacity(shoulders) }} />
          </div>
          {/* Arms */}
          <div className="flex gap-8 -mt-12">
            <div className="flex flex-col gap-0.5 items-center">
              <div className="w-4 h-7 rounded-md" style={{ backgroundColor: getColor(biceps), opacity: getOpacity(biceps) }} />
              <div className="w-3 h-5 rounded-md" style={{ backgroundColor: getColor(forearms), opacity: getOpacity(forearms) }} />
            </div>
            <div className="w-16" />
            <div className="flex flex-col gap-0.5 items-center">
              <div className="w-4 h-7 rounded-md" style={{ backgroundColor: getColor(biceps), opacity: getOpacity(biceps) }} />
              <div className="w-3 h-5 rounded-md" style={{ backgroundColor: getColor(forearms), opacity: getOpacity(forearms) }} />
            </div>
          </div>
          {/* Quads */}
          <div className="flex gap-1 mt-0">
            <div className="w-5 h-10 rounded-lg" style={{ backgroundColor: getColor(quads), opacity: getOpacity(quads) }} />
            <div className="w-5 h-10 rounded-lg" style={{ backgroundColor: getColor(quads), opacity: getOpacity(quads) }} />
          </div>
          {/* Calves */}
          <div className="flex gap-2">
            <div className="w-3 h-7 rounded-md" style={{ backgroundColor: getColor(calves), opacity: getOpacity(calves) }} />
            <div className="w-3 h-7 rounded-md" style={{ backgroundColor: getColor(calves), opacity: getOpacity(calves) }} />
          </div>
        </div>

        {/* Back body */}
        <div className="flex flex-col items-center gap-1">
          <div className="w-8 h-8 rounded-full bg-sl-border" />
          <div className="flex gap-0.5 items-start -mt-1">
            <div className="w-5 h-6 rounded-lg" style={{ backgroundColor: getColor(shoulders), opacity: getOpacity(shoulders) }} />
            <div className="flex flex-col items-center gap-0.5">
              <div className="w-12 h-6 rounded-lg" style={{ backgroundColor: getColor(back), opacity: getOpacity(back) }} />
              {/* Glutes */}
              <div className="w-10 h-5 rounded-lg" style={{ backgroundColor: getColor(back), opacity: getOpacity(back) }} />
              <div className="w-10 h-5 rounded-lg" style={{ backgroundColor: getColor(glutes), opacity: getOpacity(glutes) }} />
            </div>
            <div className="w-5 h-6 rounded-lg" style={{ backgroundColor: getColor(shoulders), opacity: getOpacity(shoulders) }} />
          </div>
          <div className="flex gap-8 -mt-12">
            <div className="flex flex-col gap-0.5 items-center">
              <div className="w-4 h-7 rounded-md" style={{ backgroundColor: getColor(triceps), opacity: getOpacity(triceps) }} />
              <div className="w-3 h-5 rounded-md" style={{ backgroundColor: getColor(forearms), opacity: getOpacity(forearms) }} />
            </div>
            <div className="w-16" />
            <div className="flex flex-col gap-0.5 items-center">
              <div className="w-4 h-7 rounded-md" style={{ backgroundColor: getColor(triceps), opacity: getOpacity(triceps) }} />
              <div className="w-3 h-5 rounded-md" style={{ backgroundColor: getColor(forearms), opacity: getOpacity(forearms) }} />
            </div>
          </div>
          {/* Hamstrings */}
          <div className="flex gap-1 mt-0">
            <div className="w-5 h-10 rounded-lg" style={{ backgroundColor: getColor(hamstrings), opacity: getOpacity(hamstrings) }} />
            <div className="w-5 h-10 rounded-lg" style={{ backgroundColor: getColor(hamstrings), opacity: getOpacity(hamstrings) }} />
          </div>
          <div className="flex gap-2">
            <div className="w-3 h-7 rounded-md" style={{ backgroundColor: getColor(calves), opacity: getOpacity(calves) }} />
            <div className="w-3 h-7 rounded-md" style={{ backgroundColor: getColor(calves), opacity: getOpacity(calves) }} />
          </div>
        </div>
      </div>

      {/* Legend */}
      <div className="mt-4 pt-3 border-t border-sl-border">
        <div className="grid grid-cols-2 gap-1.5">
          {muscles.map(m => (
            <div key={m.name} className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: getColor(m.sets), opacity: getOpacity(m.sets) }} />
              <span className="text-xs text-sl-textSecondary">{m.name}</span>
              <span className="text-xs font-mono font-semibold text-sl-text ml-auto">{Math.round(m.sets)}</span>
            </div>
          ))}
        </div>
        <p className="text-[10px] text-sl-textMuted mt-2 text-center">Sets per muscle group</p>
      </div>
    </div>
  );
}
