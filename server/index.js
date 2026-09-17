require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const { apiLimiter } = require('./middleware/rateLimiter');
const sessionRoutes = require('./routes/sessions');
const authRoutes = require('./routes/auth');
const leaderboardRoutes = require('./routes/leaderboard');
const workoutRoutes = require('./routes/workouts');
const exerciseRoutes = require('./routes/exercises');
const programRoutes = require('./routes/programs');
const bodymetricRoutes = require('./routes/bodymetrics');
const statsRoutes = require('./routes/stats');
const profileRoutes = require('./routes/profile');

const app = express();
const PORT = process.env.PORT || 5000;
const isProduction = process.env.NODE_ENV === 'production';

// ─── Security: Validate required env vars at startup ───
if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  console.error('❌ FATAL: JWT_SECRET must be set and at least 32 characters.');
  process.exit(1);
}
if (!process.env.MONGO_URI) {
  console.error('❌ FATAL: MONGO_URI must be set.');
  process.exit(1);
}

// ─── Security: Trust proxy (required for rate limiter behind Render/nginx) ───
if (isProduction) {
  app.set('trust proxy', 1);
}

// ─── Security: Helmet — sets secure HTTP headers ───
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      frameSrc: ["'none'"],
      frameAncestors: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false, // Allow mobile app to connect
  hsts: isProduction ? { maxAge: 31536000, includeSubDomains: true } : false,
}));

// ─── Security: CORS — restrict allowed origins ───
const allowedOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map(o => o.trim())
  : [];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, server-to-server)
    if (!origin) return callback(null, true);
    // In development, allow localhost
    if (!isProduction && (origin.includes('localhost') || origin.includes('127.0.0.1'))) {
      return callback(null, true);
    }
    // Check against allowed origins
    if (allowedOrigins.length > 0 && allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    // In production with no configured origins and no match, deny
    if (isProduction && allowedOrigins.length > 0) {
      return callback(new Error('Not allowed by CORS'));
    }
    // Fallback: allow (for mobile app with no origin header)
    callback(null, true);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  maxAge: 86400,
}));

// ─── Security: Body parsing with size limits ───
app.use(express.json({ limit: '1mb' }));

// ─── Security: NoSQL injection sanitizer (Express v5 compatible) ───
// express-mongo-sanitize is incompatible with Express v5 (req.query is read-only).
// This custom middleware sanitizes req.body and req.params in-place.
// req.query values are validated per-route via validators.js helpers.
function sanitizeObject(obj) {
  if (!obj || typeof obj !== 'object') return;
  for (const key of Object.keys(obj)) {
    if (key.startsWith('$') || key.includes('.')) {
      delete obj[key];
    } else if (typeof obj[key] === 'object' && obj[key] !== null) {
      sanitizeObject(obj[key]);
    }
  }
}
app.use((req, _res, next) => {
  if (req.body) sanitizeObject(req.body);
  if (req.params) sanitizeObject(req.params);
  next();
});

// ─── Security: HTTPS redirect in production ───
if (isProduction) {
  app.use((req, res, next) => {
    if (req.headers['x-forwarded-proto'] !== 'https') {
      return res.redirect(301, `https://${req.headers.host}${req.url}`);
    }
    next();
  });
}

// ─── Security: Global API rate limiter ───
app.use('/api', apiLimiter);

// ─── Routes ───
app.use('/api/auth', authRoutes);
app.use('/api/sessions', sessionRoutes);
app.use('/api/leaderboard', leaderboardRoutes);
app.use('/api/workouts', workoutRoutes);
app.use('/api/exercises', exerciseRoutes);
app.use('/api/programs', programRoutes);
app.use('/api/bodymetrics', bodymetricRoutes);
app.use('/api/stats', statsRoutes);
app.use('/api/profile', profileRoutes);

// Health check (no auth required)
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ─── Security: Catch-all for unmatched routes (don't leak server info) ───
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// ─── Security: Global error handler — never expose stack traces ───
app.use((err, req, res, _next) => {
  // Log full error internally
  console.error('Unhandled error:', err);
  // Return generic error to client
  res.status(err.status || 500).json({
    error: isProduction ? 'An unexpected error occurred.' : err.message,
  });
});

// Connect to MongoDB and start server
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => {
    console.log('✅ MongoDB connected');
    app.listen(PORT, () => {
      console.log(`🏋️ SBD Server running on port ${PORT} (${process.env.NODE_ENV || 'development'})`);
    });
  })
  .catch((err) => {
    // Don't log connection string in production
    console.error('❌ MongoDB connection error:', isProduction ? 'Connection failed' : err.message);
    process.exit(1);
  });
