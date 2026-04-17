const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Auth middleware
function auth(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token provided' });
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.userId;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// GET profile
router.get('/', auth, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({
      username: user.username,
      bodyWeight: user.bodyWeight,
      height: user.height,
      weightClass: user.weightClass,
      unit: user.unit || 'kg',
      weightHistory: user.weightHistory || [],
      createdAt: user.createdAt,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT update profile
router.put('/', auth, async (req, res) => {
  try {
    const { bodyWeight, height, weightClass, unit } = req.body;
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    if (bodyWeight !== undefined) {
      user.bodyWeight = bodyWeight;
      // Add to weight history
      user.weightHistory = user.weightHistory || [];
      user.weightHistory.push({ weight: bodyWeight, date: new Date() });
    }
    if (height !== undefined) user.height = height;
    if (weightClass !== undefined) user.weightClass = weightClass;
    if (unit !== undefined) user.unit = unit;

    await user.save();
    res.json({
      username: user.username,
      bodyWeight: user.bodyWeight,
      height: user.height,
      weightClass: user.weightClass,
      unit: user.unit,
      weightHistory: user.weightHistory,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
