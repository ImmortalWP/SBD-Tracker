import SessionForm from '../components/SessionForm';

export default function AddSession() {
  return (
    <div className="animate-fade-in">
      <div className="mb-6">
        <h1 className="text-2xl font-extrabold text-gym-50 tracking-tight">
          Log Session
        </h1>
        <p className="text-gym-400 text-sm mt-1">
          Record your training — just like your diary.
        </p>
      </div>
      <SessionForm />
    </div>
  );
}
