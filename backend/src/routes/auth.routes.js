// src/routes/auth.routes.js

const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { validateRequest } = require('../middleware/validator.middleware');

const JWT_SECRET = process.env.JWT_SECRET || 'demo-jwt-secret-change-in-prod';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'demo-refresh-secret';

// In-memory store for demo (use DB in production)
const users = new Map();
const refreshTokens = new Set();

// POST /api/auth/register
router.post('/register', validateRequest, async (req, res) => {
  const { name, email, password } = req.body;

  if (users.has(email)) {
    return res.status(422).json({
      success: false,
      message: 'Validation failed',
      errors: { email: ['Email already in use'] },
    });
  }

  const hashedPassword = await bcrypt.hash(password, 10);
  const user = { id: uuidv4(), name, email, password: hashedPassword };
  users.set(email, user);

  const tokens = _issueTokens(user);
  res.status(201).json({ success: true, data: { user: _sanitize(user), ...tokens } });
});

// POST /api/auth/login
router.post('/login', validateRequest, async (req, res) => {
  const { email, password } = req.body;
  const user = users.get(email);

  if (!user || !(await bcrypt.compare(password, user.password))) {
    return res.status(401).json({ success: false, error: 'Invalid email or password' });
  }

  const tokens = _issueTokens(user);
  res.json({ success: true, data: { user: _sanitize(user), ...tokens } });
});

// POST /api/auth/refresh
router.post('/refresh', (req, res) => {
  const { refresh_token } = req.body;
  if (!refresh_token || !refreshTokens.has(refresh_token)) {
    return res.status(401).json({ success: false, error: 'Invalid or expired refresh token' });
  }

  try {
    const payload = jwt.verify(refresh_token, JWT_REFRESH_SECRET);
    refreshTokens.delete(refresh_token); // Rotate refresh token

    const user = { id: payload.sub, email: payload.email, name: payload.name };
    const tokens = _issueTokens(user);
    res.json({ success: true, data: tokens });
  } catch (_) {
    refreshTokens.delete(refresh_token);
    res.status(401).json({ success: false, error: 'Refresh token expired. Please log in again.' });
  }
});

// POST /api/auth/logout
router.post('/logout', (req, res) => {
  const { refresh_token } = req.body;
  if (refresh_token) refreshTokens.delete(refresh_token);
  res.json({ success: true, data: { message: 'Logged out successfully' } });
});

// ─── Auth Guard for protected auth routes ─────────────────────────────────────
const authGuard = (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Authentication required' });
  }
  try {
    req.user = jwt.verify(auth.slice(7), JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ success: false, error: 'Invalid or expired token' });
  }
};

// POST /api/auth/profile/delete — bio-auth protected demo endpoint
// The Flutter BioAuthDioInterceptor guards this path.
router.post('/profile/delete', authGuard, (req, res) => {
  res.json({ success: true, data: { message: 'Profile deletion request processed (demo)' } });
});

function _issueTokens(user) {
  const access_token = jwt.sign(
    { sub: user.id, email: user.email, name: user.name },
    JWT_SECRET,
    { expiresIn: '15m' },
  );
  const refresh_token = jwt.sign(
    { sub: user.id, email: user.email, name: user.name },
    JWT_REFRESH_SECRET,
    { expiresIn: '7d' },
  );
  refreshTokens.add(refresh_token);
  return { access_token, refresh_token };
}

function _sanitize(user) {
  const { password, ...safe } = user;
  return safe;
}

module.exports = router;
module.exports.JWT_SECRET = JWT_SECRET;
