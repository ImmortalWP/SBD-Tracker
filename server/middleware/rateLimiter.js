const rateLimit = require('express-rate-limit');

/**
 * Rate limiter for authentication endpoints (login, register).
 * Strict limits to prevent brute-force attacks.
 */
const authLimiter = rateLimit({
  windowMs: parseInt(process.env.AUTH_RATE_LIMIT_WINDOW_MS, 10) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.AUTH_RATE_LIMIT_MAX, 10) || 10, // 10 attempts per window
  standardHeaders: true,
  legacyHeaders: false,
  // Use generic message — do not reveal whether account exists
  message: { error: 'Too many attempts. Please try again later.' },
  keyGenerator: (req) => {
    // Rate limit by IP + username to prevent both IP-based and account-based brute force
    const ip = req.ip || req.socket.remoteAddress;
    const username = (req.body && req.body.username) ? req.body.username.toLowerCase() : '';
    return `${ip}:${username}`;
  },
});

/**
 * General API rate limiter.
 * More permissive for authenticated API usage.
 */
const apiLimiter = rateLimit({
  windowMs: parseInt(process.env.API_RATE_LIMIT_WINDOW_MS, 10) || 60 * 1000, // 1 minute
  max: parseInt(process.env.API_RATE_LIMIT_MAX, 10) || 100, // 100 requests per minute
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Rate limit exceeded. Please slow down.' },
});

module.exports = { authLimiter, apiLimiter };
