const express = require('express');
const router = express.Router();
const BodyMetric = require('../models/BodyMetric');
const auth = require('../middleware/authMiddleware');

router.use(auth);

// GET /api/bodymetrics — list all metrics
router.get('/', async (req, res) => {
  try {
    const { limit = 30 } = req.query;
    const metrics = await BodyMetric.find({ user: req.userId })
      .sort({ date: -1 })
      .limit(Number(limit));
    res.json(metrics);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/bodymetrics — create new entry
router.post('/', async (req, res) => {
  try {
    const metric = await BodyMetric.create({ ...req.body, user: req.userId });
    res.status(201).json(metric);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// PUT /api/bodymetrics/:id — update
router.put('/:id', async (req, res) => {
  try {
    const metric = await BodyMetric.findOneAndUpdate(
      { _id: req.params.id, user: req.userId },
      req.body,
      { new: true, runValidators: true }
    );
    if (!metric) return res.status(404).json({ error: 'Metric not found' });
    res.json(metric);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/bodymetrics/:id
router.delete('/:id', async (req, res) => {
  try {
    const metric = await BodyMetric.findOneAndDelete({ _id: req.params.id, user: req.userId });
    if (!metric) return res.status(404).json({ error: 'Metric not found' });
    res.json({ message: 'Metric deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/bodymetrics/latest — get latest metrics
router.get('/latest', async (req, res) => {
  try {
    const latest = await BodyMetric.findOne({ user: req.userId }).sort({ date: -1 });
    res.json(latest);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
