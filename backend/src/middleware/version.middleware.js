// src/middleware/version.middleware.js
// 🔄 Adds app version headers to every response
// Flutter's UpdateCheckInterceptor reads these

const APP_MIN_VERSION = '1.0.0';   // Below this → force update
const APP_LATEST_VERSION = '1.2.0'; // Below this → soft update prompt

const versionMiddleware = (req, res, next) => {
  res.setHeader('X-App-Min-Version', APP_MIN_VERSION);
  res.setHeader('X-App-Latest-Version', APP_LATEST_VERSION);
  next();
};

module.exports = { versionMiddleware };
