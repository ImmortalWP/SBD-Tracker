import { useNavigate } from 'react-router-dom';
import { HiPencil, HiTrash } from 'react-icons/hi';
import { deleteSession } from '../api/sessions';
import ExerciseBlock from './ExerciseBlock';

export default function SessionCard({ session, onDelete }) {
  const navigate = useNavigate();

  const mainLifts = session.exercises.filter((e) => e.category === 'main');
  const secondaryLifts = session.exercises.filter((e) => e.category === 'secondary');
  const accessories = session.exercises.filter((e) => e.category === 'accessory');

  const handleDelete = async () => {
    if (window.confirm('Delete this session?')) {
      await deleteSession(session._id);
      onDelete?.(session._id);
    }
  };

  const getDurationInfo = () => {
    if (!session.startTime || !session.endTime) return '';
    try {
      const [sh, sm, ss = 0] = session.startTime.split(':').map(Number);
      const [eh, em, es = 0] = session.endTime.split(':').map(Number);
      
      let startSecs = (sh || 0) * 3600 + (sm || 0) * 60 + (ss || 0);
      let endSecs = (eh || 0) * 3600 + (em || 0) * 60 + (es || 0);
      
      let diff = endSecs - startSecs;
      if (diff < 0) diff += 24 * 3600;
      
      const h = Math.floor(diff / 3600);
      const m = Math.floor((diff % 3600) / 60);
      const s = diff % 60;
      
      if (h > 0) return `(${h}h ${m}m)`;
      if (m > 0) return `(${m}m)`;
      return `(${s}s)`;
    } catch {
      return '';
    }
  };

  const formattedDate = session.date
    ? new Date(session.date).toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
      })
    : '';

  return (
    <div className="card p-5 animate-slide-up">
      {/* Header */}
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-3 flex-wrap">
          <span className="badge-block">Block {session.block}</span>
          {session.percentage && (
            <span className="inline-flex items-center px-2.5 py-0.5 rounded-md text-xs font-bold font-mono bg-accent-green/15 text-accent-green border border-accent-green/20">
              {session.percentage}%
            </span>
          )}
          <span className="badge-day">{session.day}</span>
          {formattedDate && (
            <span className="text-xs text-gym-500">{formattedDate}</span>
          )}
          {session.startTime && (
            <span className="text-xs text-gym-400 font-mono bg-gym-800 px-2 py-0.5 rounded">
              ⏱ {session.startTime} {session.endTime ? `— ${session.endTime} ${getDurationInfo()}` : ''}
            </span>
          )}
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={() => navigate(`/edit/${session._id}`)}
            className="btn-ghost p-2"
            title="Edit session"
            id={`edit-session-${session._id}`}
          >
            <HiPencil className="text-base" />
          </button>
          <button
            onClick={handleDelete}
            className="btn-danger p-2"
            title="Delete session"
            id={`delete-session-${session._id}`}
          >
            <HiTrash className="text-base" />
          </button>
        </div>
      </div>

      {/* Divider */}
      <div className="h-px bg-gradient-to-r from-transparent via-gym-700/50 to-transparent mb-4" />

      {/* Main Lifts */}
      {mainLifts.length > 0 && (
        <div className="space-y-4 mb-4">
          {mainLifts.map((ex, idx) => (
            <ExerciseBlock key={idx} exercise={ex} />
          ))}
        </div>
      )}

      {/* Secondary Lifts */}
      {secondaryLifts.length > 0 && (
        <div className="space-y-4 mb-4">
          {secondaryLifts.map((ex, idx) => (
            <ExerciseBlock key={idx} exercise={ex} />
          ))}
        </div>
      )}

      {/* Accessories */}
      {accessories.length > 0 && (
        <>
          <div className="h-px bg-gym-800 my-4" />
          <div className="mb-2">
            <span className="text-xs font-semibold uppercase tracking-wider text-gym-500">
              Accessories
            </span>
          </div>
          <div className="space-y-3">
            {accessories.map((ex, idx) => (
              <ExerciseBlock key={idx} exercise={ex} />
            ))}
          </div>
        </>
      )}

      {/* Notes */}
      {session.notes && (
        <div className="mt-4 pt-3 border-t border-gym-800">
          <p className="text-xs text-gym-500 italic">📝 {session.notes}</p>
        </div>
      )}
    </div>
  );
}
