import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { HiLogout, HiChartBar, HiCalculator, HiScale, HiCog, HiChevronRight, HiUser } from 'react-icons/hi';
import { GiWeightLiftingUp, GiMuscleUp } from 'react-icons/gi';
import { useAuth } from '../context/AuthContext';
import { getProfile, updateProfile } from '../api/api';

export default function Profile() {
  const { user, logout } = useAuth();
  const [profile, setProfile] = useState(null);
  const [unit, setUnit] = useState('kg');

  useEffect(() => { loadProfile(); }, []);

  const loadProfile = async () => {
    try {
      const res = await getProfile();
      setProfile(res.data);
      setUnit(res.data.unit || 'kg');
    } catch (err) {
      console.error(err);
    }
  };

  const handleUnitChange = async (newUnit) => {
    setUnit(newUnit);
    try {
      await updateProfile({ unit: newUnit });
    } catch (err) {
      console.error(err);
    }
  };

  const menuItems = [
    { to: '/stats', icon: HiChartBar, label: 'Statistics', desc: 'Volume, records, muscle map', color: 'text-sl-green' },
    { to: '/calculators', icon: HiCalculator, label: 'Calculators', desc: '1RM, plate, warm-up', color: 'text-sl-blue' },
    { to: '/body', icon: HiScale, label: 'Body Metrics', desc: 'Weight, body fat, measurements', color: 'text-sl-amber' },
    { to: '/programs', icon: GiMuscleUp, label: 'Training Programs', desc: 'Browse & follow programs', color: 'text-sl-purple' },
    { to: '/exercises', icon: GiWeightLiftingUp, label: 'Exercise Library', desc: '300+ exercises', color: 'text-sl-cyan' },
  ];

  return (
    <div className="space-y-5 animate-fade-in">
      {/* Profile Header */}
      <div className="card p-5 flex items-center gap-4">
        <div className="w-16 h-16 rounded-2xl bg-sl-green/15 flex items-center justify-center text-sl-green text-2xl font-bold">
          {(user?.username || 'U')[0].toUpperCase()}
        </div>
        <div>
          <h1 className="text-xl font-extrabold text-sl-text capitalize">{user?.username}</h1>
          {profile?.createdAt && (
            <p className="text-xs text-sl-textMuted">
              Member since {new Date(profile.createdAt).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
            </p>
          )}
          {profile?.bodyWeight && (
            <p className="text-xs text-sl-textSecondary mt-0.5">{profile.bodyWeight} {unit}</p>
          )}
        </div>
      </div>

      {/* Unit Toggle */}
      <div className="card p-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-semibold text-sl-text">Weight Unit</p>
            <p className="text-xs text-sl-textMuted">Used across the app</p>
          </div>
          <div className="flex bg-sl-surface rounded-lg p-0.5">
            <button
              onClick={() => handleUnitChange('kg')}
              className={`px-4 py-2 rounded-lg text-xs font-semibold transition-all ${
                unit === 'kg' ? 'bg-sl-green text-white' : 'text-sl-textMuted'
              }`}>kg</button>
            <button
              onClick={() => handleUnitChange('lbs')}
              className={`px-4 py-2 rounded-lg text-xs font-semibold transition-all ${
                unit === 'lbs' ? 'bg-sl-green text-white' : 'text-sl-textMuted'
              }`}>lbs</button>
          </div>
        </div>
      </div>

      {/* Menu Items */}
      <div className="space-y-1">
        {menuItems.map(item => (
          <Link key={item.to} to={item.to} className="flex items-center gap-3 px-4 py-3.5 rounded-xl hover:bg-sl-card transition-colors" id={`menu-${item.label.split(' ')[0].toLowerCase()}`}>
            <item.icon className={`text-lg ${item.color}`} />
            <div className="flex-1">
              <p className="text-sm font-semibold text-sl-text">{item.label}</p>
              <p className="text-xs text-sl-textMuted">{item.desc}</p>
            </div>
            <HiChevronRight className="text-sl-textMuted" />
          </Link>
        ))}
      </div>

      {/* Logout */}
      <button onClick={logout} className="w-full card p-4 flex items-center justify-center gap-2 text-sl-red font-semibold text-sm hover:bg-sl-red/5 transition-colors" id="logout-btn">
        <HiLogout /> Log Out
      </button>

      <p className="text-center text-[10px] text-sl-textMuted pb-4">
        StrengthLog Clone v1.0 • Built with 💪
      </p>
    </div>
  );
}
