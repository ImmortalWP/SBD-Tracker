import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getSession } from '../api/sessions';
import SessionForm from '../components/SessionForm';

export default function EditSession() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    loadSession();
  }, [id]);

  const loadSession = async () => {
    setLoading(true);
    try {
      const res = await getSession(id);
      setSession(res.data);
    } catch (err) {
      setError('Session not found.');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="animate-pulse space-y-4">
        <div className="h-8 w-48 bg-gym-800 rounded" />
        <div className="card p-6 space-y-3">
          <div className="h-10 bg-gym-800 rounded" />
          <div className="h-10 bg-gym-800 rounded" />
          <div className="h-10 bg-gym-800 rounded" />
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="card p-8 text-center animate-fade-in">
        <div className="text-4xl mb-3">❌</div>
        <p className="text-gym-400 text-sm mb-4">{error}</p>
        <button onClick={() => navigate('/sessions')} className="btn-primary" id="back-to-sessions">
          Back to Sessions
        </button>
      </div>
    );
  }

  return (
    <div className="animate-fade-in">
      <div className="mb-6">
        <h1 className="text-2xl font-extrabold text-gym-50 tracking-tight">
          Edit Session
        </h1>
        <p className="text-gym-400 text-sm mt-1">
          Block {session.block} — {session.day}
        </p>
      </div>
      <SessionForm existingSession={session} />
    </div>
  );
}
