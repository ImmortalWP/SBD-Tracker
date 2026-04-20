const mongoose = require('mongoose');

const ExerciseSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    category: {
      type: String,
      enum: ['Barbell', 'Dumbbell', 'Machine', 'Cable', 'Bodyweight', 'Band', 'Cardio', 'Stretching', 'Other'],
      default: 'Other',
    },
    primaryMuscles: [{
      type: String,
      enum: ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Forearms', 'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Abs', 'Obliques', 'Traps', 'Lats', 'Neck', 'Full Body'],
    }],
    secondaryMuscles: [{
      type: String,
      enum: ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Forearms', 'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Abs', 'Obliques', 'Traps', 'Lats', 'Neck', 'Full Body'],
    }],
    instructions: { type: String, default: '' },
    equipment: { type: String, default: '' },
    isCustom: { type: Boolean, default: false },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // only for custom exercises
    isDefault: { type: Boolean, default: true },
  },
  { timestamps: true }
);

ExerciseSchema.index({ name: 'text' });
ExerciseSchema.index({ primaryMuscles: 1 });
ExerciseSchema.index({ category: 1 });

module.exports = mongoose.model('Exercise', ExerciseSchema);
