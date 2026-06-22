const jwt = require('jsonwebtoken');
const logger = require('../logger');
const { getDb } = require('../db');

const JWT_SECRET = (() => {
  if (process.env.JWT_SECRET) {
    return process.env.JWT_SECRET;
  }
  if (process.env.NODE_ENV === 'production') {
    logger.error('FATAL: JWT_SECRET environment variable is not set in production');
    throw new Error('JWT_SECRET environment variable is required in production mode');
  }
  const devFallback = 'happybuy_jwt_secret_2026';
  logger.warn('JWT_SECRET not set, using development fallback. Set JWT_SECRET environment variable for production.');
  return devFallback;
})();

function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: '未登录', code: 'UNAUTHORIZED' });
  }
  const token = header.slice(7);
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.username = decoded.username;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, error: '登录已过期，请重新登录', code: 'TOKEN_EXPIRED' });
    }
    logger.error('JWT verify error: ' + err.message);
    return res.status(401).json({ success: false, error: '登录已过期，请重新登录', code: 'UNAUTHORIZED' });
  }
}

function optionalAuth(req, res, next) {
  const header = req.headers.authorization;
  if (header && header.startsWith('Bearer ')) {
    const token = header.slice(7);
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      req.username = decoded.username;
    } catch (err) {
      // ignore invalid token for optional auth
    }
  }
  next();
}

function generateAccessToken(username) {
  return jwt.sign({ username, type: 'access' }, JWT_SECRET, { expiresIn: '1h' });
}

function generateRefreshToken(username) {
  return jwt.sign({ username, type: 'refresh' }, JWT_SECRET, { expiresIn: '7d' });
}

// Backward-compatible alias
const generateToken = generateAccessToken;

async function adminOnly(req, res, next) {
  const { get } = await getDb();
  const user = get('SELECT is_admin FROM users WHERE username = ?', [req.username]);
  if (!user || !user.is_admin) {
    return res.status(403).json({ success: false, error: '无权访问管理后台', code: 'FORBIDDEN' });
  }
  next();
}

module.exports = { authMiddleware, optionalAuth, adminOnly, generateToken, generateAccessToken, generateRefreshToken, JWT_SECRET };
