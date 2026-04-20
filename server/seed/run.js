const Exercise = require('../models/Exercise');
const Program = require('../models/Program');
const exerciseData = require('./exercises');
const programData = require('./programs');

async function seedIfEmpty() {
  try {
    // Seed exercises if empty
    const exerciseCount = await Exercise.countDocuments({ isDefault: true });
    if (exerciseCount === 0) {
      console.log('🌱 Seeding exercise library...');
      await Exercise.insertMany(exerciseData);
      console.log(`✅ Seeded ${exerciseData.length} exercises`);
    } else {
      console.log(`📚 Exercise library: ${exerciseCount} exercises`);
    }

    // Seed programs if empty
    const programCount = await Program.countDocuments({ isDefault: true });
    if (programCount === 0) {
      console.log('🌱 Seeding training programs...');
      await Program.insertMany(programData);
      console.log(`✅ Seeded ${programData.length} programs`);
    } else {
      console.log(`📋 Training programs: ${programCount} programs`);
    }
  } catch (err) {
    console.error('❌ Seed error:', err.message);
  }
}

module.exports = { seedIfEmpty };
