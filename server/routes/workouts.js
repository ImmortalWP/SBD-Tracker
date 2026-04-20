const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Workout = require('../models/Workout');
const PersonalRecord = require('../models/PersonalRecord');
const auth = require('../middleware/authMiddleware');

router.use(auth);

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
    const { limit = 50, offset = 0, exerciseId } = req.query;

    if (exerciseId) {
      filter['exercises.exerciseId'] = exerciseId;
    }

    const workouts = await Workout.find(filter)
      .sort({ date: -1 })
      .skip(Number(offset))
      .limit(Number(limit));
    
    const total = await Workout.countDocuments(filter);
    res.json({ workouts, total });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/workouts/:id
router.get('/:id', async (req, res) => {
  try {
    const workout = await Workout.findOne({ _id: req.params.id, user: req.userId });
    if (!workout) return res.status(404).json({ error: 'Workout not found' });
    res.json(workout);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/workouts — create
router.post('/', async (req, res) => {
  try {
    const workout = await Workout.create({ ...req.body, user: req.userId });
    const newPRs = await checkAndUpdatePRs(req.userId, workout);
    res.status(201).json({ workout, newPRs });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// PUT /api/workouts/:id — update
router.put('/:id', async (req, res) => {
  try {
    const workout = await Workout.findOne({ _id: req.params.id, user: req.userId });
    if (!workout) return res.status(404).json({ error: 'Workout not found' });
    
    Object.assign(workout, req.body);
    await workout.save();
    const newPRs = await checkAndUpdatePRs(req.userId, workout);
    res.json({ workout, newPRs });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/workouts/:id
router.delete('/:id', async (req, res) => {
  try {
    const workout = await Workout.findOneAndDelete({ _id: req.params.id, user: req.userId });
    if (!workout) return res.status(404).json({ error: 'Workout not found' });
    res.json({ message: 'Workout deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/workouts/exercise/:exerciseId/history — exercise history
router.get('/exercise/:exerciseId/history', async (req, res) => {
  try {
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
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
