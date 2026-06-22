const winston = require('winston');
const path = require('path');

const isDev = (process.env.NODE_ENV || 'development') === 'development';

const logger = winston.createLogger({
  level: isDev ? 'debug' : 'info',
  format: winston.format.json(),
  defaultMeta: { service: 'happybuy-api' },
  transports: [
    new winston.transports.Console({
      format: isDev
        ? winston.format.combine(
            winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
            winston.format.printf(({ timestamp, level, message, ...meta }) =>
              `${timestamp} [${level.toUpperCase()}] ${message} ${Object.keys(meta).length > 1 ? JSON.stringify(meta) : ''}`
            )
          )
        : winston.format.json(),
    }),
    new winston.transports.File({
      filename: path.join(__dirname, '..', 'logs', 'error.log'),
      level: 'error',
      format: winston.format.json(),
    }),
    new winston.transports.File({
      filename: path.join(__dirname, '..', 'logs', 'combined.log'),
      format: winston.format.json(),
    }),
  ],
});

module.exports = logger;
