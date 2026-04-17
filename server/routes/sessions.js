const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Session = require('../models/Session');
const auth = require('../middleware/authMiddleware');

// All routes require authentication
router.use(auth);

// GET /api/sessions — list all, with optional ?block= and ?day= filters
router.get('/', async (req, res) => {
  try {
    const filter = { user: req.userId };
    if (req.query.block) filter.block = Number(req.query.block);
    if (req.query.day) filter.day = { $regex: req.query.day, $options: 'i' };

    const sessions = await Session.find(filter).sort({ block: 1, createdAt: -1 });
    res.json(sessions);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/sessions/:id — single session
router.get('/:id', async (req, res) => {
  try {
    const session = await Session.findOne({ _id: req.params.id, user: req.userId });
    if (!session) return res.status(404).json({ error: 'Session not found' });
    res.json(session);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/sessions — create
router.post('/', async (req, res) => {
  try {
    const session = await Session.create({ ...req.body, user: req.userId });
    res.status(201).json(session);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// PUT /api/sessions/:id — update
router.put('/:id', async (req, res) => {
  try {
    const session = await Session.findOneAndUpdate(
      { _id: req.params.id, user: req.userId },
      req.body,
      { new: true, runValidators: true }
    );
    if (!session) return res.status(404).json({ error: 'Session not found' });
    res.json(session);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/sessions/:id
router.delete('/:id', async (req, res) => {
  try {
    const session = await Session.findOneAndDelete({ _id: req.params.id, user: req.userId });
    if (!session) return res.status(404).json({ error: 'Session not found' });
    res.json({ message: 'Session deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/sessions/stats/prs — personal records for main lifts
router.get('/stats/prs', async (req, res) => {
  try {
    const mainLifts = ['Squat', 'Bench', 'Deadlift'];
    const prs = {};

    for (const lift of mainLifts) {
      const result = await Session.aggregate([
        { $match: { user: new mongoose.Types.ObjectId(req.userId) } },
        { $unwind: '$exercises' },
        // Exact match instead of regex, so variations don't artificially lower/raise the main PR
        { $match: { 'exercises.name': lift, 'exercises.category': 'main' } },
        { $unwind: '$exercises.sets' },
        { $group: { _id: null, maxWeight: { $max: '$exercises.sets.weight' } } },
      ]);
      prs[lift] = result.length > 0 ? result[0].maxWeight : 0;
    }

    res.json(prs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/sessions/stats/analytics — summary analytics
router.get('/stats/analytics', async (req, res) => {
  try {
    const totalSessions = await Session.countDocuments({ user: req.userId });
    const blocks = await Session.distinct('block', { user: req.userId });

    // Sessions per block
    const sessionsPerBlock = await Session.aggregate([
      { $match: { user: new mongoose.Types.ObjectId(req.userId) } },
      { $group: { _id: '$block', count: { $sum: 1 } } },
      { $sort: { _id: 1 } },
    ]);

    // Total volume per main lift group (main lift + secondary variations)
    const liftGroups = {
      Squat: ['Squat', 'Pause Squat', 'Tempo Squat', 'Pin Squat', 'Box Squat'],
      Bench: ['Bench', 'Pause Bench', 'Close Grip Larsen', 'Pin Bench'],
      Deadlift: ['Deadlift', 'Pause Deadlift', 'Deficit Deadlift']
    };
    
    const volume = {};

    const progressionMap = {};

    for (const lift of Object.keys(liftGroups)) {
      const aliases = liftGroups[lift];
      const result = await Session.aggregate([
        { $match: { user: new mongoose.Types.ObjectId(req.userId) } },
        { $unwind: '$exercises' },
        { $match: { 'exercises.name': { $in: aliases } } },
        { $unwind: '$exercises.sets' },
        {
          $group: {
            _id: '$block',
            totalVolume: {
              $sum: { $multiply: ['$exercises.sets.weight', '$exercises.sets.sets', '$exercises.sets.reps'] },
            },
          },
        },
      ]);
      
      // Add to overall volume
      volume[lift] = result.reduce((acc, curr) => acc + curr.totalVolume, 0);

      // Add to progression map
      result.forEach(r => {
        if (!progressionMap[r._id]) progressionMap[r._id] = { blockId: r._id, block: `Block ${r._id}`, Squat: 0, Bench: 0, Deadlift: 0 };
        progressionMap[r._id][lift] = r.totalVolume;
      });
    }

    const volumeProgression = Object.values(progressionMap).sort((a, b) => a.blockId - b.blockId);

    res.json({ totalSessions, totalBlocks: blocks.length, sessionsPerBlock, volume, volumeProgression });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
