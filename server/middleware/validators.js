/**
 * Input validation and sanitization helpers.
 * Server-side validation — never trust client input.
 */

/**
 * Escape a string for safe use in a MongoDB $regex query.
 * Prevents ReDoS and regex injection.
 */
function escapeRegex(str) {
  if (typeof str !== 'string') return '';
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Sanitize a string field: trim, limit length, strip control characters.
 */
function sanitizeString(value, maxLength = 1000) {
  if (typeof value !== 'string') return '';
  // Remove null bytes and control characters (except newlines/tabs for notes)
  return value.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '').trim().slice(0, maxLength);
}

/**
 * Validate and clamp a numeric value within a range.
 * Returns null if the value is not a valid number.
 */
function validateNumber(value, { min = -Infinity, max = Infinity, integer = false } = {}) {
  const num = Number(value);
  if (isNaN(num) || !isFinite(num)) return null;
  if (integer && !Number.isInteger(num)) return null;
  return Math.min(max, Math.max(min, num));
}

/**
 * Validate a MongoDB ObjectId format (24 hex chars).
 */
function isValidObjectId(id) {
  return typeof id === 'string' && /^[a-fA-F0-9]{24}$/.test(id);
}

/**
 * Pick only allowed keys from an object. Prevents mass assignment.
 */
function pickFields(obj, allowedFields) {
  if (!obj || typeof obj !== 'object') return {};
  const result = {};
  for (const field of allowedFields) {
    if (obj[field] !== undefined) {
      result[field] = obj[field];
    }
  }
  return result;
}

/**
 * Validate session input fields.
 */
function validateSessionInput(body) {
  const errors = [];
  
  if (body.block !== undefined) {
    const block = validateNumber(body.block, { min: 1, max: 100, integer: true });
    if (block === null) errors.push('Block must be an integer between 1-100');
  }

  if (body.week !== undefined && body.week !== null) {
    const week = validateNumber(body.week, { min: 1, max: 52, integer: true });
    if (week === null) errors.push('Week must be an integer between 1-52');
  }

  if (body.day !== undefined) {
    if (typeof body.day !== 'string' || body.day.trim().length === 0 || body.day.length > 50) {
      errors.push('Day must be a non-empty string (max 50 chars)');
    }
  }

  if (body.percentage !== undefined && body.percentage !== null) {
    const pct = validateNumber(body.percentage, { min: 0, max: 200 });
    if (pct === null) errors.push('Percentage must be between 0-200');
  }

  if (body.duration !== undefined && body.duration !== null) {
    const dur = validateNumber(body.duration, { min: 0, max: 86400 });
    if (dur === null) errors.push('Duration must be between 0-86400 seconds');
  }

  if (body.sessionRating !== undefined && body.sessionRating !== null) {
    const rating = validateNumber(body.sessionRating, { min: 1, max: 10, integer: true });
    if (rating === null) errors.push('Session rating must be an integer between 1-10');
  }

  if (body.notes !== undefined && typeof body.notes !== 'string') {
    errors.push('Notes must be a string');
  }

  if (body.exercises !== undefined) {
    if (!Array.isArray(body.exercises)) {
      errors.push('Exercises must be an array');
    } else if (body.exercises.length > 50) {
      errors.push('Maximum 50 exercises per session');
    }
  }

  return errors;
}

/**
 * Validate workout input fields.
 */
function validateWorkoutInput(body) {
  const errors = [];

  if (body.name !== undefined) {
    if (typeof body.name !== 'string' || body.name.length > 100) {
      errors.push('Workout name must be a string (max 100 chars)');
    }
  }

  if (body.duration !== undefined && body.duration !== null) {
    const dur = validateNumber(body.duration, { min: 0, max: 86400 });
    if (dur === null) errors.push('Duration must be between 0-86400 seconds');
  }

  if (body.notes !== undefined && typeof body.notes !== 'string') {
    errors.push('Notes must be a string');
  }

  if (body.exercises !== undefined) {
    if (!Array.isArray(body.exercises)) {
      errors.push('Exercises must be an array');
    } else if (body.exercises.length > 50) {
      errors.push('Maximum 50 exercises per workout');
    }
  }

  return errors;
}

/**
 * Validate body metric input fields.
 */
function validateBodyMetricInput(body) {
  const errors = [];

  if (body.weight !== undefined && body.weight !== null) {
    const w = validateNumber(body.weight, { min: 10, max: 500 });
    if (w === null) errors.push('Weight must be between 10-500');
  }

  if (body.bodyFat !== undefined && body.bodyFat !== null) {
    const bf = validateNumber(body.bodyFat, { min: 1, max: 70 });
    if (bf === null) errors.push('Body fat % must be between 1-70');
  }

  if (body.notes !== undefined && typeof body.notes !== 'string') {
    errors.push('Notes must be a string');
  }

  return errors;
}

/**
 * Validate profile update fields.
 */
function validateProfileInput(body) {
  const errors = [];

  if (body.bodyWeight !== undefined && body.bodyWeight !== null) {
    const bw = validateNumber(body.bodyWeight, { min: 10, max: 500 });
    if (bw === null) errors.push('Body weight must be between 10-500');
  }

  if (body.height !== undefined && body.height !== null) {
    const h = validateNumber(body.height, { min: 50, max: 300 });
    if (h === null) errors.push('Height must be between 50-300');
  }

  if (body.unit !== undefined) {
    if (!['kg', 'lbs'].includes(body.unit)) {
      errors.push('Unit must be "kg" or "lbs"');
    }
  }

  if (body.weightClass !== undefined && typeof body.weightClass !== 'string') {
    errors.push('Weight class must be a string');
  }

  return errors;
}

module.exports = {
  escapeRegex,
  sanitizeString,
  validateNumber,
  isValidObjectId,
  pickFields,
  validateSessionInput,
  validateWorkoutInput,
  validateBodyMetricInput,
  validateProfileInput,
};
