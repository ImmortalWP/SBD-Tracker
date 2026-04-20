const mongoose = require('mongoose');

const SetSchema = new mongoose.Schema({
  setNumber: { type: Number, default: 1 },
  weight: { type: Number, default: 0 },
  reps: { type: Number, default: 0 },
  rpe: { type: Number, min: 1, max: 10 },
  rir: { type: Number, min: 0 },
  percentage1rm: { type: Number },
  isWarmup: { type: Boolean, default: false },
  isDropset: { type: Boolean, default: false },
  completed: { type: Boolean, default: false },
  distance: { type: Number }, // meters, for cardio
  time: { type: Number },    // seconds, for cardio
});

const WorkoutExerciseSchema = new mongoose.Schema({
  exerciseId: { type: String, required: true },
  name: { type: String, required: true },
  notes: { type: String, default: '' },
  restTimer: { type: Number }, // custom rest time in seconds
  supersetGroup: { type: Number }, // group number for supersets
  sets: [SetSchema],
});

const WorkoutSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    name: { type: String, default: 'Workout' },
    date: { type: Date, default: Date.now },
    duration: { type: Number, default: 0 }, // seconds
    startTime: { type: Date },
    endTime: { type: Date },
    notes: { type: String, default: '' },
    exercises: [WorkoutExerciseSchema],
    isTemplate: { type: Boolean, default: false },
    programId: { type: mongoose.Schema.Types.ObjectId, ref: 'Program' },
    programWeek: { type: Number },
    programDay: { type: Number },
    totalVolume: { type: Number, default: 0 }, // auto-calculated
    totalSets: { type: Number, default: 0 },   // auto-calculated
  },
  { timestamps: true }
);

// Auto-calculate totals before saving
WorkoutSchema.pre('save', function (next) {
  let totalVolume = 0;
  let totalSets = 0;
  this.exercises.forEach(ex => {
    ex.sets.forEach(set => {
      if (set.completed && !set.isWarmup) {
        totalVolume += (set.weight || 0) * (set.reps || 0);
        totalSets++;
      }
    });
  });
  this.totalVolume = totalVolume;
  this.totalSets = totalSets;
  next();
});

WorkoutSchema.index({ user: 1, date: -1 });
WorkoutSchema.index({ user: 1, 'exercises.exerciseId': 1 });

module.exports = mongoose.model('Workout', WorkoutSchema);
