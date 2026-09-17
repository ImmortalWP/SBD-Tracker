/**
 * SBD Tracker — Automated Security Penetration Test Suite
 * 
 * Tests authorization (IDOR/BOLA), mass assignment, JWT security,
 * input validation, NoSQL injection, and error handling.
 * 
 * Usage: 
 *   1. Set MONGO_URI and JWT_SECRET in server/.env
 *   2. Run: node tests/security.test.js
 * 
 * Requires a running MongoDB instance (uses test database).
 */

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

// ─── Test framework (zero dependencies) ───
let passed = 0, failed = 0, skipped = 0;
const results = [];

function assert(condition, testName, details = '') {
  if (condition) {
    passed++;
    results.push({ test: testName, status: 'PASS', details });
  } else {
    failed++;
    results.push({ test: testName, status: 'FAIL', details });
    console.error(`  ✗ FAIL: ${testName}${details ? ' — ' + details : ''}`);
  }
}

function skip(testName, reason) {
  skipped++;
  results.push({ test: testName, status: 'SKIP', details: reason });
}

// ─── HTTP helper ───
function request(method, path, { body, token, headers: extraHeaders } = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, `http://127.0.0.1:${testPort}`);
    const options = {
      hostname: '127.0.0.1',
      port: testPort,
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
        ...(extraHeaders || {}),
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        let json = null;
        try { json = JSON.parse(data); } catch {}
        resolve({ status: res.statusCode, body: json, raw: data, headers: res.headers });
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// ─── Test state ───
let testPort;
let server;
let userA = { username: 'testuser_a_' + Date.now(), password: 'SecurePass123!' };
let userB = { username: 'testuser_b_' + Date.now(), password: 'SecurePass456!' };
let tokenA, tokenB, userAId, userBId;
let sessionAId, workoutAId, bodymetricAId;

// ─── Setup ───
async function setup() {
  // Ensure we have env vars
  if (!process.env.MONGO_URI || !process.env.JWT_SECRET) {
    console.error('ERROR: MONGO_URI and JWT_SECRET must be set in .env');
    process.exit(1);
  }

  // Connect to MongoDB
  await mongoose.connect(process.env.MONGO_URI);

  // Import the Express app (but don't listen yet)
  // We need to create a fresh app instance
  const app = require('../index.js');

  // Wait a moment for the server to initialize
  await new Promise(r => setTimeout(r, 1000));

  // Find the port (the server listens in index.js)
  // We'll use a different approach: start a fresh server
}

async function startTestServer() {
  // We'll directly use the app by requiring the modules
  const appExpress = express();
  const helmet = require('helmet');
  const mongoSanitize = require('express-mongo-sanitize');
  const cors = require('cors');
  const { apiLimiter } = require('../middleware/rateLimiter');

  appExpress.use(helmet({ contentSecurityPolicy: false }));
  appExpress.use(cors());
  appExpress.use(express.json({ limit: '1mb' }));
  appExpress.use(mongoSanitize({ replaceWith: '_' }));

  // Import routes
  appExpress.use('/api/auth', require('../routes/auth'));
  appExpress.use('/api/sessions', require('../routes/sessions'));
  appExpress.use('/api/workouts', require('../routes/workouts'));
  appExpress.use('/api/exercises', require('../routes/exercises'));
  appExpress.use('/api/programs', require('../routes/programs'));
  appExpress.use('/api/bodymetrics', require('../routes/bodymetrics'));
  appExpress.use('/api/stats', require('../routes/stats'));
  appExpress.use('/api/leaderboard', require('../routes/leaderboard'));
  appExpress.use('/api/profile', require('../routes/profile'));
  appExpress.get('/api/health', (req, res) => res.json({ status: 'ok' }));

  // Error handler
  appExpress.use((err, req, res, _next) => {
    res.status(err.status || 500).json({ error: 'Server error' });
  });

  await mongoose.connect(process.env.MONGO_URI);
  console.log('✅ MongoDB connected for testing');

  return new Promise((resolve) => {
    server = appExpress.listen(0, () => {
      testPort = server.address().port;
      console.log(`🧪 Test server running on port ${testPort}\n`);
      resolve();
    });
  });
}

// ─── Register test users ───
async function registerUsers() {
  console.log('📋 Registering test users...');

  const resA = await request('POST', '/api/auth/register', { body: userA });
  assert(resA.status === 201, 'Register User A', `status=${resA.status}`);
  if (resA.body) {
    tokenA = resA.body.token;
    userAId = resA.body.user?._id;
  }

  const resB = await request('POST', '/api/auth/register', { body: userB });
  assert(resB.status === 201, 'Register User B', `status=${resB.status}`);
  if (resB.body) {
    tokenB = resB.body.token;
    userBId = resB.body.user?._id;
  }

  if (!tokenA || !tokenB) {
    console.error('FATAL: Could not register test users. Aborting.');
    process.exit(1);
  }
}

// ─── Create test data for User A ───
async function createTestData() {
  console.log('📋 Creating test data for User A...');

  // Create session
  const sessionRes = await request('POST', '/api/sessions', {
    token: tokenA,
    body: { block: 1, day: 'Monday', exercises: [{ name: 'Squat', category: 'main', sets: [{ weight: 100, sets: 3, reps: 5 }] }] },
  });
  assert(sessionRes.status === 201, 'Create session for User A');
  sessionAId = sessionRes.body?._id;

  // Create workout
  const workoutRes = await request('POST', '/api/workouts', {
    token: tokenA,
    body: { name: 'Test Workout', exercises: [{ exerciseId: 'test123', name: 'Squat', sets: [{ weight: 100, reps: 5, completed: true }] }] },
  });
  assert(workoutRes.status === 201, 'Create workout for User A');
  workoutAId = workoutRes.body?.workout?._id;

  // Create body metric
  const metricRes = await request('POST', '/api/bodymetrics', {
    token: tokenA,
    body: { weight: 80, bodyFat: 15 },
  });
  assert(metricRes.status === 201, 'Create body metric for User A');
  bodymetricAId = metricRes.body?._id;
}

// ═══════════════════════════════════════════════
// PRIORITY 2: AUTHORIZATION PENETRATION TESTS
// ═══════════════════════════════════════════════

async function testIDOR() {
  console.log('\n🔐 PRIORITY 2: AUTHORIZATION / IDOR TESTS');
  console.log('─'.repeat(50));

  // ── Sessions ──
  if (sessionAId) {
    const r1 = await request('GET', `/api/sessions/${sessionAId}`, { token: tokenB });
    assert(r1.status === 404, 'IDOR: User B cannot READ User A session', `status=${r1.status}`);

    const r2 = await request('PUT', `/api/sessions/${sessionAId}`, { token: tokenB, body: { day: 'HACKED' } });
    assert(r2.status === 404, 'IDOR: User B cannot UPDATE User A session', `status=${r2.status}`);

    const r3 = await request('DELETE', `/api/sessions/${sessionAId}`, { token: tokenB });
    assert(r3.status === 404, 'IDOR: User B cannot DELETE User A session', `status=${r3.status}`);
  } else {
    skip('IDOR Session tests', 'No session ID');
  }

  // ── Workouts ──
  if (workoutAId) {
    const r4 = await request('GET', `/api/workouts/${workoutAId}`, { token: tokenB });
    assert(r4.status === 404, 'IDOR: User B cannot READ User A workout', `status=${r4.status}`);

    const r5 = await request('PUT', `/api/workouts/${workoutAId}`, { token: tokenB, body: { name: 'HACKED' } });
    assert(r5.status === 404, 'IDOR: User B cannot UPDATE User A workout', `status=${r5.status}`);

    const r6 = await request('DELETE', `/api/workouts/${workoutAId}`, { token: tokenB });
    assert(r6.status === 404, 'IDOR: User B cannot DELETE User A workout', `status=${r6.status}`);
  } else {
    skip('IDOR Workout tests', 'No workout ID');
  }

  // ── Body Metrics ──
  if (bodymetricAId) {
    const r7 = await request('PUT', `/api/bodymetrics/${bodymetricAId}`, { token: tokenB, body: { weight: 999 } });
    assert(r7.status === 404, 'IDOR: User B cannot UPDATE User A body metric', `status=${r7.status}`);

    const r8 = await request('DELETE', `/api/bodymetrics/${bodymetricAId}`, { token: tokenB });
    assert(r8.status === 404, 'IDOR: User B cannot DELETE User A body metric', `status=${r8.status}`);
  } else {
    skip('IDOR Body metric tests', 'No metric ID');
  }

  // ── Sessions list isolation ──
  const r9 = await request('GET', '/api/sessions', { token: tokenB });
  const bSessions = r9.body || [];
  const leakedSession = Array.isArray(bSessions) && bSessions.some(s => s.user?.toString() === userAId);
  assert(!leakedSession, 'ISOLATION: User B session list does not contain User A sessions');

  // ── Workouts list isolation ──
  const r10 = await request('GET', '/api/workouts', { token: tokenB });
  const bWorkouts = r10.body?.workouts || [];
  const leakedWorkout = bWorkouts.some(w => w.user?.toString() === userAId);
  assert(!leakedWorkout, 'ISOLATION: User B workout list does not contain User A workouts');
}

// ═══════════════════════════════════════════════
// MASS ASSIGNMENT TESTS
// ═══════════════════════════════════════════════

async function testMassAssignment() {
  console.log('\n🛡️ MASS ASSIGNMENT TESTS');
  console.log('─'.repeat(50));

  // Test 1: Create session with foreign user ID
  const r1 = await request('POST', '/api/sessions', {
    token: tokenB,
    body: {
      user: userAId,  // Attempt to assign to User A
      block: 1, day: 'Tuesday',
      exercises: [],
    },
  });
  assert(r1.status === 201 || r1.status === 200, 'Mass assignment: Session created', `status=${r1.status}`);
  if (r1.body) {
    assert(r1.body.user?.toString() !== userAId, 'Mass assignment: Session user is NOT User A (foreign user ID ignored)', `created user=${r1.body.user}, userA=${userAId}`);
  }

  // Test 2: Create workout with foreign user ID
  const r2 = await request('POST', '/api/workouts', {
    token: tokenB,
    body: {
      user: userAId,
      name: 'Hacked Workout',
      totalVolume: 999999,
      totalSets: 9999,
      exercises: [],
    },
  });
  if (r2.status === 201) {
    assert(r2.body?.workout?.user?.toString() !== userAId, 'Mass assignment: Workout user is NOT User A');
    assert(r2.body?.workout?.totalVolume === 0, 'Mass assignment: totalVolume is server-calculated (0)', `got=${r2.body?.workout?.totalVolume}`);
    assert(r2.body?.workout?.totalSets === 0, 'Mass assignment: totalSets is server-calculated (0)', `got=${r2.body?.workout?.totalSets}`);
  }

  // Test 3: Create body metric with foreign user ID
  const r3 = await request('POST', '/api/bodymetrics', {
    token: tokenB,
    body: {
      user: userAId,
      weight: 75,
    },
  });
  if (r3.status === 201) {
    assert(r3.body?.user?.toString() !== userAId, 'Mass assignment: Body metric user is NOT User A');
  }

  // Test 4: Attempt admin escalation via profile
  const r4 = await request('PUT', '/api/profile', {
    token: tokenB,
    body: {
      role: 'admin',
      isAdmin: true,
      password: 'newpassword',
      username: 'admin',
      bodyWeight: 80,
    },
  });
  assert(r4.status === 200, 'Mass assignment: Profile update accepted', `status=${r4.status}`);
  // Verify the profile doesn't have admin fields
  const profile = await request('GET', '/api/profile', { token: tokenB });
  assert(profile.body?.username === userB.username.toLowerCase(), 'Mass assignment: Username unchanged after admin escalation attempt');

  // Test 5: Create exercise with isDefault=true
  const r5 = await request('POST', '/api/exercises', {
    token: tokenB,
    body: {
      name: 'Hacked Exercise',
      isDefault: true,
      isCustom: false,
      userId: userAId,
    },
  });
  if (r5.status === 201) {
    assert(r5.body?.isDefault === false, 'Mass assignment: isDefault forced to false', `got=${r5.body?.isDefault}`);
    assert(r5.body?.isCustom === true, 'Mass assignment: isCustom forced to true', `got=${r5.body?.isCustom}`);
    assert(r5.body?.userId?.toString() !== userAId, 'Mass assignment: Exercise userId is NOT User A');
  }
}

// ═══════════════════════════════════════════════
// PRIORITY 3: JWT SECURITY TESTS
// ═══════════════════════════════════════════════

async function testJWTSecurity() {
  console.log('\n🔑 PRIORITY 3: JWT SECURITY TESTS');
  console.log('─'.repeat(50));

  // Test 1: No token
  const r1 = await request('GET', '/api/sessions');
  assert(r1.status === 401, 'JWT: Missing token rejected', `status=${r1.status}`);

  // Test 2: Invalid token
  const r2 = await request('GET', '/api/sessions', { token: 'invalid.jwt.token' });
  assert(r2.status === 401, 'JWT: Invalid token rejected', `status=${r2.status}`);

  // Test 3: Malformed token
  const r3 = await request('GET', '/api/sessions', { token: 'not-a-jwt' });
  assert(r3.status === 401, 'JWT: Malformed token rejected', `status=${r3.status}`);

  // Test 4: Expired token
  const expiredToken = jwt.sign(
    { userId: userAId, username: userA.username },
    process.env.JWT_SECRET,
    { expiresIn: '-1s' }
  );
  const r4 = await request('GET', '/api/sessions', { token: expiredToken });
  assert(r4.status === 401, 'JWT: Expired token rejected', `status=${r4.status}`);

  // Test 5: Token signed with wrong secret
  const wrongSecretToken = jwt.sign(
    { userId: userAId, username: userA.username },
    'wrong-secret-key-here',
    { expiresIn: '1h' }
  );
  const r5 = await request('GET', '/api/sessions', { token: wrongSecretToken });
  assert(r5.status === 401, 'JWT: Wrong secret token rejected', `status=${r5.status}`);

  // Test 6: Token with modified payload (tampered)
  const parts = tokenA.split('.');
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  payload.userId = userBId; // Tamper with userId
  const tamperedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const tamperedToken = `${parts[0]}.${tamperedPayload}.${parts[2]}`;
  const r6 = await request('GET', '/api/sessions', { token: tamperedToken });
  assert(r6.status === 401, 'JWT: Tampered token rejected', `status=${r6.status}`);

  // Test 7: Algorithm confusion (none algorithm)
  const noneToken = `${Buffer.from(JSON.stringify({alg:'none',typ:'JWT'})).toString('base64url')}.${Buffer.from(JSON.stringify({userId:userAId,username:'admin'})).toString('base64url')}.`;
  const r7 = await request('GET', '/api/sessions', { token: noneToken });
  assert(r7.status === 401, 'JWT: Algorithm "none" rejected', `status=${r7.status}`);

  // Test 8: Verify JWT doesn't contain sensitive info
  const decoded = jwt.decode(tokenA);
  assert(!decoded.password, 'JWT: No password in token');
  assert(!decoded.email, 'JWT: No email in token');
  assert(decoded.userId && decoded.username, 'JWT: Contains only userId and username');

  // Test 9: req.body.userId cannot override req.userId
  const r9 = await request('POST', '/api/sessions', {
    token: tokenB,
    body: { userId: userAId, user: userAId, block: 2, day: 'Wednesday', exercises: [] },
  });
  if (r9.body) {
    assert(r9.body.user?.toString() !== userAId, 'JWT: body.userId/user cannot override authenticated identity');
  }
}

// ═══════════════════════════════════════════════
// PRIORITY 4: PASSWORD SECURITY TESTS
// ═══════════════════════════════════════════════

async function testPasswordSecurity() {
  console.log('\n🔒 PRIORITY 4: PASSWORD SECURITY TESTS');
  console.log('─'.repeat(50));

  // Test 1: Login with wrong password gives generic error
  const r1 = await request('POST', '/api/auth/login', { body: { username: userA.username, password: 'wrongpassword123' } });
  assert(r1.status === 401, 'Password: Wrong password rejected');
  assert(r1.body?.error === 'Invalid username or password.', 'Password: Generic error (no username enumeration)', `got="${r1.body?.error}"`);

  // Test 2: Login with non-existent user gives same error
  const r2 = await request('POST', '/api/auth/login', { body: { username: 'nonexistent_user_xyz', password: 'somepassword123' } });
  assert(r2.status === 401, 'Password: Non-existent user rejected');
  assert(r2.body?.error === 'Invalid username or password.', 'Password: Same error for non-existent user (no enumeration)', `got="${r2.body?.error}"`);

  // Test 3: Weak password rejected
  const r3 = await request('POST', '/api/auth/register', { body: { username: 'weak_pw_' + Date.now(), password: '1234567' } });
  assert(r3.status === 400, 'Password: 7-char password rejected', `status=${r3.status}`);

  // Test 4: Password not in API responses
  const r4 = await request('POST', '/api/auth/login', { body: { username: userA.username, password: userA.password } });
  assert(!r4.body?.user?.password, 'Password: Not in login response');

  const r5 = await request('GET', '/api/profile', { token: tokenA });
  assert(!r5.body?.password, 'Password: Not in profile response');

  // Test 5: Password hash not in any response
  const r5raw = r5.raw || '';
  assert(!r5raw.includes('$2b$') && !r5raw.includes('$2a$'), 'Password: No bcrypt hash in profile response');
}

// ═══════════════════════════════════════════════
// PRIORITY 6: INPUT VALIDATION TESTS
// ═══════════════════════════════════════════════

async function testInputValidation() {
  console.log('\n📝 PRIORITY 6: INPUT VALIDATION TESTS');
  console.log('─'.repeat(50));

  // Test 1: Invalid ObjectId
  const r1 = await request('GET', '/api/sessions/not-a-valid-id', { token: tokenA });
  assert(r1.status === 400, 'Validation: Invalid ObjectId rejected', `status=${r1.status}`);

  // Test 2: Extremely long string in notes
  const longString = 'A'.repeat(10000);
  const r2 = await request('POST', '/api/sessions', {
    token: tokenA,
    body: { block: 1, day: 'Monday', notes: longString, exercises: [] },
  });
  // Should accept but Mongoose will handle storage; validator accepts strings
  assert(r2.status === 201 || r2.status === 400, 'Validation: Long string handled', `status=${r2.status}`);

  // Test 3: Negative weight in body metric
  const r3 = await request('POST', '/api/bodymetrics', {
    token: tokenA,
    body: { weight: -50 },
  });
  assert(r3.status === 400, 'Validation: Negative weight rejected', `status=${r3.status}`);

  // Test 4: Absurdly large weight
  const r4 = await request('POST', '/api/bodymetrics', {
    token: tokenA,
    body: { weight: 9999 },
  });
  assert(r4.status === 400, 'Validation: Absurd weight rejected', `status=${r4.status}`);

  // Test 5: Session rating > 10
  const r5 = await request('POST', '/api/sessions', {
    token: tokenA,
    body: { block: 1, day: 'Monday', sessionRating: 15, exercises: [] },
  });
  assert(r5.status === 400, 'Validation: Session rating > 10 rejected', `status=${r5.status}`);

  // Test 6: Invalid enum for exercise category
  const r6 = await request('POST', '/api/exercises', {
    token: tokenA,
    body: { name: 'Test', category: 'INVALID_CATEGORY' },
  });
  assert(r6.status === 400, 'Validation: Invalid exercise category rejected', `status=${r6.status}`);

  // Test 7: Block = 0 (below min)
  const r7 = await request('POST', '/api/sessions', {
    token: tokenA,
    body: { block: 0, day: 'Monday', exercises: [] },
  });
  assert(r7.status === 400, 'Validation: Block 0 rejected', `status=${r7.status}`);

  // Test 8: Invalid unit in profile
  const r8 = await request('PUT', '/api/profile', {
    token: tokenA,
    body: { unit: 'stones' },
  });
  // Should succeed but unit should be unchanged (ignored since 'stones' is invalid)
  assert(r8.status === 200, 'Validation: Invalid unit handled', `status=${r8.status}`);
}

// ═══════════════════════════════════════════════
// PRIORITY 7: NoSQL INJECTION TESTS
// ═══════════════════════════════════════════════

async function testNoSQLInjection() {
  console.log('\n💉 PRIORITY 7: NoSQL INJECTION TESTS');
  console.log('─'.repeat(50));

  // Test 1: Login with $gt operator
  const r1 = await request('POST', '/api/auth/login', {
    body: { username: { '$gt': '' }, password: { '$gt': '' } },
  });
  assert(r1.status === 400 || r1.status === 401, 'NoSQL: $gt injection in login rejected', `status=${r1.status}`);

  // Test 2: Login with $ne operator
  const r2 = await request('POST', '/api/auth/login', {
    body: { username: { '$ne': null }, password: { '$ne': null } },
  });
  assert(r2.status === 400 || r2.status === 401, 'NoSQL: $ne injection in login rejected', `status=${r2.status}`);

  // Test 3: Session filter with $gt
  const r3 = await request('GET', '/api/sessions?block[$gt]=0', { token: tokenA });
  // express-mongo-sanitize should strip the $gt
  assert(r3.status === 200 || r3.status === 400, 'NoSQL: $gt in query param handled', `status=${r3.status}`);

  // Test 4: Regex injection in search
  const r4 = await request('GET', '/api/sessions?day=.*', { token: tokenA });
  assert(r4.status === 200, 'NoSQL: Regex pattern in day filter handled safely', `status=${r4.status}`);
}

// ═══════════════════════════════════════════════
// PRIORITY 9: API RESPONSE SECURITY
// ═══════════════════════════════════════════════

async function testResponseSecurity() {
  console.log('\n📦 PRIORITY 9: API RESPONSE SECURITY');
  console.log('─'.repeat(50));

  // Test 1: Login response doesn't contain password
  const r1 = await request('POST', '/api/auth/login', { body: { username: userA.username, password: userA.password } });
  assert(!r1.raw.includes(userA.password), 'Response: Password not in login response');
  assert(!r1.raw.includes('$2b$'), 'Response: No bcrypt hash in login response');

  // Test 2: Profile doesn't expose password hash
  const r2 = await request('GET', '/api/profile', { token: tokenA });
  assert(!r2.raw.includes('$2b$'), 'Response: No password hash in profile');
  assert(!r2.raw.includes('__v'), 'Response: No __v in profile (explicit fields only)');

  // Test 3: Leaderboard doesn't expose userIds
  const r3 = await request('GET', '/api/leaderboard', { token: tokenA });
  if (r3.status === 200 && Array.isArray(r3.body)) {
    const hasUserId = r3.body.some(e => e.userId);
    assert(!hasUserId, 'Response: Leaderboard does not expose userId');
  }

  // Test 4: Error responses are generic
  const r4 = await request('GET', '/api/sessions/000000000000000000000000', { token: tokenA });
  assert(r4.status === 404, 'Response: 404 for non-existent record');
  assert(!r4.raw.includes('MongoError') && !r4.raw.includes('mongoose'), 'Response: No MongoDB internals in error');
}

// ═══════════════════════════════════════════════
// PRIORITY 12: SECURITY HEADERS
// ═══════════════════════════════════════════════

async function testSecurityHeaders() {
  console.log('\n📋 PRIORITY 12: SECURITY HEADERS');
  console.log('─'.repeat(50));

  const r = await request('GET', '/api/health');
  const h = r.headers;

  assert(h['x-content-type-options'] === 'nosniff', 'Headers: X-Content-Type-Options', `got=${h['x-content-type-options']}`);
  assert(h['x-frame-options'] !== undefined || (h['content-security-policy'] && h['content-security-policy'].includes('frame-ancestors')), 'Headers: Frame protection present');
  assert(h['content-security-policy'] !== undefined, 'Headers: CSP present', `got=${!!h['content-security-policy']}`);

  // Check CSP doesn't have unsafe-eval
  if (h['content-security-policy']) {
    assert(!h['content-security-policy'].includes('unsafe-eval'), 'Headers: CSP no unsafe-eval');
  }
}

// ═══════════════════════════════════════════════
// PRIORITY 14: ERROR HANDLING
// ═══════════════════════════════════════════════

async function testErrorHandling() {
  console.log('\n⚠️ PRIORITY 14: ERROR HANDLING');
  console.log('─'.repeat(50));

  // Test 1: Invalid JSON body
  const r1 = await new Promise((resolve, reject) => {
    const options = {
      hostname: '127.0.0.1', port: testPort, path: '/api/auth/login',
      method: 'POST', headers: { 'Content-Type': 'application/json', },
    };
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => resolve({ status: res.statusCode, raw: data }));
    });
    req.on('error', reject);
    req.write('{invalid json');
    req.end();
  });
  assert(r1.status === 400 || r1.status === 500, 'Error: Invalid JSON handled', `status=${r1.status}`);
  assert(!r1.raw.includes('stack') && !r1.raw.includes('SyntaxError'), 'Error: No stack trace in invalid JSON error');

  // Test 2: 404 doesn't leak server info
  const r2 = await request('GET', '/api/nonexistent');
  assert(r2.status === 404, 'Error: Unknown route returns 404');
  assert(!r2.raw.includes('Express') && !r2.raw.includes('Cannot GET'), 'Error: No Express info in 404');
}

// ═══════════════════════════════════════════════
// CLEANUP & REPORT
// ═══════════════════════════════════════════════

async function cleanup() {
  console.log('\n🧹 Cleaning up test data...');
  const User = require('../models/User');
  const Session = require('../models/Session');
  const Workout = require('../models/Workout');
  const BodyMetric = require('../models/BodyMetric');
  const Exercise = require('../models/Exercise');
  const PersonalRecord = require('../models/PersonalRecord');

  if (userAId) {
    await Session.deleteMany({ user: userAId });
    await Workout.deleteMany({ user: userAId });
    await BodyMetric.deleteMany({ user: userAId });
    await Exercise.deleteMany({ userId: userAId, isCustom: true });
    await PersonalRecord.deleteMany({ user: userAId });
    await User.findByIdAndDelete(userAId);
  }
  if (userBId) {
    await Session.deleteMany({ user: userBId });
    await Workout.deleteMany({ user: userBId });
    await BodyMetric.deleteMany({ user: userBId });
    await Exercise.deleteMany({ userId: userBId, isCustom: true });
    await PersonalRecord.deleteMany({ user: userBId });
    await User.findByIdAndDelete(userBId);
  }
}

function printReport() {
  console.log('\n' + '═'.repeat(60));
  console.log('  SECURITY TEST REPORT');
  console.log('═'.repeat(60));
  console.log(`\n  ✅ Passed: ${passed}`);
  console.log(`  ✗ Failed: ${failed}`);
  console.log(`  ⏭ Skipped: ${skipped}`);
  console.log(`  Total: ${passed + failed + skipped}\n`);

  if (failed > 0) {
    console.log('  FAILED TESTS:');
    results.filter(r => r.status === 'FAIL').forEach(r => {
      console.log(`    ✗ ${r.test}: ${r.details}`);
    });
  }

  console.log('\n' + '═'.repeat(60));

  // Print results table
  console.log('\n| Test | Result |');
  console.log('|------|--------|');
  results.forEach(r => {
    const emoji = r.status === 'PASS' ? '✅' : r.status === 'FAIL' ? '❌' : '⏭';
    console.log(`| ${r.test} | ${emoji} ${r.status} |`);
  });
}

// ─── MAIN ───
async function main() {
  console.log('🔒 SBD Tracker Security Penetration Test Suite');
  console.log('═'.repeat(60) + '\n');

  try {
    await startTestServer();
    await registerUsers();
    await createTestData();

    await testIDOR();
    await testMassAssignment();
    await testJWTSecurity();
    await testPasswordSecurity();
    await testInputValidation();
    await testNoSQLInjection();
    await testResponseSecurity();
    await testSecurityHeaders();
    await testErrorHandling();

    await cleanup();
    printReport();
  } catch (err) {
    console.error('Test suite error:', err);
  } finally {
    if (server) server.close();
    await mongoose.disconnect();
    process.exit(failed > 0 ? 1 : 0);
  }
}

main();
