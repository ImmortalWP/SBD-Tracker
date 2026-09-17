const express = require('express');
const jwt = require('jsonwebtoken');
const router = express.Router();
const User = require('../models/User');
const Session = require('../models/Session');
const { authLimiter } = require('../middleware/rateLimiter');
const { sanitizeString } = require('../middleware/validators');

const generateToken = (user) => {
  return jwt.sign(
    { userId: user._id, username: user.username },
    process.env.JWT_SECRET,
    { expiresIn: '7d', algorithm: 'HS256' } // Explicitly HS256 — prevents algorithm confusion
  );
};

// ─── Rate limit auth endpoints ───
router.use(authLimiter);

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    // Whitelist only username and password — block mass assignment
    const username = sanitizeString(req.body.username, 20);
    const password = req.body.password;

    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required.' });
    }

    if (username.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters.' });
    }

    if (!/^[a-zA-Z0-9_]+$/.test(username)) {
      return res.status(400).json({ error: 'Username may only contain letters, numbers, and underscores.' });
    }

    if (typeof password !== 'string' || password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
    }

    if (password.length > 128) {
      return res.status(400).json({ error: 'Password must be at most 128 characters.' });
    }

    // Check if username already exists
    const existing = await User.findOne({ username: username.toLowerCase() });
    if (existing) {
      return res.status(400).json({ error: 'Username already taken.' });
    }

    // Create with only safe fields
    const user = await User.create({ username, password });

    // Migrate orphaned sessions (no user field) to the first registered user
    const userCount = await User.countDocuments();
    if (userCount === 1) {
      const migrated = await Session.updateMany(
        { user: { $exists: false } },
        { $set: { user: user._id } }
      );
      if (migrated.modifiedCount > 0) {
        console.log(`📦 Migrated ${migrated.modifiedCount} orphan sessions to user "${user.username}"`);
      }
    }

    const token = generateToken(user);
    // Return only safe user fields
    res.status(201).json({
      token,
      user: {
        _id: user._id,
        username: user.username,
        createdAt: user.createdAt,
      },
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Registration failed. Please try again.' });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const username = sanitizeString(req.body.username, 20);
    const password = req.body.password;

    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required.' });
    }

    // Generic error for both invalid username and password — prevents user enumeration
    const genericError = 'Invalid username or password.';

    const user = await User.findOne({ username: username.toLowerCase() });
    if (!user) {
      return res.status(401).json({ error: genericError });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ error: genericError });
    }

    const token = generateToken(user);
    // Return only safe user fields
    res.json({
      token,
      user: {
        _id: user._id,
        username: user.username,
        unit: user.unit,
        createdAt: user.createdAt,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed. Please try again.' });
  }
});

module.exports = router;
