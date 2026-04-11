import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import Dashboard from './pages/Dashboard';
import Sessions from './pages/Sessions';
import AddSession from './pages/AddSession';
import EditSession from './pages/EditSession';
import Analytics from './pages/Analytics';

export default function App() {
  return (
    <Router>
      <div className="min-h-screen bg-gym-950">
        <Navbar />
        <main className="max-w-6xl mx-auto px-4 py-8">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/sessions" element={<Sessions />} />
            <Route path="/add" element={<AddSession />} />
            <Route path="/edit/:id" element={<EditSession />} />
            <Route path="/analytics" element={<Analytics />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}
