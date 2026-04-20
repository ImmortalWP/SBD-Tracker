const express = require('express');
const router = express.Router();
const Program = require('../models/Program');
const auth = require('../middleware/authMiddleware');

router.use(auth);

// GET /api/programs — list all programs
router.get('/', async (req, res) => {
  try {
    const programs = await Program.find({
      $or: [
        { isDefault: true },
        { isCustom: true, userId: req.userId },
      ],
    }).select('-schedule').sort({ name: 1 });
    res.json(programs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/programs/:id — get full program with schedule
router.get('/:id', async (req, res) => {
  try {
    const program = await Program.findById(req.params.id);
    if (!program) return res.status(404).json({ error: 'Program not found' });
    res.json(program);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/programs — create custom program
router.post('/', async (req, res) => {
  try {
    const program = await Program.create({
      ...req.body,
      isCustom: true,
      isDefault: false,
      userId: req.userId,
    });
    res.status(201).json(program);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// POST /api/programs/:id/start — start following a program
router.post('/:id/start', async (req, res) => {
  try {
    const program = await Program.findById(req.params.id);
    if (!program) return res.status(404).json({ error: 'Program not found' });

    // Remove existing progress
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
    res.json({ message: 'Program started', program });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/programs/:id/progress — update progress
router.put('/:id/progress', async (req, res) => {
  try {
    const program = await Program.findById(req.params.id);
    if (!program) return res.status(404).json({ error: 'Program not found' });

    const userProgress = program.activeUsers.find(
      u => u.userId.toString() === req.userId
    );
    if (!userProgress) return res.status(400).json({ error: 'Not following this program' });

    if (req.body.currentWeek) userProgress.currentWeek = req.body.currentWeek;
    if (req.body.currentDay) userProgress.currentDay = req.body.currentDay;

    await program.save();
    res.json({ message: 'Progress updated', userProgress });
  } catch (err) {
    res.status(500).json({ error: err.message });
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

    res.json({ program, progress: userProgress });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/programs/:id/stop — stop following a program
router.post('/:id/stop', async (req, res) => {
  try {
    const program = await Program.findById(req.params.id);
    if (!program) return res.status(404).json({ error: 'Program not found' });

    program.activeUsers = program.activeUsers.filter(
      u => u.userId.toString() !== req.userId
    );
    await program.save();
    res.json({ message: 'Program stopped' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
