// src/middleware/softDelete.middleware.js
// 🗑️ Handles soft-delete semantics server-side.
// Recognizes PATCH requests with X-Soft-Delete header and sets deleted_at.

const softDeleteMiddleware = (req, res, next) => {
  if (req.method === 'PATCH' && req.headers['x-soft-delete'] === 'true') {
    // Ensure deleted_at is set to now if not provided
    if (!req.body.deleted_at) {
      req.body.deleted_at = new Date().toISOString();
    }
    req.isSoftDelete = true;
  }
  next();
};

module.exports = { softDeleteMiddleware };
