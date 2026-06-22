// src/routes/post.routes.js
// CRUD for posts — demonstrates soft delete, cache headers, auth guard

const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const NodeCache = require('node-cache');
const { validateRequest } = require('../middleware/validator.middleware');
const { JWT_SECRET } = require('./auth.routes');

const cache = new NodeCache({ stdTTL: 300 }); // 5 min server-side cache

// In-memory posts store (use DB in production)
const posts = new Map();

// Seed some demo posts
['Intro to Interceptors', 'Dio Deep Dive', 'BLoC State Management'].forEach((title, i) => {
  const id = uuidv4();
  posts.set(id, {
    id,
    title,
    body: `This is a detailed post about ${title}. It covers all the important aspects in depth.`,
    author_id: 'seed-user',
    deleted_at: null,
    created_at: new Date(Date.now() - i * 86400000).toISOString(),
    updated_at: new Date().toISOString(),
  });
});

// ─── Auth Guard Middleware ────────────────────────────────────────────────────
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

// GET /api/posts — list (excludes soft-deleted)
router.get('/', (req, res) => {
  const cacheKey = 'posts:all';
  const cached = cache.get(cacheKey);

  if (cached) {
    res.setHeader('X-Cache', 'HIT');
    return res.json({ success: true, data: cached });
  }

  const allPosts = Array.from(posts.values())
    .filter(p => !p.deleted_at) // Server-side soft delete filter
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

  cache.set(cacheKey, allPosts);
  res.setHeader('X-Cache', 'MISS');
  res.setHeader('Cache-Control', 'max-age=300'); // Tell client to cache 5 min
  res.json({ success: true, data: allPosts });
});

// GET /api/posts/:id
router.get('/:id', (req, res) => {
  const post = posts.get(req.params.id);
  if (!post || post.deleted_at) {
    return res.status(404).json({ success: false, error: 'Post not found' });
  }
  res.setHeader('Cache-Control', 'max-age=300');
  res.json({ success: true, data: post });
});

// POST /api/posts — create (auth required)
router.post('/', authGuard, validateRequest, (req, res) => {
  const id = uuidv4();
  const post = {
    id,
    title: req.body.title,
    body: req.body.body,
    author_id: req.user.sub,
    deleted_at: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
  posts.set(id, post);
  cache.del('posts:all'); // Invalidate list cache
  res.status(201).json({ success: true, data: post });
});

// PATCH /api/posts/:id — update or soft delete
router.patch('/:id', authGuard, (req, res) => {
  const post = posts.get(req.params.id);
  if (!post) {
    return res.status(404).json({ success: false, error: 'Post not found' });
  }

  const updated = {
    ...post,
    ...req.body,
    id: post.id, // Protect immutable fields
    author_id: post.author_id,
    created_at: post.created_at,
    updated_at: new Date().toISOString(),
  };

  posts.set(post.id, updated);
  cache.del('posts:all');

  // If this was a soft delete, 204 response
  if (req.isSoftDelete) {
    return res.status(204).send();
  }

  res.json({ success: true, data: updated });
});

// DELETE /api/posts/:id — hard delete (only with explicit flag)
router.delete('/:id', authGuard, (req, res) => {
  if (!posts.has(req.params.id)) {
    return res.status(404).json({ success: false, error: 'Post not found' });
  }
  posts.delete(req.params.id);
  cache.del('posts:all');
  res.json({ success: true, data: { message: 'Post permanently deleted' } });
});

module.exports = router;
