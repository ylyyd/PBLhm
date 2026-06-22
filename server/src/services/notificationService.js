const { URL } = require('url');
const jwt = require('jsonwebtoken');
const logger = require('../logger');

const JWT_SECRET = process.env.JWT_SECRET || 'happybuy_jwt_secret_2026';
const HEARTBEAT_INTERVAL = 30000;

class NotificationService {
  constructor() {
    /** @type {Map<string, Set<import('ws').WebSocket>>} */
    this.userSockets = new Map();
    this.wss = null;
    this.heartbeatTimer = null;
  }

  /**
   * Initialize with a WebSocketServer instance
   * @param {import('ws').Server} wss
   */
  init(wss) {
    this.wss = wss;
    this._setupAuth();
    this._startHeartbeat();
    logger.info('NotificationService initialized with WebSocket server');
  }

  /** Authenticate WebSocket connections via ?token= query param */
  _setupAuth() {
    this.wss.on('connection', (ws, req) => {
      try {
        const params = new URL(req.url, 'http://localhost').searchParams;
        const token = params.get('token');
        if (!token) {
          logger.warn('WebSocket connection rejected: no token');
          ws.close(4001, '未提供token');
          return;
        }
        const decoded = jwt.verify(token, JWT_SECRET);
        const username = decoded.username;
        if (!username) {
          ws.close(4001, '无效token');
          return;
        }

        ws.isAlive = true;
        ws.username = username;

        if (!this.userSockets.has(username)) {
          this.userSockets.set(username, new Set());
        }
        this.userSockets.get(username).add(ws);
        logger.info(`WebSocket connected: ${username} (total connections: ${this.userSockets.size} users)`);

        ws.on('pong', () => {
          ws.isAlive = true;
        });

        ws.on('close', () => {
          const sockets = this.userSockets.get(username);
          if (sockets) {
            sockets.delete(ws);
            if (sockets.size === 0) {
              this.userSockets.delete(username);
            }
          }
          logger.info(`WebSocket disconnected: ${username}`);
        });

        ws.on('error', (err) => {
          logger.error(`WebSocket error for ${username}: ${err.message}`);
        });

        // Send welcome message to confirm connection
        ws.send(JSON.stringify({ type: 'connected', message: 'WebSocket连接成功', username }));
      } catch (err) {
        logger.error(`WebSocket auth error: ${err.message}`);
        ws.close(4001, 'token验证失败');
      }
    });
  }

  /**
   * Send a message to a specific user
   * @param {string} username
   * @param {object} message - will be JSON.stringify'd
   */
  send(username, message) {
    const sockets = this.userSockets.get(username);
    if (!sockets || sockets.size === 0) {
      return false;
    }
    const data = typeof message === 'string' ? message : JSON.stringify(message);
    let sent = 0;
    for (const ws of sockets) {
      if (ws.readyState === 1) { // WebSocket.OPEN
        try {
          ws.send(data);
          sent++;
        } catch (err) {
          logger.error(`WebSocket send error to ${username}: ${err.message}`);
        }
      }
    }
    return sent > 0;
  }

  /**
   * Send a typed notification to a user
   * @param {string} username
   * @param {string} type - notification type (order, system, promotion)
   * @param {string} title
   * @param {string} content
   * @param {object} [extra] - optional extra data
   */
  notify(username, type, title, content, extra) {
    return this.send(username, {
      type: 'notification',
      notificationType: type,
      title,
      content,
      time: new Date().toISOString(),
      ...extra,
    });
  }

  /** Heartbeat to detect dead connections */
  _startHeartbeat() {
    this.heartbeatTimer = setInterval(() => {
      if (!this.wss) return;
      this.wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
          logger.warn(`WebSocket heartbeat timeout: ${ws.username || 'unknown'}`);
          return ws.terminate();
        }
        ws.isAlive = false;
        ws.ping();
      });
    }, HEARTBEAT_INTERVAL);
  }

  /** Clean up — call on server shutdown */
  close() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
    if (this.wss) {
      this.wss.close();
    }
    this.userSockets.clear();
    logger.info('NotificationService closed');
  }

  /** Get connection stats */
  getStats() {
    let totalConnections = 0;
    for (const sockets of this.userSockets.values()) {
      totalConnections += sockets.size;
    }
    return {
      connectedUsers: this.userSockets.size,
      totalConnections,
    };
  }
}

// Singleton
const notificationService = new NotificationService();

module.exports = notificationService;
