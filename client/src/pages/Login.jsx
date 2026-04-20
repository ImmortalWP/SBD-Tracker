import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { HiLockClosed, HiUser, HiArrowRight } from 'react-icons/hi';
import { GiWeightLiftingUp } from 'react-icons/gi';
import { useAuth } from '../context/AuthContext';
import { loginUser, registerUser } from '../api/api';

export default function Login() {
  const [isRegister, setIsRegister] = useState(false);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();
  const { login } = useAuth();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    if (!username.trim() || !password) {
      setError('Username and password are required.');
      return;
    }
    if (isRegister && password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }
    setLoading(true);
    try {
      const res = isRegister
        ? await registerUser({ username: username.trim(), password })
        : await loginUser({ username: username.trim(), password });
      login(res.data.token);
      navigate('/');
    } catch (err) {
      setError(err.response?.data?.error || 'Something went wrong.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-sl-bg flex items-center justify-center px-5 py-12">
      <div className="fixed inset-0 pointer-events-none">
        <div className="absolute -top-32 -right-32 w-64 h-64 bg-sl-green/5 rounded-full blur-3xl" />
        <div className="absolute -bottom-32 -left-32 w-64 h-64 bg-sl-green/3 rounded-full blur-3xl" />
      </div>

      <div className="w-full max-w-sm relative z-10 animate-fade-in">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-sl-green/10 border border-sl-green/20 mb-4">
            <GiWeightLiftingUp className="text-sl-green text-3xl" />
          </div>
          <h1 className="text-3xl font-extrabold text-sl-text tracking-tight">
            StrengthLog
          </h1>
          <p className="text-sl-textMuted text-sm mt-1">
            {isRegister ? 'Create your account' : 'Welcome back'}
          </p>
        </div>

        {/* Form */}
        <div className="card p-6 border-sl-border/50">
          <form onSubmit={handleSubmit} className="space-y-4">
            {error && (
              <div className="p-3 rounded-xl bg-sl-red/10 border border-sl-red/20 text-sl-red text-sm animate-fade-in">
                {error}
              </div>
            )}

            <div>
              <label className="section-title block mb-1.5">Username</label>
              <div className="relative">
                <HiUser className="absolute left-3.5 top-1/2 -translate-y-1/2 text-sl-textMuted" />
                <input
                  type="text" value={username}
                  onChange={e => setUsername(e.target.value)}
                  placeholder="Enter username"
                  className="input-field pl-10" autoFocus id="login-username"
                />
              </div>
            </div>

            <div>
              <label className="section-title block mb-1.5">Password</label>
              <div className="relative">
                <HiLockClosed className="absolute left-3.5 top-1/2 -translate-y-1/2 text-sl-textMuted" />
                <input
                  type="password" value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="Enter password"
                  className="input-field pl-10" id="login-password"
                />
              </div>
            </div>

            {isRegister && (
              <div className="animate-fade-in">
                <label className="section-title block mb-1.5">Confirm Password</label>
                <div className="relative">
                  <HiLockClosed className="absolute left-3.5 top-1/2 -translate-y-1/2 text-sl-textMuted" />
                  <input
                    type="password" value={confirmPassword}
                    onChange={e => setConfirmPassword(e.target.value)}
                    placeholder="Confirm password"
                    className="input-field pl-10" id="login-confirm"
                  />
                </div>
              </div>
            )}

            <button type="submit" disabled={loading} className="btn-primary w-full flex items-center justify-center gap-2 py-3.5" id="auth-submit">
              {loading ? (
                <span className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>{isRegister ? 'Create Account' : 'Login'} <HiArrowRight /></>
              )}
            </button>
          </form>

          <div className="mt-5 pt-4 border-t border-sl-border">
            <button
              onClick={() => { setIsRegister(!isRegister); setError(''); }}
              className="w-full text-center text-sm text-sl-textSecondary hover:text-sl-text transition-colors"
              id="auth-toggle"
            >
              {isRegister ? 'Already have an account? Login' : "Don't have an account? Register"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
