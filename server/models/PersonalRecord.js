const mongoose = require('mongoose');

const PersonalRecordSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    exerciseId: { type: String, required: true },
    exerciseName: { type: String, required: true },
    reps: { type: Number, required: true },    // 1 for 1RM, 2 for 2RM, etc.
    weight: { type: Number, required: true },
    estimated1rm: { type: Number },            // Epley formula estimate
    date: { type: Date, default: Date.now },
    workoutId: { type: mongoose.Schema.Types.ObjectId, ref: 'Workout' },
  },
  { timestamps: true }
);

// Unique PR per user, exercise, and rep count
PersonalRecordSchema.index({ user: 1, exerciseId: 1, reps: 1 }, { unique: true });

module.exports = mongoose.model('PersonalRecord', PersonalRecordSchema);
