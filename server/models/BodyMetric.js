const mongoose = require('mongoose');

const BodyMetricSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    date: { type: Date, default: Date.now },
    weight: { type: Number },       // kg or lbs
    bodyFat: { type: Number },      // percentage
    // Measurements in cm or inches
    measurements: {
      chest: { type: Number },
      waist: { type: Number },
      hips: { type: Number },
      leftArm: { type: Number },
      rightArm: { type: Number },
      leftThigh: { type: Number },
      rightThigh: { type: Number },
      leftCalf: { type: Number },
      rightCalf: { type: Number },
      neck: { type: Number },
      shoulders: { type: Number },
    },
    notes: { type: String, default: '' },
  },
  { timestamps: true }
);

BodyMetricSchema.index({ user: 1, date: -1 });

module.exports = mongoose.model('BodyMetric', BodyMetricSchema);
