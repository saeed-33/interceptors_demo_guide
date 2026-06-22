// src/middleware/encrypt.middleware.js
// 🔐 Encrypts response body when request was encrypted.

const crypto = require('crypto');
const SECRET_KEY = process.env.ENCRYPTION_KEY || 'demo-secret-key-32-bytes-exactly!!';

const encryptResponse = (req, res, next) => {
  if (!req.wasEncrypted) return next();

  const originalJson = res.json.bind(res);
  res.json = (data) => {
    try {
      const key = Buffer.from(SECRET_KEY, 'utf8').slice(0, 32);
      const iv = crypto.randomBytes(16);
      const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);

      const plaintext = JSON.stringify(data);
      let encrypted = cipher.update(plaintext, 'utf8', 'base64');
      encrypted += cipher.final('base64');

      res.setHeader('X-Encrypted', 'true');
      originalJson({ payload: encrypted, iv: iv.toString('base64') });
    } catch (_) {
      originalJson(data); // Fallback to unencrypted on error
    }
  };

  next();
};

module.exports = { encryptResponse };
