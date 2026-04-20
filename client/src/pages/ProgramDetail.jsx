import { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { HiArrowLeft, HiPlay, HiStop } from 'react-icons/hi';
import { getProgram, startProgram, stopProgram } from '../api/api';

export default function ProgramDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [program, setProgram] = useState(null);
  const [loading, setLoading] = useState(true);
  const [expandedWeek, setExpandedWeek] = useState(0);

  useEffect(() => { loadProgram(); }, [id]);

  const loadProgram = async () => {
    try {
      const res = await getProgram(id);
      setProgram(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleStart = async () => {
    try {
      await startProgram(id);
      alert('Program started! Your workouts will follow this schedule.');
      loadProgram();
    } catch (err) {
      console.error(err);
    }
  };

  const handleStop = async () => {
    if (!confirm('Stop this program?')) return;
    try {
      await stopProgram(id);
      loadProgram();
    } catch (err) {
      console.error(err);
    }
  };

  if (loading) {
    return <div className="space-y-4"><div className="skeleton h-8 w-48 rounded-lg" /><div className="skeleton h-64 rounded-2xl" /></div>;
  }

  if (!program) return <p className="text-sl-textMuted text-center py-12">Program not found</p>;

  return (
    <div className="space-y-5 animate-fade-in">
      <div className="flex items-center gap-3">
        <Link to="/programs" className="btn-icon" id="back-programs"><HiArrowLeft className="text-lg" /></Link>
        <div className="flex-1">
          <h1 className="text-xl font-extrabold text-sl-text">{program.name}</h1>
          <p className="text-xs text-sl-textMuted">{program.weeks} weeks • {program.daysPerWeek} days/week • {program.difficulty}</p>
        </div>
      </div>

      <div className="card p-4">
        <p className="text-sm text-sl-textSecondary leading-relaxed">{program.description}</p>
      </div>

      {/* Action */}
      <button onClick={handleStart} className="btn-primary w-full flex items-center justify-center gap-2" id="start-program">
        <HiPlay /> Start Program
      </button>

      {/* Schedule */}
      {program.schedule?.map((week, wIdx) => (
        <div key={wIdx}>
          <button
            onClick={() => setExpandedWeek(expandedWeek === wIdx ? -1 : wIdx)}
            className="w-full text-left section-title mb-2 flex items-center justify-between py-2"
          >
            <span>{week.name || `Week ${week.weekNumber}`}</span>
            <span className="text-sl-textMuted">{expandedWeek === wIdx ? '▼' : '▶'}</span>
          </button>
          
          {expandedWeek === wIdx && (
            <div className="space-y-3 animate-fade-in">
              {week.days?.map((day, dIdx) => (
                <div key={dIdx} className="card p-4">
                  <h3 className="text-sm font-bold text-sl-green mb-3">{day.name}</h3>
                  <div className="space-y-2">
                    {day.exercises?.map((ex, eIdx) => (
                      <div key={eIdx} className="flex items-center justify-between py-1">
                        <span className="text-sm text-sl-text">{ex.name}</span>
                        <span className="text-xs text-sl-textMuted font-mono">
                          {ex.sets}×{ex.reps}
                          {ex.percentage1rm && ` @${ex.percentage1rm}%`}
                        </span>
                      </div>
                    ))}
                  </div>
                  {day.exercises?.[0]?.notes && (
                    <p className="text-xs text-sl-textMuted mt-2 italic">{day.exercises[0].notes}</p>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
