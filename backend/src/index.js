// src/index.js — Express server wiring all middleware/interceptors

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const authRoutes = require('./routes/auth.routes');
const postRoutes = require('./routes/post.routes');

const { versionMiddleware } = require('./middleware/version.middleware');
const { softDeleteMiddleware } = require('./middleware/softDelete.middleware');
const { decryptMiddleware } = require('./middleware/decrypt.middleware');
const { encryptResponse } = require('./middleware/encrypt.middleware');
const { validateRequest } = require('./middleware/validator.middleware');
const { logMiddleware } = require('./middleware/log.middleware');
const { rootDeviceMiddleware } = require('./middleware/rootDevice.middleware');

const app = express();
const PORT = process.env.PORT || 3000;

// ─── Security Headers ────────────────────────────────────────────────────────
app.use(helmet());

// ─── CORS ────────────────────────────────────────────────────────────────────
app.use(cors({
  origin: ['http://localhost:*', '*'],
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Encrypted', 'X-Soft-Delete', 'X-Device-Rooted', 'X-Screen-Origin'],
  exposedHeaders: ['X-App-Min-Version', 'X-App-Latest-Version', 'X-Encrypted', 'X-Cache'],
}));

// ─── Rate Limiting ────────────────────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: { success: false, error: 'Too many requests. Please try again later.' },
});
app.use('/api/', limiter);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { success: false, error: 'Too many login attempts. Try again in 15 minutes.' },
});
app.use('/api/auth/', authLimiter);

// ─── Body Parsing ─────────────────────────────────────────────────────────────
app.use(express.json({ limit: '1mb' }));

// ─── Logging ─────────────────────────────────────────────────────────────────
app.use(morgan('dev'));
app.use(logMiddleware); // Custom structured log middleware

// ─── Root Device Warning ─────────────────────────────────────────────────────
app.use(rootDeviceMiddleware);

// ─── Decryption (must run before route handlers) ─────────────────────────────
app.use(decryptMiddleware);

// ─── App Version Headers ──────────────────────────────────────────────────────
// Every response gets version headers so the Flutter app can check for updates
app.use(versionMiddleware);

// ─── Soft Delete Normalization ────────────────────────────────────────────────
app.use(softDeleteMiddleware);

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/posts', postRoutes);

// ─── Health Check ─────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ success: true, data: { status: 'ok', timestamp: new Date().toISOString() } });
});

// ─── 404 Handler ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, error: `Route ${req.path} not found` });
});

// ─── Global Error Handler ─────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  const status = err.status || 500;
  res.status(status).json({
    success: false,
    error: err.message || 'Internal server error',
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Interceptors Demo Backend running on http://localhost:${PORT}`);
  console.log(`📋 Routes: /api/auth, /api/posts`);
  console.log(`❤️  Health: /health`);
});
