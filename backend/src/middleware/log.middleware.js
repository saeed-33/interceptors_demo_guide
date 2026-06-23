// src/middleware/log.middleware.js
// 📋 Structured request/response logging

const logMiddleware = (req, res, next) => {
  const start = Date.now();
  const screen = req.headers['x-screen-origin'] || 'unknown';

  res.on('finish', () => {
    const duration = Date.now() - start;
    const log = {
      method: req.method,
      path: req.originalUrl || req.path,
      status: res.statusCode,
      duration_ms: duration,
      screen_origin: screen,
      ip: req.ip,
      timestamp: new Date().toISOString(),
    };
    // In production: write to log aggregator (e.g., Datadog, CloudWatch)
    console.log(JSON.stringify(log));
  });

  next();
};

module.exports = { logMiddleware };
