export default function ExerciseBlock({ exercise }) {
  const isMain = exercise.category === 'main';

  return (
    <div className="animate-fade-in">
      <div className="flex items-center gap-2 mb-2">
        <h4 className="text-sm font-semibold text-gym-100">{exercise.name}</h4>
        <span className={isMain ? 'badge-main' : 'badge-accessory'}>
          {isMain ? 'Main' : 'Accessory'}
        </span>
      </div>

      <div className="space-y-1 pl-4 border-l-2 border-gym-700/50">
        {exercise.sets.map((set, idx) => (
          <div key={idx} className="set-row flex items-center gap-2">
            <span className="text-gym-600 text-xs w-5">{idx + 1}.</span>
            <span className="text-gym-200">
              {set.weight}
              <span className="text-gym-500 mx-1">@</span>
              {set.sets}
              <span className="text-gym-500 mx-0.5">×</span>
              {set.reps}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
