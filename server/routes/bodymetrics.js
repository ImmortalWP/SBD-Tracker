const express = require('express');
const router = express.Router();
const BodyMetric = require('../models/BodyMetric');
const auth = require('../middleware/authMiddleware');
const { pickFields, isValidObjectId, validateBodyMetricInput, validateNumber } = require('../middleware/validators');

router.use(auth);

// Allowed fields for body metric create/update — prevents mass assignment
const BODYMETRIC_ALLOWED_FIELDS = [
  'date', 'weight', 'bodyFat', 'measurements', 'notes',
];

// GET /api/bodymetrics — list all metrics
router.get('/', async (req, res) => {
  try {
    const limit = validateNumber(req.query.limit, { min: 1, max: 200, integer: true }) || 30;
    // Ownership enforced in query
    const metrics = await BodyMetric.find({ user: req.userId })
      .sort({ date: -1 })
      .limit(limit);
    res.json(metrics);
  } catch (err) {
    console.error('GET /bodymetrics error:', err);
    res.status(500).json({ error: 'Failed to load body metrics.' });
  }
});

// POST /api/bodymetrics — create new entry
router.post('/', async (req, res) => {
  try {
    // Whitelist allowed fields — prevent mass assignment
    const data = pickFields(req.body, BODYMETRIC_ALLOWED_FIELDS);

    const errors = validateBodyMetricInput(data);
    if (errors.length > 0) {
      return res.status(400).json({ error: errors.join('; ') });
    }

    // Server sets ownership
    const metric = await BodyMetric.create({ ...data, user: req.userId });
    res.status(201).json(metric);
  } catch (err) {
    console.error('POST /bodymetrics error:', err);
    res.status(400).json({ error: 'Failed to create body metric.' });
  }
});

// PUT /api/bodymetrics/:id — update
router.put('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid metric ID' });
    }

    // Whitelist allowed fields — prevent mass assignment
    const data = pickFields(req.body, BODYMETRIC_ALLOWED_FIELDS);

    const errors = validateBodyMetricInput(data);
    if (errors.length > 0) {
      return res.status(400).json({ error: errors.join('; ') });
    }

    // Ownership enforced in query
    const metric = await BodyMetric.findOneAndUpdate(
      { _id: req.params.id, user: req.userId },
      data,
      { new: true, runValidators: true }
    );
    if (!metric) return res.status(404).json({ error: 'Metric not found' });
    res.json(metric);
  } catch (err) {
    console.error('PUT /bodymetrics/:id error:', err);
    res.status(400).json({ error: 'Failed to update body metric.' });
  }
});

// DELETE /api/bodymetrics/:id
router.delete('/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid metric ID' });
    }
    // Ownership enforced in query
    const metric = await BodyMetric.findOneAndDelete({ _id: req.params.id, user: req.userId });
    if (!metric) return res.status(404).json({ error: 'Metric not found' });
    res.json({ message: 'Metric deleted' });
  } catch (err) {
    console.error('DELETE /bodymetrics/:id error:', err);
    res.status(500).json({ error: 'Failed to delete body metric.' });
  }
});

// GET /api/bodymetrics/latest — get latest metrics
router.get('/latest', async (req, res) => {
  try {
    // Ownership enforced in query
    const latest = await BodyMetric.findOne({ user: req.userId }).sort({ date: -1 });
    res.json(latest);
  } catch (err) {
    console.error('GET /bodymetrics/latest error:', err);
    res.status(500).json({ error: 'Failed to load latest metric.' });
  }
});

module.exports = router;
