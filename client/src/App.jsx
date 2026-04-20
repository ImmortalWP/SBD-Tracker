import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import BottomTabBar from './components/BottomTabBar';
import Login from './pages/Login';
import Home from './pages/Home';
import WorkoutActive from './pages/WorkoutActive';
import History from './pages/History';
import Exercises from './pages/Exercises';
import ExerciseDetail from './pages/ExerciseDetail';
import Programs from './pages/Programs';
import ProgramDetail from './pages/ProgramDetail';
import Stats from './pages/Stats';
import Calculators from './pages/Calculators';
import BodyMetrics from './pages/BodyMetrics';
import Profile from './pages/Profile';

function ProtectedRoute({ children }) {
  const { isAuthenticated } = useAuth();
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return children;
}

function AuthRoute({ children }) {
  const { isAuthenticated } = useAuth();
  if (isAuthenticated) return <Navigate to="/" replace />;
  return children;
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<AuthRoute><Login /></AuthRoute>} />
      <Route path="/*" element={
        <ProtectedRoute>
          <div className="min-h-screen bg-sl-bg pb-20">
            <main className="max-w-lg mx-auto px-4 py-4">
              <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/workout" element={<WorkoutActive />} />
                <Route path="/workout/:id" element={<WorkoutActive />} />
                <Route path="/history" element={<History />} />
                <Route path="/exercises" element={<Exercises />} />
                <Route path="/exercises/:id" element={<ExerciseDetail />} />
                <Route path="/programs" element={<Programs />} />
                <Route path="/programs/:id" element={<ProgramDetail />} />
                <Route path="/stats" element={<Stats />} />
                <Route path="/calculators" element={<Calculators />} />
                <Route path="/body" element={<BodyMetrics />} />
                <Route path="/profile" element={<Profile />} />
              </Routes>
            </main>
            <BottomTabBar />
          </div>
        </ProtectedRoute>
      } />
    </Routes>
  );
}

export default function App() {
  return (
    <Router>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </Router>
  );
}
