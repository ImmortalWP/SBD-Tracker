import { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import OfflineBanner from './components/OfflineBanner';
import Dashboard from './pages/Dashboard';
import Sessions from './pages/Sessions';
import AddSession from './pages/AddSession';
import EditSession from './pages/EditSession';
import Analytics from './pages/Analytics';
import Leaderboard from './pages/Leaderboard';
import Login from './pages/Login';
import { initSync } from './utils/syncEngine';

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
  // Initialize sync engine once
  useEffect(() => {
    initSync();
  }, []);

  return (
    <Routes>
      <Route
        path="/login"
        element={
          <AuthRoute>
            <Login />
          </AuthRoute>
        }
      />
      <Route
        path="/*"
        element={
          <ProtectedRoute>
            <div className="min-h-screen bg-gym-950">
              <OfflineBanner />
              <Navbar />
              <main className="max-w-6xl mx-auto px-4 py-8">
                <Routes>
                  <Route path="/" element={<Dashboard />} />
                  <Route path="/sessions" element={<Sessions />} />
                  <Route path="/add" element={<AddSession />} />
                  <Route path="/edit/:id" element={<EditSession />} />
                  <Route path="/analytics" element={<Analytics />} />
                  <Route path="/leaderboard" element={<Leaderboard />} />
                </Routes>
              </main>
            </div>
          </ProtectedRoute>
        }
      />
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
