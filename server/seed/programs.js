const programs = [
  {
    name: 'Starting Strength',
    description: 'Classic beginner linear progression program by Mark Rippetoe. 3 days per week, alternating A/B workouts focusing on compound lifts.',
    category: 'Beginner',
    difficulty: 'Beginner',
    weeks: 12,
    daysPerWeek: 3,
    isDefault: true,
    schedule: [
      {
        weekNumber: 1,
        name: 'Week 1',
        days: [
          {
            dayNumber: 1, name: 'Workout A',
            exercises: [
              { name: 'Barbell Squat', sets: 3, reps: '5', restSeconds: 180 },
              { name: 'Barbell Bench Press', sets: 3, reps: '5', restSeconds: 180 },
              { name: 'Deadlift', sets: 1, reps: '5', restSeconds: 300 },
            ]
          },
          {
            dayNumber: 2, name: 'Workout B',
            exercises: [
              { name: 'Barbell Squat', sets: 3, reps: '5', restSeconds: 180 },
              { name: 'Overhead Press', sets: 3, reps: '5', restSeconds: 180 },
              { name: 'Deadlift', sets: 1, reps: '5', restSeconds: 300 },
            ]
          },
          {
            dayNumber: 3, name: 'Workout A',
            exercises: [
              { name: 'Barbell Squat', sets: 3, reps: '5', restSeconds: 180 },
              { name: 'Barbell Bench Press', sets: 3, reps: '5', restSeconds: 180 },
              { name: 'Deadlift', sets: 1, reps: '5', restSeconds: 300 },
            ]
          },
        ]
      }
    ]
  },
  {
    name: 'Push Pull Legs (PPL)',
    description: '6-day PPL split. Two push, two pull, two leg days per week. Great for intermediate lifters looking for hypertrophy and strength.',
    category: 'Hypertrophy',
    difficulty: 'Intermediate',
    weeks: 8,
    daysPerWeek: 6,
    isDefault: true,
    schedule: [
      {
        weekNumber: 1,
        name: 'Week 1',
        days: [
          {
            dayNumber: 1, name: 'Push A',
            exercises: [
              { name: 'Barbell Bench Press', sets: 4, reps: '5', restSeconds: 180 },
              { name: 'Overhead Press', sets: 3, reps: '8-12', restSeconds: 120 },
              { name: 'Incline Dumbbell Bench Press', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Cable Crossover', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Lateral Raise', sets: 4, reps: '12-15', restSeconds: 60 },
              { name: 'Tricep Pushdown', sets: 3, reps: '10-12', restSeconds: 60 },
              { name: 'Overhead Tricep Extension', sets: 3, reps: '10-12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 2, name: 'Pull A',
            exercises: [
              { name: 'Deadlift', sets: 3, reps: '5', restSeconds: 240 },
              { name: 'Pull-Up', sets: 3, reps: '6-10', restSeconds: 120 },
              { name: 'Barbell Row', sets: 3, reps: '8-12', restSeconds: 120 },
              { name: 'Face Pull', sets: 4, reps: '15-20', restSeconds: 60 },
              { name: 'Barbell Curl', sets: 3, reps: '8-12', restSeconds: 60 },
              { name: 'Hammer Curl', sets: 3, reps: '8-12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 3, name: 'Legs A',
            exercises: [
              { name: 'Barbell Squat', sets: 4, reps: '5', restSeconds: 180 },
              { name: 'Romanian Deadlift', sets: 3, reps: '8-12', restSeconds: 120 },
              { name: 'Leg Press', sets: 3, reps: '10-12', restSeconds: 120 },
              { name: 'Leg Extension', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Lying Leg Curl', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Standing Calf Raise', sets: 4, reps: '12-15', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 4, name: 'Push B',
            exercises: [
              { name: 'Overhead Press', sets: 4, reps: '5', restSeconds: 180 },
              { name: 'Dumbbell Bench Press', sets: 3, reps: '8-12', restSeconds: 120 },
              { name: 'Incline Dumbbell Bench Press', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Dumbbell Fly', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Lateral Raise', sets: 4, reps: '12-15', restSeconds: 60 },
              { name: 'Skull Crusher', sets: 3, reps: '10-12', restSeconds: 60 },
              { name: 'Rope Pushdown', sets: 3, reps: '10-12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 5, name: 'Pull B',
            exercises: [
              { name: 'Barbell Row', sets: 4, reps: '5', restSeconds: 180 },
              { name: 'Lat Pulldown', sets: 3, reps: '8-12', restSeconds: 120 },
              { name: 'Seated Cable Row', sets: 3, reps: '8-12', restSeconds: 120 },
              { name: 'Face Pull', sets: 4, reps: '15-20', restSeconds: 60 },
              { name: 'EZ Bar Curl', sets: 3, reps: '8-12', restSeconds: 60 },
              { name: 'Incline Dumbbell Curl', sets: 3, reps: '8-12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 6, name: 'Legs B',
            exercises: [
              { name: 'Front Squat', sets: 3, reps: '6-8', restSeconds: 180 },
              { name: 'Hip Thrust', sets: 3, reps: '8-12', restSeconds: 120 },
              { name: 'Bulgarian Split Squat', sets: 3, reps: '10-12', restSeconds: 90 },
              { name: 'Leg Extension', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Seated Leg Curl', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Seated Calf Raise', sets: 4, reps: '15-20', restSeconds: 60 },
            ]
          },
        ]
      }
    ]
  },
  {
    name: 'Wendler 5/3/1',
    description: 'Jim Wendler\'s proven 4-day strength program. Focus on slow, steady progression with submaximal training. Each day focuses on one main lift.',
    category: 'Powerlifting',
    difficulty: 'Intermediate',
    weeks: 4,
    daysPerWeek: 4,
    isDefault: true,
    schedule: [
      {
        weekNumber: 1, name: 'Week 1 — 5s',
        days: [
          {
            dayNumber: 1, name: 'Squat Day',
            exercises: [
              { name: 'Barbell Squat', sets: 3, reps: '5', percentage1rm: 75, restSeconds: 180, notes: '65% x5, 75% x5, 85% x5+' },
              { name: 'Leg Press', sets: 5, reps: '10', restSeconds: 90 },
              { name: 'Leg Extension', sets: 3, reps: '12', restSeconds: 60 },
              { name: 'Hanging Leg Raise', sets: 4, reps: '15', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 2, name: 'Bench Day',
            exercises: [
              { name: 'Barbell Bench Press', sets: 3, reps: '5', percentage1rm: 75, restSeconds: 180, notes: '65% x5, 75% x5, 85% x5+' },
              { name: 'Dumbbell Row', sets: 5, reps: '10', restSeconds: 90 },
              { name: 'Dumbbell Fly', sets: 3, reps: '12', restSeconds: 60 },
              { name: 'Tricep Pushdown', sets: 3, reps: '12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 3, name: 'Deadlift Day',
            exercises: [
              { name: 'Deadlift', sets: 3, reps: '5', percentage1rm: 75, restSeconds: 240, notes: '65% x5, 75% x5, 85% x5+' },
              { name: 'Good Morning', sets: 3, reps: '10', restSeconds: 90 },
              { name: 'Hanging Leg Raise', sets: 4, reps: '15', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 4, name: 'OHP Day',
            exercises: [
              { name: 'Overhead Press', sets: 3, reps: '5', percentage1rm: 75, restSeconds: 180, notes: '65% x5, 75% x5, 85% x5+' },
              { name: 'Chin-Up', sets: 5, reps: '8', restSeconds: 90 },
              { name: 'Lateral Raise', sets: 4, reps: '12', restSeconds: 60 },
              { name: 'Face Pull', sets: 3, reps: '15', restSeconds: 60 },
            ]
          },
        ]
      },
      {
        weekNumber: 2, name: 'Week 2 — 3s',
        days: [
          { dayNumber: 1, name: 'Squat Day', exercises: [{ name: 'Barbell Squat', sets: 3, reps: '3', percentage1rm: 80, restSeconds: 180, notes: '70% x3, 80% x3, 90% x3+' }] },
          { dayNumber: 2, name: 'Bench Day', exercises: [{ name: 'Barbell Bench Press', sets: 3, reps: '3', percentage1rm: 80, restSeconds: 180, notes: '70% x3, 80% x3, 90% x3+' }] },
          { dayNumber: 3, name: 'Deadlift Day', exercises: [{ name: 'Deadlift', sets: 3, reps: '3', percentage1rm: 80, restSeconds: 240, notes: '70% x3, 80% x3, 90% x3+' }] },
          { dayNumber: 4, name: 'OHP Day', exercises: [{ name: 'Overhead Press', sets: 3, reps: '3', percentage1rm: 80, restSeconds: 180, notes: '70% x3, 80% x3, 90% x3+' }] },
        ]
      },
      {
        weekNumber: 3, name: 'Week 3 — 5/3/1',
        days: [
          { dayNumber: 1, name: 'Squat Day', exercises: [{ name: 'Barbell Squat', sets: 3, reps: '5,3,1', percentage1rm: 85, restSeconds: 240, notes: '75% x5, 85% x3, 95% x1+' }] },
          { dayNumber: 2, name: 'Bench Day', exercises: [{ name: 'Barbell Bench Press', sets: 3, reps: '5,3,1', percentage1rm: 85, restSeconds: 240, notes: '75% x5, 85% x3, 95% x1+' }] },
          { dayNumber: 3, name: 'Deadlift Day', exercises: [{ name: 'Deadlift', sets: 3, reps: '5,3,1', percentage1rm: 85, restSeconds: 300, notes: '75% x5, 85% x3, 95% x1+' }] },
          { dayNumber: 4, name: 'OHP Day', exercises: [{ name: 'Overhead Press', sets: 3, reps: '5,3,1', percentage1rm: 85, restSeconds: 240, notes: '75% x5, 85% x3, 95% x1+' }] },
        ]
      },
      {
        weekNumber: 4, name: 'Week 4 — Deload',
        days: [
          { dayNumber: 1, name: 'Squat Day', exercises: [{ name: 'Barbell Squat', sets: 3, reps: '5', percentage1rm: 60, restSeconds: 120, notes: '40% x5, 50% x5, 60% x5' }] },
          { dayNumber: 2, name: 'Bench Day', exercises: [{ name: 'Barbell Bench Press', sets: 3, reps: '5', percentage1rm: 60, restSeconds: 120, notes: '40% x5, 50% x5, 60% x5' }] },
          { dayNumber: 3, name: 'Deadlift Day', exercises: [{ name: 'Deadlift', sets: 3, reps: '5', percentage1rm: 60, restSeconds: 120, notes: '40% x5, 50% x5, 60% x5' }] },
          { dayNumber: 4, name: 'OHP Day', exercises: [{ name: 'Overhead Press', sets: 3, reps: '5', percentage1rm: 60, restSeconds: 120, notes: '40% x5, 50% x5, 60% x5' }] },
        ]
      }
    ]
  },
  {
    name: 'Upper Lower Split',
    description: '4-day upper/lower split. Great balance of strength and hypertrophy. Hit each muscle group twice per week.',
    category: 'General',
    difficulty: 'Intermediate',
    weeks: 8,
    daysPerWeek: 4,
    isDefault: true,
    schedule: [
      {
        weekNumber: 1,
        name: 'Week 1',
        days: [
          {
            dayNumber: 1, name: 'Upper A (Strength)',
            exercises: [
              { name: 'Barbell Bench Press', sets: 4, reps: '4-6', restSeconds: 180 },
              { name: 'Barbell Row', sets: 4, reps: '4-6', restSeconds: 180 },
              { name: 'Overhead Press', sets: 3, reps: '6-8', restSeconds: 120 },
              { name: 'Lat Pulldown', sets: 3, reps: '8-10', restSeconds: 90 },
              { name: 'Barbell Curl', sets: 2, reps: '8-12', restSeconds: 60 },
              { name: 'Skull Crusher', sets: 2, reps: '8-12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 2, name: 'Lower A (Strength)',
            exercises: [
              { name: 'Barbell Squat', sets: 4, reps: '4-6', restSeconds: 180 },
              { name: 'Romanian Deadlift', sets: 3, reps: '6-8', restSeconds: 120 },
              { name: 'Leg Press', sets: 3, reps: '8-10', restSeconds: 120 },
              { name: 'Lying Leg Curl', sets: 3, reps: '10-12', restSeconds: 60 },
              { name: 'Standing Calf Raise', sets: 4, reps: '10-15', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 3, name: 'Upper B (Hypertrophy)',
            exercises: [
              { name: 'Incline Dumbbell Bench Press', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Seated Cable Row', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Dumbbell Fly', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Face Pull', sets: 3, reps: '15-20', restSeconds: 60 },
              { name: 'Lateral Raise', sets: 4, reps: '12-15', restSeconds: 60 },
              { name: 'Dumbbell Curl', sets: 3, reps: '10-12', restSeconds: 60 },
              { name: 'Rope Pushdown', sets: 3, reps: '10-12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 4, name: 'Lower B (Hypertrophy)',
            exercises: [
              { name: 'Deadlift', sets: 3, reps: '5', restSeconds: 240 },
              { name: 'Bulgarian Split Squat', sets: 3, reps: '10-12', restSeconds: 90 },
              { name: 'Leg Extension', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Seated Leg Curl', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Hip Thrust', sets: 3, reps: '10-12', restSeconds: 90 },
              { name: 'Seated Calf Raise', sets: 4, reps: '15-20', restSeconds: 60 },
            ]
          },
        ]
      }
    ]
  },
  {
    name: 'Full Body 3x',
    description: 'Simple 3-day full body routine. Perfect for beginners or those with limited time. Hit every muscle group each session.',
    category: 'Beginner',
    difficulty: 'Beginner',
    weeks: 8,
    daysPerWeek: 3,
    isDefault: true,
    schedule: [
      {
        weekNumber: 1,
        name: 'Week 1',
        days: [
          {
            dayNumber: 1, name: 'Full Body A',
            exercises: [
              { name: 'Barbell Squat', sets: 3, reps: '8-10', restSeconds: 120 },
              { name: 'Barbell Bench Press', sets: 3, reps: '8-10', restSeconds: 120 },
              { name: 'Barbell Row', sets: 3, reps: '8-10', restSeconds: 120 },
              { name: 'Overhead Press', sets: 2, reps: '8-12', restSeconds: 90 },
              { name: 'Dumbbell Curl', sets: 2, reps: '10-12', restSeconds: 60 },
              { name: 'Plank', sets: 3, reps: '30-60s', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 2, name: 'Full Body B',
            exercises: [
              { name: 'Deadlift', sets: 3, reps: '5', restSeconds: 180 },
              { name: 'Incline Dumbbell Bench Press', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Lat Pulldown', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Leg Press', sets: 3, reps: '10-12', restSeconds: 120 },
              { name: 'Lateral Raise', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Tricep Pushdown', sets: 2, reps: '10-12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 3, name: 'Full Body C',
            exercises: [
              { name: 'Front Squat', sets: 3, reps: '8-10', restSeconds: 120 },
              { name: 'Dumbbell Bench Press', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Seated Cable Row', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Romanian Deadlift', sets: 3, reps: '10-12', restSeconds: 120 },
              { name: 'Face Pull', sets: 3, reps: '15-20', restSeconds: 60 },
              { name: 'Hammer Curl', sets: 2, reps: '10-12', restSeconds: 60 },
            ]
          },
        ]
      }
    ]
  },
  {
    name: 'Powerbuilding Program',
    description: 'Hybrid powerbuilding, 5 days per week. Combines heavy compound lifts with hypertrophy accessory work.',
    category: 'Powerbuilding',
    difficulty: 'Advanced',
    weeks: 8,
    daysPerWeek: 5,
    isDefault: true,
    schedule: [
      {
        weekNumber: 1,
        name: 'Week 1',
        days: [
          {
            dayNumber: 1, name: 'Heavy Squat + Legs',
            exercises: [
              { name: 'Barbell Squat', sets: 5, reps: '3-5', restSeconds: 240 },
              { name: 'Pause Squat', sets: 3, reps: '5', percentage1rm: 70, restSeconds: 180 },
              { name: 'Leg Press', sets: 4, reps: '10-12', restSeconds: 120 },
              { name: 'Lying Leg Curl', sets: 4, reps: '10-12', restSeconds: 90 },
              { name: 'Standing Calf Raise', sets: 4, reps: '12-15', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 2, name: 'Heavy Bench + Chest/Tri',
            exercises: [
              { name: 'Barbell Bench Press', sets: 5, reps: '3-5', restSeconds: 240 },
              { name: 'Close Grip Bench Press', sets: 3, reps: '6-8', restSeconds: 120 },
              { name: 'Incline Dumbbell Bench Press', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Cable Crossover', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Skull Crusher', sets: 3, reps: '10-12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 3, name: 'Heavy Deadlift + Back',
            exercises: [
              { name: 'Deadlift', sets: 5, reps: '3-5', restSeconds: 300 },
              { name: 'Barbell Row', sets: 4, reps: '6-8', restSeconds: 120 },
              { name: 'Pull-Up', sets: 4, reps: '6-10', restSeconds: 120 },
              { name: 'Seated Cable Row', sets: 3, reps: '10-12', restSeconds: 90 },
              { name: 'Face Pull', sets: 3, reps: '15-20', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 4, name: 'Heavy OHP + Shoulders/Arms',
            exercises: [
              { name: 'Overhead Press', sets: 5, reps: '3-5', restSeconds: 240 },
              { name: 'Arnold Press', sets: 3, reps: '8-12', restSeconds: 90 },
              { name: 'Lateral Raise', sets: 4, reps: '12-15', restSeconds: 60 },
              { name: 'Rear Delt Fly', sets: 3, reps: '15', restSeconds: 60 },
              { name: 'Barbell Curl', sets: 3, reps: '8-12', restSeconds: 60 },
              { name: 'Rope Pushdown', sets: 3, reps: '10-12', restSeconds: 60 },
            ]
          },
          {
            dayNumber: 5, name: 'Hypertrophy Legs',
            exercises: [
              { name: 'Front Squat', sets: 3, reps: '8-10', restSeconds: 120 },
              { name: 'Romanian Deadlift', sets: 4, reps: '8-12', restSeconds: 120 },
              { name: 'Bulgarian Split Squat', sets: 3, reps: '10-12', restSeconds: 90 },
              { name: 'Leg Extension', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Seated Leg Curl', sets: 3, reps: '12-15', restSeconds: 60 },
              { name: 'Seated Calf Raise', sets: 4, reps: '15-20', restSeconds: 60 },
            ]
          },
        ]
      }
    ]
  },
];

module.exports = programs;
