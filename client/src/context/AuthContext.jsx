import { createContext, useContext, useState, useEffect } from 'react';

const AuthContext = createContext(null);

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}

function parseToken(token) {
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    // Check if expired
    if (payload.exp * 1000 < Date.now()) return null;
    return { userId: payload.userId, username: payload.username };
  } catch {
    return null;
  }
}

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => localStorage.getItem('sbd_token'));
  const [user, setUser] = useState(() => {
    const t = localStorage.getItem('sbd_token');
    return t ? parseToken(t) : null;
  });

  useEffect(() => {
    if (token) {
      const parsed = parseToken(token);
      if (parsed) {
        localStorage.setItem('sbd_token', token);
        setUser(parsed);
      } else {
        // Token expired or invalid
        localStorage.removeItem('sbd_token');
        setToken(null);
        setUser(null);
      }
    } else {
      localStorage.removeItem('sbd_token');
      setUser(null);
    }
  }, [token]);

  const login = (newToken) => {
    setToken(newToken);
  };

  const logout = () => {
    setToken(null);
  };

  return (
    <AuthContext.Provider value={{ user, token, login, logout, isAuthenticated: !!user }}>
      {children}
    </AuthContext.Provider>
  );
}
