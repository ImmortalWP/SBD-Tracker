import { NavLink } from 'react-router-dom';
import { GiWeightLiftingUp } from 'react-icons/gi';
import { HiHome, HiClipboardList, HiPlusCircle, HiChartBar } from 'react-icons/hi';

const navLinks = [
  { to: '/', label: 'Dashboard', icon: HiHome },
  { to: '/sessions', label: 'Sessions', icon: HiClipboardList },
  { to: '/add', label: 'Log Session', icon: HiPlusCircle },
  { to: '/analytics', label: 'Analytics', icon: HiChartBar },
];

export default function Navbar() {
  return (
    <nav className="sticky top-0 z-50 bg-gym-950/80 backdrop-blur-xl border-b border-gym-800/50">
      <div className="max-w-6xl mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <NavLink to="/" className="flex items-center gap-2.5 group">
            <div className="w-9 h-9 rounded-lg bg-accent-red/15 border border-accent-red/25 flex items-center justify-center group-hover:bg-accent-red/25 transition-colors duration-200">
              <GiWeightLiftingUp className="text-accent-red text-lg" />
            </div>
            <div>
              <span className="text-lg font-extrabold tracking-tight text-gym-50">
                SBD
              </span>
              <span className="hidden sm:inline text-xs text-gym-500 ml-2 font-medium">
                Training Log
              </span>
            </div>
          </NavLink>

          {/* Nav Links */}
          <div className="flex items-center gap-1">
            {navLinks.map(({ to, label, icon: Icon }) => (
              <NavLink
                key={to}
                to={to}
                className={({ isActive }) =>
                  `flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                    isActive
                      ? 'bg-accent-red/10 text-accent-red'
                      : 'text-gym-400 hover:text-gym-200 hover:bg-gym-800/50'
                  }`
                }
              >
                <Icon className="text-base" />
                <span className="hidden md:inline">{label}</span>
              </NavLink>
            ))}
          </div>
        </div>
      </div>
    </nav>
  );
}
