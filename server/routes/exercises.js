const express = require('express');
const router = express.Router();
const Exercise = require('../models/Exercise');
const PersonalRecord = require('../models/PersonalRecord');
const auth = require('../middleware/authMiddleware');
const { escapeRegex, sanitizeString, pickFields, isValidObjectId } = require('../middleware/validators');

router.use(auth);

// Allowed fields for custom exercise creation
const EXERCISE_ALLOWED_FIELDS = [
  'name', 'category', 'primaryMuscles', 'secondaryMuscles',
  'instructions', 'equipment',
];

// Valid category values
const VALID_CATEGORIES = ['Barbell', 'Dumbbell', 'Machine', 'Cable', 'Bodyweight', 'Band', 'Cardio', 'Stretching', 'Other'];

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
      const safeMuscle = sanitizeString(muscle, 50);
      if (safeMuscle) filter.primaryMuscles = safeMuscle;
    }
    if (category) {
      const safeCategory = sanitizeString(category, 50);
      if (safeCategory && VALID_CATEGORIES.includes(safeCategory)) {
        filter.category = safeCategory;
      }
    }

    let exercises;
    if (search) {
      // Escape regex to prevent ReDoS / regex injection
      const safeSearch = escapeRegex(sanitizeString(search, 100));
      if (safeSearch) {
        exercises = await Exercise.find({
          ...filter,
          name: { $regex: safeSearch, $options: 'i' },
        }).sort({ name: 1 }).limit(100);
      } else {
        exercises = await Exercise.find(filter).sort({ name: 1 }).limit(100);
      }
    } else {
      exercises = await Exercise.find(filter).sort({ name: 1 });
    }

    res.json(exercises);
  } catch (err) {
    console.error('GET /exercises error:', err);
    res.status(500).json({ error: 'Failed to load exercises.' });
  }
});

// GET /api/exercises/:id
router.get('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid exercise ID' });
    }
    // Ownership check: return default exercises OR user's own custom exercises
    const exercise = await Exercise.findOne({
      _id: req.params.id,
      $or: [
        { isDefault: true },
        { isCustom: true, userId: req.userId },
      ],
    });
    if (!exercise) return res.status(404).json({ error: 'Exercise not found' });
    res.json(exercise);
  } catch (err) {
    console.error('GET /exercises/:id error:', err);
    res.status(500).json({ error: 'Failed to load exercise.' });
  }
});

// POST /api/exercises — create custom exercise
router.post('/', async (req, res) => {
  try {
    // Whitelist allowed fields — prevent mass assignment of isDefault, isCustom, userId
    const data = pickFields(req.body, EXERCISE_ALLOWED_FIELDS);

    // Validate required fields
    if (!data.name || typeof data.name !== 'string' || data.name.trim().length === 0) {
      return res.status(400).json({ error: 'Exercise name is required' });
    }
    data.name = sanitizeString(data.name, 100);

    if (data.category && !VALID_CATEGORIES.includes(data.category)) {
      return res.status(400).json({ error: 'Invalid category' });
    }

    // Server-controlled fields
    const exercise = await Exercise.create({
      ...data,
      isCustom: true,
      isDefault: false,
      userId: req.userId,
    });
    res.status(201).json(exercise);
  } catch (err) {
    console.error('POST /exercises error:', err);
    res.status(400).json({ error: 'Failed to create exercise.' });
  }
});

// DELETE /api/exercises/:id — delete custom exercise only
router.delete('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid exercise ID' });
    }
    // Ownership enforced: only user's own custom exercises
    const exercise = await Exercise.findOneAndDelete({
      _id: req.params.id,
      isCustom: true,
      userId: req.userId,
    });
    if (!exercise) return res.status(404).json({ error: 'Cannot delete this exercise' });
    res.json({ message: 'Exercise deleted' });
  } catch (err) {
    console.error('DELETE /exercises/:id error:', err);
    res.status(500).json({ error: 'Failed to delete exercise.' });
  }
});

// GET /api/exercises/:id/records — PRs for this exercise
router.get('/:id/records', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid exercise ID' });
    }
    // Ownership enforced: only user's own PRs
    const records = await PersonalRecord.find({
      user: req.userId,
      exerciseId: req.params.id,
    }).sort({ reps: 1 });
    res.json(records);
  } catch (err) {
    console.error('GET /exercises/:id/records error:', err);
    res.status(500).json({ error: 'Failed to load records.' });
  }
});

module.exports = router;
