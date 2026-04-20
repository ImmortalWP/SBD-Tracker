const express = require('express');
const router = express.Router();
const Exercise = require('../models/Exercise');
const PersonalRecord = require('../models/PersonalRecord');
const auth = require('../middleware/authMiddleware');

router.use(auth);

// GET /api/exercises — list all exercises (default + user custom)
router.get('/', async (req, res) => {
  try {
    const { muscle, category, search } = req.query;
    const filter = {
      $or: [
        { isDefault: true },
        { isCustom: true, userId: req.userId },
      ],
    };

    if (muscle) {
      filter.primaryMuscles = muscle;
    }
    if (category) {
      filter.category = category;
    }

    let exercises;
    if (search) {
      exercises = await Exercise.find({
        ...filter,
        name: { $regex: search, $options: 'i' },
      }).sort({ name: 1 }).limit(100);
    } else {
      exercises = await Exercise.find(filter).sort({ name: 1 });
    }

    res.json(exercises);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/exercises/:id
router.get('/:id', async (req, res) => {
  try {
    const exercise = await Exercise.findById(req.params.id);
    if (!exercise) return res.status(404).json({ error: 'Exercise not found' });
    res.json(exercise);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/exercises — create custom exercise
router.post('/', async (req, res) => {
  try {
    const exercise = await Exercise.create({
      ...req.body,
      isCustom: true,
      isDefault: false,
      userId: req.userId,
    });
    res.status(201).json(exercise);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/exercises/:id — delete custom exercise only
router.delete('/:id', async (req, res) => {
  try {
    const exercise = await Exercise.findOneAndDelete({
      _id: req.params.id,
      isCustom: true,
      userId: req.userId,
    });
    if (!exercise) return res.status(404).json({ error: 'Cannot delete this exercise' });
    res.json({ message: 'Exercise deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/exercises/:id/records — PRs for this exercise
router.get('/:id/records', async (req, res) => {
  try {
    const records = await PersonalRecord.find({
      user: req.userId,
      exerciseId: req.params.id,
    }).sort({ reps: 1 });
    res.json(records);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
