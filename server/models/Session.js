const mongoose = require('mongoose');

const SetSchema = new mongoose.Schema({
  weight: { type: Number, required: true },
  sets: { type: Number, required: true },
  reps: { type: Number, required: true },
});

const ExerciseSchema = new mongoose.Schema({
  name: { type: String, required: true },
  category: { type: String, enum: ['main', 'secondary', 'accessory'], default: 'main' },
  sets: [SetSchema],
});

const SessionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    block: { type: Number, required: true },
    day: { type: String, required: true },
    date: { type: Date, default: Date.now },
    startTime: { type: String },
    endTime: { type: String },
    exercises: [ExerciseSchema],
    notes: { type: String, default: '' },
  },
  { timestamps: true }
);

// Index for efficient queries
SessionSchema.index({ user: 1, block: 1, day: 1 });

module.exports = mongoose.model('Session', SessionSchema);
