// src/middleware/decrypt.middleware.js
// 🔐 Decrypts request body when X-Encrypted: true header is present.
// Mirror of Flutter's EncryptInterceptor — uses AES-256-CBC.

const crypto = require('crypto');

// In production: store this in environment variables / secrets manager
const SECRET_KEY = process.env.ENCRYPTION_KEY || 'demo-secret-key-32-bytes-exactly!!';

const decryptMiddleware = (req, res, next) => {
  if (req.headers['x-encrypted'] !== 'true') return next();
  if (!req.body || !req.body.payload) return next();

  try {
    const key = Buffer.from(SECRET_KEY, 'utf8').slice(0, 32);
    const iv = Buffer.from(req.body.iv, 'base64');
    const payload = Buffer.from(req.body.payload, 'base64');

    const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
    let decrypted = decipher.update(payload);
    decrypted = Buffer.concat([decrypted, decipher.final()]);

    req.body = JSON.parse(decrypted.toString('utf8'));
    req.wasEncrypted = true;
  } catch (err) {
    return res.status(400).json({ success: false, error: 'Failed to decrypt request body.' });
  }

  next();
};

module.exports = { decryptMiddleware };
