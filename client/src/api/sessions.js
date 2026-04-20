import axios from 'axios';
import { cacheSet, cacheGet, makeCacheKey, cacheClearPattern } from '../utils/cache';
import { enqueue, isOnline } from '../utils/offlineQueue';

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

// Cache GET responses automatically
API.interceptors.response.use((response) => {
  if (response.config.method === 'get') {
    const key = makeCacheKey(response.config.url, response.config.params);
    cacheSet(key, response.data);
  }
  return response;
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

// Leaderboard
export const getLeaderboard = () => API.get('/leaderboard');

// --- Cache helpers for pages ---

/**
 * Get cached API data by key.
 */
export function getCached(url, params) {
  const key = makeCacheKey(url, params);
  return cacheGet(key);
}

/**
 * Invalidate session-related caches after mutations.
 */
export function invalidateSessionCaches() {
  cacheClearPattern('sessions');
  cacheClearPattern('stats');
  cacheClearPattern('leaderboard');
}

/**
 * Queue a create-session mutation for offline sync.
 * Returns a temporary local session object for optimistic UI.
 */
export function offlineCreateSession(data) {
  const tempId = 'temp_' + crypto.randomUUID();
  enqueue({
    type: 'create',
    url: '/sessions',
    data,
  });
  // Return a fake session for optimistic UI
  return {
    _id: tempId,
    ...data,
    _offline: true,
    createdAt: new Date().toISOString(),
  };
}

/**
 * Queue an update-session mutation for offline sync.
 */
export function offlineUpdateSession(id, data) {
  enqueue({
    type: 'update',
    url: `/sessions/${id}`,
    data,
  });
}

/**
 * Queue a delete-session mutation for offline sync.
 */
export function offlineDeleteSession(id) {
  enqueue({
    type: 'delete',
    url: `/sessions/${id}`,
  });
}

export default API;
