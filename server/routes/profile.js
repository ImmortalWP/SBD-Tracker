const express = require('express');
const router = express.Router();
const User = require('../models/User');
const auth = require('../middleware/authMiddleware');
const { pickFields, validateProfileInput, sanitizeString, validateNumber } = require('../middleware/validators');

// Use shared auth middleware — not inline duplicate
// GET profile
router.get('/', auth, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });
    // Return only safe, necessary fields — never expose password hash or internal fields
    res.json({
      username: user.username,
      bodyWeight: user.bodyWeight,
      height: user.height,
      weightClass: user.weightClass,
      unit: user.unit || 'kg',
      weightHistory: user.weightHistory || [],
      prHistory: user.prHistory || [],
      createdAt: user.createdAt,
    });
  } catch (err) {
    console.error('GET /profile error:', err);
    res.status(500).json({ error: 'Failed to load profile.' });
  }
});

// PUT update profile
router.put('/', auth, async (req, res) => {
  try {
    // Whitelist only allowed profile fields — prevents mass assignment
    // Blocks: username, password, _id, createdAt, updatedAt, __v, role, admin, etc.
    const data = pickFields(req.body, ['bodyWeight', 'height', 'weightClass', 'unit']);

    const errors = validateProfileInput(data);
    if (errors.length > 0) {
      return res.status(400).json({ error: errors.join('; ') });
    }

    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    if (data.bodyWeight !== undefined) {
      const bw = validateNumber(data.bodyWeight, { min: 10, max: 500 });
      if (bw !== null) {
        user.bodyWeight = bw;
        // Add to weight history
        user.weightHistory = user.weightHistory || [];
        // Limit history length to prevent unbounded growth
        if (user.weightHistory.length > 1000) {
          user.weightHistory = user.weightHistory.slice(-500);
        }
        user.weightHistory.push({ weight: bw, date: new Date() });
      }
    }
    if (data.height !== undefined) {
      const h = validateNumber(data.height, { min: 50, max: 300 });
      if (h !== null) user.height = h;
    }
    if (data.weightClass !== undefined) {
      user.weightClass = sanitizeString(data.weightClass, 20);
    }
    if (data.unit !== undefined && ['kg', 'lbs'].includes(data.unit)) {
      user.unit = data.unit;
    }

    await user.save();
    // Return only safe fields
    res.json({
      username: user.username,
      bodyWeight: user.bodyWeight,
      height: user.height,
      weightClass: user.weightClass,
      unit: user.unit,
      weightHistory: user.weightHistory,
    });
  } catch (err) {
    console.error('PUT /profile error:', err);
    res.status(500).json({ error: 'Failed to update profile.' });
  }
});



module.exports = router;
