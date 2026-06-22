// src/middleware/validator.middleware.js
// ✅ Schema-based request validation middleware

const schemas = {
  'POST:/api/auth/login': {
    email: { required: true, type: 'email' },
    password: { required: true, minLength: 8 },
  },
  'POST:/api/auth/register': {
    name: { required: true, minLength: 2 },
    email: { required: true, type: 'email' },
    password: { required: true, minLength: 8 },
  },
  'POST:/api/posts': {
    title: { required: true, minLength: 3, maxLength: 100 },
    body: { required: true, minLength: 10 },
  },
};

const validateRequest = (req, res, next) => {
  const key = `${req.method}:${req.path}`;
  const schema = schemas[key];
  if (!schema) return next();

  const errors = {};
  for (const [field, rule] of Object.entries(schema)) {
    const value = req.body?.[field];
    if (rule.required && !value) {
      errors[field] = [`${field} is required`];
      continue;
    }
    if (!value) continue;
    if (rule.type === 'email' && !/^[\w.-]+@[\w.-]+\.\w{2,}$/.test(value)) {
      errors[field] = [`${field} must be a valid email`];
    }
    if (rule.minLength && value.length < rule.minLength) {
      errors[field] = [`${field} must be at least ${rule.minLength} characters`];
    }
    if (rule.maxLength && value.length > rule.maxLength) {
      errors[field] = [`${field} must be at most ${rule.maxLength} characters`];
    }
  }

  if (Object.keys(errors).length > 0) {
    return res.status(422).json({ success: false, message: 'Validation failed', errors });
  }
  next();
};

module.exports = { validateRequest };
