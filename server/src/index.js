require('express-async-errors');
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
const { WebSocketServer } = require('ws');
const logger = require('./logger');
const { getDb, startBackgroundTasks, healthCheck } = require('./db');
const { sanitizeBody } = require('./middleware/validate');
const notificationService = require('./services/notificationService');

// Custom error classes for unified error handling
class AppError extends Error {
  constructor(message, code = 'INTERNAL_ERROR', statusCode = 500) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
  }
}

class ValidationError extends AppError {
  constructor(message) {
    super(message, 'VALIDATION_ERROR', 400);
    this.name = 'ValidationError';
  }
}

class AuthError extends AppError {
  constructor(message, code = 'UNAUTHORIZED') {
    super(message, code, 401);
    this.name = 'AuthError';
  }
}

class NotFoundError extends AppError {
  constructor(message = '资源不存在') {
    super(message, 'NOT_FOUND', 404);
    this.name = 'NotFoundError';
  }
}

const authRoutes = require('./routes/auth');
const productRoutes = require('./routes/products');
const cartRoutes = require('./routes/cart');
const orderRoutes = require('./routes/orders');
const reviewRoutes = require('./routes/reviews');
const addressRoutes = require('./routes/addresses');
const favoriteRoutes = require('./routes/favorites');
const uploadRoutes = require('./routes/upload');
const adminRoutes = require('./routes/admin');
const trackingRoutes = require('./routes/tracking');
const paymentRoutes = require('./routes/payment');
const shopRoutes = require('./routes/shops');
const aftersalesRoutes = require('./routes/aftersales');
const messageRoutes = require('./routes/messages');
const searchHistoryRoutes = require('./routes/search-history');
const browsingHistoryRoutes = require('./routes/browsing-history');
const questionRoutes = require('./routes/questions');
const couponRoutes = require('./routes/coupons');
const invoiceRoutes = require('./routes/invoices');
const shopFollowRoutes = require('./routes/shop-follows');
const statsRoutes = require('./routes/stats');

const app = express();
const PORT = process.env.PORT || 3000;
const isDev = (process.env.NODE_ENV || 'development') === 'development';

app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  contentSecurityPolicy: false,
}));
app.use(cors({
  origin: isDev ? true : (process.env.CORS_ORIGIN || '*'),
  credentials: true,
}));
app.use(express.json({ limit: '1mb' }));
app.use(sanitizeBody);

app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const ms = Date.now() - start;
    logger.info(`${req.method} ${req.originalUrl} ${res.statusCode} ${ms}ms`);
  });
  next();
});

const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,
  message: { success: false, error: '请求过于频繁，请稍后再试', code: 'RATE_LIMITED' },
});
app.use('/api/', globalLimiter);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50,
  message: { success: false, error: '登录尝试过于频繁，请稍后再试', code: 'RATE_LIMITED' },
});
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);

const callbackLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 30,
  message: { success: false, error: '请求过于频繁', code: 'RATE_LIMITED' },
});
app.use('/api/payment/callback', callbackLimiter);
app.use('/api/v2/payment/callback', callbackLimiter);

app.get('/health', (req, res) => {
  const dbHealth = healthCheck();
  res.json({
    status: dbHealth.status === 'connected' ? 'ok' : 'degraded',
    db: dbHealth,
    uptime: process.uptime(),
    version: '2.0.0',
    timestamp: new Date().toISOString(),
    memory: process.memoryUsage ? {
      rss: Math.round(process.memoryUsage().rss / 1024 / 1024) + 'MB',
      heap: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + 'MB',
    } : undefined,
  });
});

const apiVersion = process.env.API_VERSION || 'v2';
const apiPrefix = `/api/${apiVersion}`;

const routes = [
  ['/auth', authRoutes],
  ['/products', productRoutes],
  ['/reviews', reviewRoutes],
  ['/cart', cartRoutes],
  ['/orders', orderRoutes],
  ['/addresses', addressRoutes],
  ['/favorites', favoriteRoutes],
  ['/upload', uploadRoutes],
  ['/admin', adminRoutes],
  ['/tracking', trackingRoutes],
  ['/payment', paymentRoutes],
  ['/shops', shopRoutes],
  ['/aftersales', aftersalesRoutes],
  ['/messages', messageRoutes],
  ['/search-history', searchHistoryRoutes],
  ['/browsing-history', browsingHistoryRoutes],
  ['/questions', questionRoutes],
  ['/coupons', couponRoutes],
  ['/invoices', invoiceRoutes],
  ['/shop-follows', shopFollowRoutes],
  ['/stats', statsRoutes],
];
for (const [path, router] of routes) {
  app.use(`/api${path}`, router);
  app.use(`${apiPrefix}${path}`, router);
}

app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));
app.use('/admin', express.static(path.join(__dirname, '..', 'public', 'admin')));
app.use('/payment', express.static(path.join(__dirname, '..', 'public', 'payment')));

app.use((req, res) => {
  res.status(404).json({ success: false, error: '接口不存在', code: 'NOT_FOUND' });
});

app.use((err, req, res, next) => {
  // Log structured error
  logger.error({
    message: err.message || 'Unhandled error',
    method: req.method,
    url: req.originalUrl,
    statusCode: err.statusCode || err.status || 500,
    code: err.code || 'INTERNAL_ERROR',
    name: err.name,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
  });

  // Payload too large (Express built-in)
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ success: false, error: '请求体过大', code: 'PAYLOAD_TOO_LARGE' });
  }

  // Custom AppError subclasses (ValidationError, AuthError, NotFoundError)
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({ success: false, error: err.message, code: err.code });
  }

  // JSON parse error
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({ success: false, error: '请求体格式错误', code: 'VALIDATION_ERROR' });
  }

  // Multer errors (file upload)
  if (err.name === 'MulterError' || err.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({ success: false, error: err.message || '文件上传错误', code: 'VALIDATION_ERROR' });
  }

  // Fallback — unknown internal error
  res.status(500).json({ success: false, error: '服务器内部错误', code: 'INTERNAL_ERROR' });
});

async function start() {
  const { db } = await getDb();
  startBackgroundTasks();

  function tryListen(port) {
    const server = app.listen(port, '0.0.0.0');
    server.on('listening', () => {
      if (process.env.NODE_ENV !== 'test') {
        logger.info(`HappyBuy API v2 running on http://0.0.0.0:${port} [${isDev ? 'development' : 'production'}]`);
      }

      // Attach WebSocket server to HTTP server
      const wss = new WebSocketServer({ server, path: '/ws' });
      notificationService.init(wss);
      logger.info('WebSocket server attached at /ws');

      process.on('SIGTERM', () => {
        logger.info('SIGTERM received, shutting down...');
        notificationService.close();
        if (db) db.close();
        server.close(() => process.exit(0));
      });
      process.on('SIGINT', () => {
        logger.info('SIGINT received, shutting down...');
        notificationService.close();
        if (db) db.close();
        server.close(() => process.exit(0));
      });
    });
    server.on('error', (err) => {
      if (err.code === 'EADDRINUSE' && port < PORT + 10) {
        logger.warn(`Port ${port} is in use, trying port ${port + 1}...`);
        tryListen(port + 1);
      } else {
        logger.error('Failed to start server: ' + err.message);
        process.exit(1);
      }
    });
  }

  tryListen(PORT);
}

if (process.env.NODE_ENV !== 'test') {
  start().catch(err => {
    logger.error('Failed to start server: ' + err.message);
    process.exit(1);
  });
}

module.exports = app;
