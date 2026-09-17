const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Workout = require('../models/Workout');
const PersonalRecord = require('../models/PersonalRecord');
const auth = require('../middleware/authMiddleware');
const { pickFields, isValidObjectId, validateWorkoutInput, validateNumber } = require('../middleware/validators');

router.use(auth);

// Allowed fields for workout create/update — prevents mass assignment
// Excludes: user, totalVolume, totalSets (server-calculated), _id, createdAt, updatedAt
const WORKOUT_ALLOWED_FIELDS = [
  'name', 'date', 'duration', 'startTime', 'endTime', 'notes',
  'exercises', 'isTemplate', 'programId', 'programWeek', 'programDay',
];

// Helper: Check and update PRs after saving a workout
async function checkAndUpdatePRs(userId, workout) {
  const newPRs = [];
  for (const exercise of workout.exercises) {
    for (const set of exercise.sets) {
      if (!set.completed || set.isWarmup || !set.weight || !set.reps) continue;
      
      const existing = await PersonalRecord.findOne({
        user: userId,
        exerciseId: exercise.exerciseId,
        reps: set.reps,
      });

      // Epley 1RM estimate
      const estimated1rm = set.reps === 1 ? set.weight : set.weight * (1 + set.reps / 30);

      if (!existing || set.weight > existing.weight) {
        await PersonalRecord.findOneAndUpdate(
          { user: userId, exerciseId: exercise.exerciseId, reps: set.reps },
          {
            user: userId,
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.name,
            reps: set.reps,
            weight: set.weight,
            estimated1rm: Math.round(estimated1rm * 10) / 10,
            date: workout.date || new Date(),
            workoutId: workout._id,
          },
          { upsert: true, new: true }
        );
        newPRs.push({ exercise: exercise.name, reps: set.reps, weight: set.weight });
      }
    }
  }
  return newPRs;
}

// GET /api/workouts — list all workouts
router.get('/', async (req, res) => {
  try {
    const filter = { user: req.userId, isTemplate: false };

    const limit = validateNumber(req.query.limit, { min: 1, max: 100, integer: true }) || 50;
    const offset = validateNumber(req.query.offset, { min: 0, max: 10000, integer: true }) || 0;

    if (req.query.exerciseId) {
      // Validate exerciseId format
      if (typeof req.query.exerciseId !== 'string' || req.query.exerciseId.length > 50) {
        return res.status(400).json({ error: 'Invalid exercise ID' });
      }
      filter['exercises.exerciseId'] = req.query.exerciseId;
    }

    const workouts = await Workout.find(filter)
      .sort({ date: -1 })
      .skip(offset)
      .limit(limit);
    
    const total = await Workout.countDocuments(filter);
    res.json({ workouts, total });
  } catch (err) {
    console.error('GET /workouts error:', err);
    res.status(500).json({ error: 'Failed to load workouts.' });
  }
});

// GET /api/workouts/:id
router.get('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid workout ID' });
    }
    // Ownership enforced in query
    const workout = await Workout.findOne({ _id: req.params.id, user: req.userId });
    if (!workout) return res.status(404).json({ error: 'Workout not found' });
    res.json(workout);
  } catch (err) {
    console.error('GET /workouts/:id error:', err);
    res.status(500).json({ error: 'Failed to load workout.' });
  }
});

// POST /api/workouts — create
router.post('/', async (req, res) => {
  try {
    // Whitelist allowed fields — prevent mass assignment of user, totalVolume, etc.
    const data = pickFields(req.body, WORKOUT_ALLOWED_FIELDS);

    const errors = validateWorkoutInput(data);
    if (errors.length > 0) {
      return res.status(400).json({ error: errors.join('; ') });
    }

    // Server sets ownership
    const workout = await Workout.create({ ...data, user: req.userId });
    const newPRs = await checkAndUpdatePRs(req.userId, workout);
    res.status(201).json({ workout, newPRs });
  } catch (err) {
    console.error('POST /workouts error:', err);
    res.status(400).json({ error: 'Failed to create workout.' });
  }
});

// PUT /api/workouts/:id — update
router.put('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid workout ID' });
    }

    // Ownership enforced in query
    const workout = await Workout.findOne({ _id: req.params.id, user: req.userId });
    if (!workout) return res.status(404).json({ error: 'Workout not found' });

    // Whitelist allowed fields — prevent mass assignment
    const data = pickFields(req.body, WORKOUT_ALLOWED_FIELDS);

    const errors = validateWorkoutInput(data);
    if (errors.length > 0) {
      return res.status(400).json({ error: errors.join('; ') });
    }

    Object.assign(workout, data);
    await workout.save();
    const newPRs = await checkAndUpdatePRs(req.userId, workout);
    res.json({ workout, newPRs });
  } catch (err) {
    console.error('PUT /workouts/:id error:', err);
    res.status(400).json({ error: 'Failed to update workout.' });
  }
});

// DELETE /api/workouts/:id
router.delete('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid workout ID' });
    }
    // Ownership enforced in query
    const workout = await Workout.findOneAndDelete({ _id: req.params.id, user: req.userId });
    if (!workout) return res.status(404).json({ error: 'Workout not found' });
    res.json({ message: 'Workout deleted' });
  } catch (err) {
    console.error('DELETE /workouts/:id error:', err);
    res.status(500).json({ error: 'Failed to delete workout.' });
  }
});

// GET /api/workouts/exercise/:exerciseId/history — exercise history
router.get('/exercise/:exerciseId/history', async (req, res) => {
  try {
    // Validate exerciseId
    if (typeof req.params.exerciseId !== 'string' || req.params.exerciseId.length > 50) {
      return res.status(400).json({ error: 'Invalid exercise ID' });
    }

    const workouts = await Workout.find({
      user: req.userId,
      'exercises.exerciseId': req.params.exerciseId,
      isTemplate: false,
    })
      .sort({ date: -1 })
      .limit(20)
      .select('date exercises name');

    const history = workouts.map(w => {
      const ex = w.exercises.find(e => e.exerciseId === req.params.exerciseId);
      return {
        workoutId: w._id,
        workoutName: w.name,
        date: w.date,
        sets: ex ? ex.sets : [],
      };
    });

    res.json(history);
  } catch (err) {
    console.error('GET /workouts/exercise/:id/history error:', err);
    res.status(500).json({ error: 'Failed to load exercise history.' });
  }
});

module.exports = router;
