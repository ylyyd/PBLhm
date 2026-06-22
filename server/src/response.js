const { ERROR_CODES } = require('./constants');

function success(res, data = null, statusCode = 200) {
  if (data === null || data === undefined) {
    return res.status(statusCode).json({ success: true });
  }
  return res.status(statusCode).json(data);
}

function fail(res, message = '服务器内部错误', code = ERROR_CODES.INTERNAL_ERROR, statusCode = 500) {
  return res.status(statusCode).json({
    success: false,
    error: message,
    code,
  });
}

function paginated(res, { items, total, page, pageSize }) {
  return res.status(200).json({
    items,
    total,
    page,
    pageSize,
    totalPages: Math.ceil(total / pageSize),
  });
}

module.exports = { success, fail, paginated };
