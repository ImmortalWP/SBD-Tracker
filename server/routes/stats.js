const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Workout = require('../models/Workout');
const PersonalRecord = require('../models/PersonalRecord');
const auth = require('../middleware/authMiddleware');

router.use(auth);

// GET /api/stats/overview — dashboard overview
router.get('/overview', async (req, res) => {
  try {
    const userId = new mongoose.Types.ObjectId(req.userId);
    
    const totalWorkouts = await Workout.countDocuments({ user: req.userId, isTemplate: false });
    
    // This week's workouts
    const startOfWeek = new Date();
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
    startOfWeek.setHours(0, 0, 0, 0);
    
    const thisWeekWorkouts = await Workout.countDocuments({
      user: req.userId,
      isTemplate: false,
      date: { $gte: startOfWeek },
    });

    // Workout streak (consecutive days with workouts)
    const recentWorkouts = await Workout.find({ user: req.userId, isTemplate: false })
      .sort({ date: -1 })
      .select('date')
      .limit(365);

    let streak = 0;
    if (recentWorkouts.length > 0) {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      let checkDate = new Date(today);
      
      // Check if there was a workout today or yesterday
      const todayStr = today.toDateString();
      const hasToday = recentWorkouts.some(w => new Date(w.date).toDateString() === todayStr);
      
      if (!hasToday) {
        checkDate.setDate(checkDate.getDate() - 1);
        const yestStr = checkDate.toDateString();
        const hasYesterday = recentWorkouts.some(w => new Date(w.date).toDateString() === yestStr);
        if (!hasYesterday) {
          streak = 0;
        } else {
          streak = 1;
          checkDate.setDate(checkDate.getDate() - 1);
          while (true) {
            const dateStr = checkDate.toDateString();
            if (recentWorkouts.some(w => new Date(w.date).toDateString() === dateStr)) {
              streak++;
              checkDate.setDate(checkDate.getDate() - 1);
            } else {
              break;
            }
          }
        }
      } else {
        streak = 1;
        checkDate.setDate(checkDate.getDate() - 1);
        while (true) {
          const dateStr = checkDate.toDateString();
          if (recentWorkouts.some(w => new Date(w.date).toDateString() === dateStr)) {
            streak++;
            checkDate.setDate(checkDate.getDate() - 1);
          } else {
            break;
          }
        }
      }
    }

    // Total volume this week
    const weekWorkouts = await Workout.find({
      user: req.userId,
      isTemplate: false,
      date: { $gte: startOfWeek },
    }).select('totalVolume');
    const weekVolume = weekWorkouts.reduce((sum, w) => sum + (w.totalVolume || 0), 0);

    // Total volume all time
    const allVolume = await Workout.aggregate([
      { $match: { user: userId, isTemplate: false } },
      { $group: { _id: null, total: { $sum: '$totalVolume' } } },
    ]);
    const totalVolume = allVolume.length > 0 ? allVolume[0].total : 0;

    // Total duration
    const allDuration = await Workout.aggregate([
      { $match: { user: userId, isTemplate: false } },
      { $group: { _id: null, total: { $sum: '$duration' } } },
    ]);
    const totalDuration = allDuration.length > 0 ? allDuration[0].total : 0;

    res.json({
      totalWorkouts,
      thisWeekWorkouts,
      streak,
      weekVolume,
      totalVolume,
      totalDuration,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/stats/muscle-map — muscle group training volume
router.get('/muscle-map', async (req, res) => {
  try {
    const { days = 7 } = req.query;
    const since = new Date();
    since.setDate(since.getDate() - Number(days));

    const workouts = await Workout.find({
      user: req.userId,
      isTemplate: false,
      date: { $gte: since },
    }).select('exercises');

    // Count sets per muscle group
    const muscleMap = {};
    const muscleGroups = ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Forearms',
      'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Abs', 'Obliques', 'Traps', 'Lats', 'Neck'];
    
    muscleGroups.forEach(m => { muscleMap[m] = 0; });

    // We need the Exercise model for muscle data — import here
    const Exercise = require('../models/Exercise');
    const exercises = await Exercise.find({}).select('_id primaryMuscles secondaryMuscles');
    const exerciseMap = {};
    exercises.forEach(e => { exerciseMap[e._id.toString()] = e; });

    workouts.forEach(w => {
      w.exercises.forEach(ex => {
        const exerciseData = exerciseMap[ex.exerciseId];
        const completedSets = ex.sets.filter(s => s.completed && !s.isWarmup).length;
        if (exerciseData && completedSets > 0) {
          (exerciseData.primaryMuscles || []).forEach(m => {
            if (muscleMap[m] !== undefined) muscleMap[m] += completedSets;
          });
          (exerciseData.secondaryMuscles || []).forEach(m => {
            if (muscleMap[m] !== undefined) muscleMap[m] += completedSets * 0.5;
          });
        }
      });
    });

    res.json(muscleMap);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/stats/prs — all personal records
router.get('/prs', async (req, res) => {
  try {
    const records = await PersonalRecord.find({ user: req.userId }).sort({ exerciseName: 1, reps: 1 });
    
    // Group by exercise
    const grouped = {};
    records.forEach(r => {
      if (!grouped[r.exerciseName]) {
        grouped[r.exerciseName] = { exerciseId: r.exerciseId, records: [] };
      }
      grouped[r.exerciseName].records.push({
        reps: r.reps,
        weight: r.weight,
        estimated1rm: r.estimated1rm,
        date: r.date,
      });
    });

    res.json(grouped);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/stats/volume — volume over time
router.get('/volume', async (req, res) => {
  try {
    const userId = new mongoose.Types.ObjectId(req.userId);
    const { period = 'weekly' } = req.query;

    let groupFormat;
    if (period === 'daily') {
      groupFormat = { $dateToString: { format: '%Y-%m-%d', date: '$date' } };
    } else if (period === 'monthly') {
      groupFormat = { $dateToString: { format: '%Y-%m', date: '$date' } };
    } else {
      // weekly
      groupFormat = {
        $dateToString: {
          format: '%Y-W%V',
          date: '$date',
        },
      };
    }

    const data = await Workout.aggregate([
      { $match: { user: userId, isTemplate: false } },
      {
        $group: {
          _id: groupFormat,
          totalVolume: { $sum: '$totalVolume' },
          workoutCount: { $sum: 1 },
          totalSets: { $sum: '$totalSets' },
        },
      },
      { $sort: { _id: 1 } },
      { $limit: 52 },
    ]);

    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
