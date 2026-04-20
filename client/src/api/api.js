import axios from 'axios';

const API = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'https://sbd-tracker.onrender.com/api',
});

// Attach auth token
API.interceptors.request.use((config) => {
  const token = localStorage.getItem('sl_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// ====== AUTH ======
export const loginUser = (data) => API.post('/auth/login', data);
export const registerUser = (data) => API.post('/auth/register', data);

// ====== WORKOUTS ======
export const getWorkouts = (params) => API.get('/workouts', { params });
export const getWorkout = (id) => API.get(`/workouts/${id}`);
export const createWorkout = (data) => API.post('/workouts', data);
export const updateWorkout = (id, data) => API.put(`/workouts/${id}`, data);
export const deleteWorkout = (id) => API.delete(`/workouts/${id}`);
export const getExerciseHistory = (exerciseId) => API.get(`/workouts/exercise/${exerciseId}/history`);

// ====== EXERCISES ======
export const getExercises = (params) => API.get('/exercises', { params });
export const getExercise = (id) => API.get(`/exercises/${id}`);
export const createExercise = (data) => API.post('/exercises', data);
export const deleteExercise = (id) => API.delete(`/exercises/${id}`);
export const getExerciseRecords = (id) => API.get(`/exercises/${id}/records`);

// ====== PROGRAMS ======
export const getPrograms = () => API.get('/programs');
export const getProgram = (id) => API.get(`/programs/${id}`);
export const createProgram = (data) => API.post('/programs', data);
export const startProgram = (id) => API.post(`/programs/${id}/start`);
export const stopProgram = (id) => API.post(`/programs/${id}/stop`);
export const updateProgramProgress = (id, data) => API.put(`/programs/${id}/progress`, data);
export const getActiveProgram = () => API.get('/programs/user/active');

// ====== STATS ======
export const getStatsOverview = () => API.get('/stats/overview');
export const getMuscleMap = (days) => API.get('/stats/muscle-map', { params: { days } });
export const getPersonalRecords = () => API.get('/stats/prs');
export const getVolumeStats = (period) => API.get('/stats/volume', { params: { period } });

// ====== BODY METRICS ======
export const getBodyMetrics = (params) => API.get('/bodymetrics', { params });
export const createBodyMetric = (data) => API.post('/bodymetrics', data);
export const updateBodyMetric = (id, data) => API.put(`/bodymetrics/${id}`, data);
export const deleteBodyMetric = (id) => API.delete(`/bodymetrics/${id}`);

// ====== PROFILE ======
export const getProfile = () => API.get('/profile');
export const updateProfile = (data) => API.put('/profile', data);

export default API;
