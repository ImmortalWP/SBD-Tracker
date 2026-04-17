const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Session = require('../models/Session');
const User = require('../models/User');
const auth = require('../middleware/authMiddleware');

// All routes require authentication
router.use(auth);

// GET /api/leaderboard — PRs for all users, ranked by total
router.get('/', async (req, res) => {
  try {
    const users = await User.find({}, '_id username');
    const mainLifts = ['Squat', 'Bench', 'Deadlift'];
    const leaderboard = [];

    for (const user of users) {
      const entry = {
        userId: user._id,
        username: user.username,
        Squat: 0,
        Bench: 0,
        Deadlift: 0,
        total: 0,
      };

      for (const lift of mainLifts) {
        const result = await Session.aggregate([
          { $match: { user: new mongoose.Types.ObjectId(user._id) } },
          { $unwind: '$exercises' },
          { $match: { 'exercises.name': lift, 'exercises.category': 'main' } },
          { $unwind: '$exercises.sets' },
          { $group: { _id: null, maxWeight: { $max: '$exercises.sets.weight' } } },
        ]);
        entry[lift] = result.length > 0 ? result[0].maxWeight : 0;
      }

      entry.total = entry.Squat + entry.Bench + entry.Deadlift;

      // Only include users who have logged at least one lift
      if (entry.total > 0) {
        leaderboard.push(entry);
      }
    }

    // Sort by total descending
    leaderboard.sort((a, b) => b.total - a.total);

    res.json(leaderboard);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
