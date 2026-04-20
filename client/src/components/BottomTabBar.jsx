import { NavLink, useLocation } from 'react-router-dom';
import { HiHome, HiClock, HiCollection, HiPlus, HiDotsHorizontal } from 'react-icons/hi';
import { GiMuscleUp } from 'react-icons/gi';

const tabs = [
  { to: '/', icon: HiHome, label: 'Home' },
  { to: '/history', icon: HiClock, label: 'History' },
  { to: '/workout', icon: HiPlus, label: 'Workout', isFab: true },
  { to: '/exercises', icon: GiMuscleUp, label: 'Exercises' },
  { to: '/profile', icon: HiDotsHorizontal, label: 'More' },
];

export default function BottomTabBar() {
  const location = useLocation();
  // Hide tab bar during active workout
  if (location.pathname.startsWith('/workout')) return null;

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 bg-sl-card/95 backdrop-blur-xl border-t border-sl-border" id="bottom-tab-bar">
      <div className="max-w-lg mx-auto flex items-end justify-around px-2 pt-1 pb-1" style={{ paddingBottom: 'max(0.25rem, env(safe-area-inset-bottom))' }}>
        {tabs.map(({ to, icon: Icon, label, isFab }) => {
          const isActive = location.pathname === to || (to !== '/' && location.pathname.startsWith(to));

          if (isFab) {
            return (
              <NavLink key={to} to={to} className="flex flex-col items-center -mt-5" id="tab-workout">
                <div className="fab w-12 h-12 text-xl shadow-glow">
                  <Icon />
                </div>
                <span className="text-[10px] font-medium text-sl-green mt-0.5">{label}</span>
              </NavLink>
            );
          }

          return (
            <NavLink key={to} to={to} className={`tab-item ${isActive ? 'active' : ''}`} id={`tab-${label.toLowerCase()}`}>
              <Icon className="tab-icon" />
              <span>{label}</span>
            </NavLink>
          );
        })}
      </div>
    </nav>
  );
}
