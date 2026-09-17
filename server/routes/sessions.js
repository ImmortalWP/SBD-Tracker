const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Session = require('../models/Session');
const auth = require('../middleware/authMiddleware');
const { escapeRegex, sanitizeString, pickFields, isValidObjectId, validateSessionInput } = require('../middleware/validators');

// All routes require authentication
router.use(auth);

// Allowed fields for session create/update — prevents mass assignment
const SESSION_ALLOWED_FIELDS = [
  'clientId', 'block', 'week', 'percentage', 'day', 'date',
  'duration', 'durationInMinutes', 'startTime', 'endTime',
  'exercises', 'notes', 'note', 'intensity', 'sessionRating',
];

// GET /api/sessions — list all, with optional ?block= and ?day= filters
router.get('/', async (req, res) => {
  try {
    const filter = { user: req.userId };

    if (req.query.block) {
      const block = Number(req.query.block);
      if (!Number.isInteger(block) || block < 1 || block > 100) {
        return res.status(400).json({ error: 'Invalid block number' });
      }
      filter.block = block;
    }

    if (req.query.day) {
      // Escape regex to prevent ReDoS / regex injection
      const safeDay = escapeRegex(sanitizeString(req.query.day, 50));
      if (safeDay) {
        filter.day = { $regex: safeDay, $options: 'i' };
      }
    }

    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit) || 100));
    const skip = (page - 1) * limit;

    const [sessions, total] = await Promise.all([
      Session.find(filter).sort({ date: -1, createdAt: -1 }).skip(skip).limit(limit).lean(),
      Session.countDocuments(filter),
    ]);
    res.json(sessions);
  } catch (err) {
    console.error('GET /sessions error:', err);
    res.status(500).json({ error: 'Failed to load sessions.' });
  }
});

// GET /api/sessions/:id — single session
router.get('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid session ID' });
    }
    // Ownership enforced: user can only access their own sessions
    const session = await Session.findOne({ _id: req.params.id, user: req.userId }).lean();
    if (!session) return res.status(404).json({ error: 'Session not found' });
    res.json(session);
  } catch (err) {
    console.error('GET /sessions/:id error:', err);
    res.status(500).json({ error: 'Failed to load session.' });
  }
});

// POST /api/sessions — create (idempotent via clientId)
router.post('/', async (req, res) => {
  try {
    // Whitelist allowed fields — prevent mass assignment
    const data = pickFields(req.body, SESSION_ALLOWED_FIELDS);

    // Validate input
    const errors = validateSessionInput(data);
    if (errors.length > 0) {
      return res.status(400).json({ error: errors.join('; ') });
    }

    const { clientId, ...rest } = data;

    // If clientId provided, check for duplicate first
    if (clientId) {
      const safeClientId = sanitizeString(clientId, 100);
      const existing = await Session.findOne({ user: req.userId, clientId: safeClientId }).lean();
      if (existing) {
        return res.status(200).json(existing); // Idempotent — return existing
      }
      rest.clientId = safeClientId;
    }

    // Server sets ownership — never trust client-provided user ID
    const session = await Session.create({
      ...rest,
      user: req.userId,
    });
    res.status(201).json(session);
  } catch (err) {
    // Handle race condition: concurrent duplicate clientId insert
    if (err.code === 11000 && req.body.clientId) {
      try {
        const existing = await Session.findOne({ user: req.userId, clientId: req.body.clientId }).lean();
        if (existing) {
          return res.status(200).json(existing);
        }
      } catch (_) { /* fall through */ }
    }
    console.error('POST /sessions error:', err);
    res.status(400).json({ error: 'Failed to create session.' });
  }
});

// PUT /api/sessions/:id — update
router.put('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid session ID' });
    }

    // Whitelist allowed fields — prevent mass assignment of user, _id, etc.
    const data = pickFields(req.body, SESSION_ALLOWED_FIELDS);

    // Prevent overwriting ownership
    delete data.user;

    // Validate input
    const errors = validateSessionInput(data);
    if (errors.length > 0) {
      return res.status(400).json({ error: errors.join('; ') });
    }

    // Ownership enforced in query
    const session = await Session.findOneAndUpdate(
      { _id: req.params.id, user: req.userId },
      data,
      { new: true, runValidators: true }
    );
    if (!session) return res.status(404).json({ error: 'Session not found' });
    res.json(session);
  } catch (err) {
    console.error('PUT /sessions/:id error:', err);
    res.status(400).json({ error: 'Failed to update session.' });
  }
});

// DELETE /api/sessions/:id
router.delete('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid session ID' });
    }
    // Ownership enforced in query
    const session = await Session.findOneAndDelete({ _id: req.params.id, user: req.userId });
    if (!session) return res.status(404).json({ error: 'Session not found' });
    res.json({ message: 'Session deleted' });
  } catch (err) {
    console.error('DELETE /sessions/:id error:', err);
    res.status(500).json({ error: 'Failed to delete session.' });
  }
});

// GET /api/sessions/stats/prs — personal records for main lifts
router.get('/stats/prs', async (req, res) => {
  try {
    const userId = new mongoose.Types.ObjectId(req.userId);
    // Single aggregation with $facet — 3x fewer DB roundtrips
    const result = await Session.aggregate([
      { $match: { user: userId } },
      { $unwind: '$exercises' },
      { $match: { 'exercises.category': 'main' } },
      { $unwind: '$exercises.sets' },
      {
        $facet: {
          Squat: [
            { $match: { 'exercises.name': 'Squat' } },
            { $group: { _id: null, maxWeight: { $max: '$exercises.sets.weight' } } },
          ],
          Bench: [
            { $match: { 'exercises.name': 'Bench' } },
            { $group: { _id: null, maxWeight: { $max: '$exercises.sets.weight' } } },
          ],
          Deadlift: [
            { $match: { 'exercises.name': 'Deadlift' } },
            { $group: { _id: null, maxWeight: { $max: '$exercises.sets.weight' } } },
          ],
        },
      },
    ]);

    const facets = result[0] || {};
    const prs = {
      Squat: facets.Squat?.[0]?.maxWeight || 0,
      Bench: facets.Bench?.[0]?.maxWeight || 0,
      Deadlift: facets.Deadlift?.[0]?.maxWeight || 0,
    };

    res.json(prs);
  } catch (err) {
    console.error('GET /sessions/stats/prs error:', err);
    res.status(500).json({ error: 'Failed to load personal records.' });
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
    console.error('GET /sessions/stats/analytics error:', err);
    res.status(500).json({ error: 'Failed to load analytics.' });
  }
});

module.exports = router;
