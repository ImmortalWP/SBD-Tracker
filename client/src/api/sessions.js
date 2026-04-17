import axios from 'axios';

const API = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'https://sbd-tracker.onrender.com/api'
});

// Attach auth token to every request
API.interceptors.request.use((config) => {
  const token = localStorage.getItem('sbd_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Auth
export const loginUser = (data) => API.post('/auth/login', data);
export const registerUser = (data) => API.post('/auth/register', data);

// Sessions CRUD
export const getSessions = (params) => API.get('/sessions', { params });
export const getSession = (id) => API.get(`/sessions/${id}`);
export const createSession = (data) => API.post('/sessions', data);
export const updateSession = (id, data) => API.put(`/sessions/${id}`, data);
export const deleteSession = (id) => API.delete(`/sessions/${id}`);

// Stats
export const getPRs = () => API.get('/sessions/stats/prs');
export const getAnalytics = () => API.get('/sessions/stats/analytics');

export default API;
