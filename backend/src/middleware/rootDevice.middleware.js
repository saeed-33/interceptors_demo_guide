// src/middleware/rootDevice.middleware.js
// 🔒 Logs requests from rooted/jailbroken devices. Can block if needed.

const rootDeviceMiddleware = (req, res, next) => {
  const isRooted = req.headers['x-device-rooted'] === 'true';

  if (isRooted) {
    console.warn(`⚠️ Request from rooted device: ${req.ip} → ${req.method} ${req.path}`);
    // To block: return res.status(403).json({ success: false, error: 'Access denied from rooted device.' });
  }

  req.deviceRooted = isRooted;
  next();
};

module.exports = { rootDeviceMiddleware };
