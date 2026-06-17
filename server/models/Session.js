const mongoose = require('mongoose');

const SetSchema = new mongoose.Schema({
  weight: { type: Number, required: true },
  sets: { type: Number, required: true },
  reps: { type: Number, required: true },
});

const ExerciseSchema = new mongoose.Schema({
  name: { type: String, required: true },
  category: { type: String, enum: ['main', 'secondary', 'accessory'], default: 'main' },
  percentage: { type: Number },
  note: { type: String, default: '' },
  sets: [SetSchema],
});

const SessionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    clientId: { type: String, default: null },
    block: { type: Number, required: true },
    week: { type: Number },
    percentage: { type: Number },
    day: { type: String, required: true },
    date: { type: Date, default: Date.now },
    duration: { type: Number },
    durationInMinutes: { type: Number },
    startTime: { type: String },
    endTime: { type: String },
    exercises: [ExerciseSchema],
    notes: { type: String, default: '' },
    note: { type: String, default: '' },
    intensity: { type: Number },
    sessionRating: { type: Number, min: 1, max: 10 },
  },
  { timestamps: true }
);

// Indexes for efficient queries
SessionSchema.index({ user: 1, block: 1, day: 1 });
SessionSchema.index({ user: 1, date: -1 });              // Date-sorted queries
SessionSchema.index({ user: 1, 'exercises.name': 1 });    // Exercise history lookup
SessionSchema.index({ user: 1, clientId: 1 }, { unique: true, sparse: true }); // Idempotency — prevent duplicate submissions

module.exports = mongoose.model('Session', SessionSchema);
