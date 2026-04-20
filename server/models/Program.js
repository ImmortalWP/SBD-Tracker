const mongoose = require('mongoose');

const ProgramExerciseSchema = new mongoose.Schema({
  exerciseId: { type: String },
  name: { type: String, required: true },
  sets: { type: Number, default: 3 },
  reps: { type: String, default: '8-12' }, // can be "5", "8-12", "AMRAP"
  rpe: { type: Number },
  percentage1rm: { type: Number },
  restSeconds: { type: Number, default: 90 },
  notes: { type: String },
});

const ProgramDaySchema = new mongoose.Schema({
  dayNumber: { type: Number, required: true },
  name: { type: String, required: true }, // "Push Day", "Squat Day"
  exercises: [ProgramExerciseSchema],
});

const ProgramWeekSchema = new mongoose.Schema({
  weekNumber: { type: Number, required: true },
  name: { type: String },
  days: [ProgramDaySchema],
});

const ProgramSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    description: { type: String, default: '' },
    category: {
      type: String,
      enum: ['Strength', 'Hypertrophy', 'Powerlifting', 'Bodybuilding', 'General', 'Powerbuilding', 'Beginner', 'Athletic'],
      default: 'General',
    },
    difficulty: {
      type: String,
      enum: ['Beginner', 'Intermediate', 'Advanced'],
      default: 'Intermediate',
    },
    weeks: { type: Number, default: 4 },
    daysPerWeek: { type: Number, default: 3 },
    schedule: [ProgramWeekSchema],
    isDefault: { type: Boolean, default: false },
    isCustom: { type: Boolean, default: false },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    // User progress tracking
    activeUsers: [{
      userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      currentWeek: { type: Number, default: 1 },
      currentDay: { type: Number, default: 1 },
      startedAt: { type: Date, default: Date.now },
    }],
  },
  { timestamps: true }
);

module.exports = mongoose.model('Program', ProgramSchema);
