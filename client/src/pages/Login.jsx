import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { GiWeightLiftingUp } from 'react-icons/gi';
import { HiLockClosed, HiUser, HiArrowRight, HiSwitchHorizontal } from 'react-icons/hi';
import { useAuth } from '../context/AuthContext';
import { loginUser, registerUser } from '../api/sessions';

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
      setError(err.response?.data?.error || 'Something went wrong. Try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gym-950 flex items-center justify-center px-4 py-12">
      {/* Background decoration */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-80 h-80 bg-accent-red/5 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-80 h-80 bg-accent-amber/5 rounded-full blur-3xl" />
      </div>

      <div className="w-full max-w-md relative z-10 animate-fade-in">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-accent-red/10 border border-accent-red/20 mb-4">
            <GiWeightLiftingUp className="text-accent-red text-3xl" />
          </div>
          <h1 className="text-3xl font-extrabold text-gym-50 tracking-tight">
            SBD Tracker
          </h1>
          <p className="text-gym-400 text-sm mt-1">
            {isRegister ? 'Create your training log' : 'Log in to your training log'}
          </p>
        </div>

        {/* Card */}
        <div className="card p-6 sm:p-8 bg-gym-850/80 backdrop-blur-sm border-gym-700/50">
          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Error */}
            {error && (
              <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm animate-fade-in">
                {error}
              </div>
            )}

            {/* Username */}
            <div>
              <label
                htmlFor="login-username"
                className="block text-xs font-semibold uppercase tracking-wider text-gym-400 mb-1.5"
              >
                Username
              </label>
              <div className="relative">
                <HiUser className="absolute left-3 top-1/2 -translate-y-1/2 text-gym-500 text-base" />
                <input
                  id="login-username"
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="Enter username"
                  className="input-base pl-10"
                  autoComplete="username"
                  autoFocus
                />
              </div>
            </div>

            {/* Password */}
            <div>
              <label
                htmlFor="login-password"
                className="block text-xs font-semibold uppercase tracking-wider text-gym-400 mb-1.5"
              >
                Password
              </label>
              <div className="relative">
                <HiLockClosed className="absolute left-3 top-1/2 -translate-y-1/2 text-gym-500 text-base" />
                <input
                  id="login-password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter password"
                  className="input-base pl-10"
                  autoComplete={isRegister ? 'new-password' : 'current-password'}
                />
              </div>
            </div>

            {/* Confirm Password (Register only) */}
            {isRegister && (
              <div className="animate-fade-in">
                <label
                  htmlFor="login-confirm-password"
                  className="block text-xs font-semibold uppercase tracking-wider text-gym-400 mb-1.5"
                >
                  Confirm Password
                </label>
                <div className="relative">
                  <HiLockClosed className="absolute left-3 top-1/2 -translate-y-1/2 text-gym-500 text-base" />
                  <input
                    id="login-confirm-password"
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    placeholder="Confirm password"
                    className="input-base pl-10"
                    autoComplete="new-password"
                  />
                </div>
              </div>
            )}

            {/* Submit */}
            <button
              type="submit"
              disabled={loading}
              className="btn-primary w-full flex items-center justify-center gap-2 py-3 text-base"
              id="auth-submit"
            >
              {loading ? (
                <span className="inline-block w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  {isRegister ? 'Create Account' : 'Login'}
                  <HiArrowRight className="text-lg" />
                </>
              )}
            </button>
          </form>

          {/* Toggle */}
          <div className="mt-6 pt-5 border-t border-gym-700/50">
            <button
              onClick={() => {
                setIsRegister(!isRegister);
                setError('');
                setConfirmPassword('');
              }}
              className="w-full text-center text-sm text-gym-400 hover:text-gym-200 transition-colors duration-200 flex items-center justify-center gap-2"
              id="auth-toggle"
            >
              <HiSwitchHorizontal className="text-base" />
              {isRegister
                ? 'Already have an account? Login'
                : "Don't have an account? Register"}
            </button>
          </div>
        </div>

        {/* Footer */}
        <p className="text-center text-gym-600 text-xs mt-6">
          Your lifts, your data. Track SBD progress.
        </p>
      </div>
    </div>
  );
}
