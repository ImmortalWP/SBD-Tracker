const express = require('express');
const router = express.Router();
const Program = require('../models/Program');
const auth = require('../middleware/authMiddleware');
const { pickFields, isValidObjectId, validateNumber, sanitizeString } = require('../middleware/validators');

router.use(auth);

// Allowed fields for custom program creation
const PROGRAM_ALLOWED_FIELDS = [
  'name', 'description', 'category', 'difficulty',
  'weeks', 'daysPerWeek', 'schedule',
];

// Valid enum values
const VALID_CATEGORIES = ['Strength', 'Hypertrophy', 'Powerlifting', 'Bodybuilding', 'General', 'Powerbuilding', 'Beginner', 'Athletic'];
const VALID_DIFFICULTIES = ['Beginner', 'Intermediate', 'Advanced'];

/**
 * Strip other users' data from activeUsers array.
 * Only return the requesting user's own progress.
 */
function stripOtherUsersProgress(program, userId) {
  if (!program) return program;
  const obj = program.toObject ? program.toObject() : { ...program };
  if (obj.activeUsers) {
    obj.activeUsers = obj.activeUsers.filter(
      u => u.userId && u.userId.toString() === userId
    );
  }
  return obj;
}

// GET /api/programs — list all programs
router.get('/', async (req, res) => {
  try {
    const programs = await Program.find({
      $or: [
        { isDefault: true },
        { isCustom: true, userId: req.userId },
      ],
    }).select('-schedule').sort({ name: 1 }).lean();

    // Strip other users' progress data
    const safePrograms = programs.map(p => {
      if (p.activeUsers) {
        p.activeUsers = p.activeUsers.filter(
          u => u.userId && u.userId.toString() === req.userId
        );
      }
      return p;
    });

    res.json(safePrograms);
  } catch (err) {
    console.error('GET /programs error:', err);
    res.status(500).json({ error: 'Failed to load programs.' });
  }
});

// GET /api/programs/:id — get full program with schedule
router.get('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid program ID' });
    }
    // Allow access to default programs OR user's own custom programs
    const program = await Program.findOne({
      _id: req.params.id,
      $or: [
        { isDefault: true },
        { isCustom: true, userId: req.userId },
      ],
    });
    if (!program) return res.status(404).json({ error: 'Program not found' });
    // Strip other users' progress
    res.json(stripOtherUsersProgress(program, req.userId));
  } catch (err) {
    console.error('GET /programs/:id error:', err);
    res.status(500).json({ error: 'Failed to load program.' });
  }
});

// POST /api/programs — create custom program
router.post('/', async (req, res) => {
  try {
    // Whitelist allowed fields — prevent mass assignment
    const data = pickFields(req.body, PROGRAM_ALLOWED_FIELDS);

    if (!data.name || typeof data.name !== 'string' || data.name.trim().length === 0) {
      return res.status(400).json({ error: 'Program name is required' });
    }
    data.name = sanitizeString(data.name, 100);

    if (data.category && !VALID_CATEGORIES.includes(data.category)) {
      return res.status(400).json({ error: 'Invalid category' });
    }
    if (data.difficulty && !VALID_DIFFICULTIES.includes(data.difficulty)) {
      return res.status(400).json({ error: 'Invalid difficulty' });
    }

    // Server-controlled fields
    const program = await Program.create({
      ...data,
      isCustom: true,
      isDefault: false,
      userId: req.userId,
    });
    res.status(201).json(stripOtherUsersProgress(program, req.userId));
  } catch (err) {
    console.error('POST /programs error:', err);
    res.status(400).json({ error: 'Failed to create program.' });
  }
});

// POST /api/programs/:id/start — start following a program
router.post('/:id/start', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid program ID' });
    }
    const program = await Program.findById(req.params.id);
    if (!program) return res.status(404).json({ error: 'Program not found' });

    // Remove existing progress for this user only
    program.activeUsers = program.activeUsers.filter(
      u => u.userId.toString() !== req.userId
    );
    
    program.activeUsers.push({
      userId: req.userId,
      currentWeek: 1,
      currentDay: 1,
      startedAt: new Date(),
    });

    await program.save();
    res.json({ message: 'Program started', program: stripOtherUsersProgress(program, req.userId) });
  } catch (err) {
    console.error('POST /programs/:id/start error:', err);
    res.status(500).json({ error: 'Failed to start program.' });
  }
});

// PUT /api/programs/:id/progress — update progress
router.put('/:id/progress', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid program ID' });
    }
    const program = await Program.findById(req.params.id);
    if (!program) return res.status(404).json({ error: 'Program not found' });

    const userProgress = program.activeUsers.find(
      u => u.userId.toString() === req.userId
    );
    if (!userProgress) return res.status(400).json({ error: 'Not following this program' });

    // Validate and set only allowed progress fields
    if (req.body.currentWeek) {
      const week = validateNumber(req.body.currentWeek, { min: 1, max: 52, integer: true });
      if (week !== null) userProgress.currentWeek = week;
    }
    if (req.body.currentDay) {
      const day = validateNumber(req.body.currentDay, { min: 1, max: 7, integer: true });
      if (day !== null) userProgress.currentDay = day;
    }

    await program.save();
    res.json({ message: 'Progress updated', userProgress });
  } catch (err) {
    console.error('PUT /programs/:id/progress error:', err);
    res.status(500).json({ error: 'Failed to update progress.' });
  }
});

// GET /api/programs/user/active — get active program for user
router.get('/user/active', async (req, res) => {
  try {
    const program = await Program.findOne({
      'activeUsers.userId': req.userId,
    });
    
    if (!program) return res.json(null);
    
    const userProgress = program.activeUsers.find(
      u => u.userId.toString() === req.userId
    );

    // Strip other users' data
    res.json({ program: stripOtherUsersProgress(program, req.userId), progress: userProgress });
  } catch (err) {
    console.error('GET /programs/user/active error:', err);
    res.status(500).json({ error: 'Failed to load active program.' });
  }
});

// POST /api/programs/:id/stop — stop following a program
router.post('/:id/stop', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid program ID' });
    }
    const program = await Program.findById(req.params.id);
    if (!program) return res.status(404).json({ error: 'Program not found' });

    // Only remove the current user's entry
    program.activeUsers = program.activeUsers.filter(
      u => u.userId.toString() !== req.userId
    );
    await program.save();
    res.json({ message: 'Program stopped' });
  } catch (err) {
    console.error('POST /programs/:id/stop error:', err);
    res.status(500).json({ error: 'Failed to stop program.' });
  }
});

module.exports = router;
