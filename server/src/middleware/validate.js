const sanitizeHtml = require('sanitize-html');

function requireFields(...fields) {
  return (req, res, next) => {
    const missing = fields.filter(f => {
      const val = req.body[f];
      return val === undefined || val === null || (typeof val === 'string' && val.trim() === '');
    });
    if (missing.length > 0) {
      return res.status(400).json({
        success: false,
        error: `缺少必填字段: ${missing.join(', ')}`,
        code: 'VALIDATION_ERROR'
      });
    }
    next();
  };
}

function validateFields(rules) {
  return (req, res, next) => {
    for (const [field, validators] of Object.entries(rules)) {
      const val = req.body[field];
      for (const v of validators) {
        const error = v(val, field);
        if (error) {
          return res.status(400).json({ success: false, error, code: 'VALIDATION_ERROR' });
        }
      }
    }
    next();
  };
}

function minLength(min) {
  return (val, field) => {
    if (typeof val === 'string' && val.length < min) {
      return `${field} 长度不能少于 ${min} 个字符`;
    }
    return null;
  };
}

function maxLength(max) {
  return (val, field) => {
    if (typeof val === 'string' && val.length > max) {
      return `${field} 长度不能超过 ${max} 个字符`;
    }
    return null;
  }
}

function isNumber(fieldLabel) {
  return (val, field) => {
    if (val !== undefined && val !== null && isNaN(Number(val))) {
      return `${fieldLabel || field} 必须是数字`;
    }
    return null;
  };
}

function isIn(values, fieldLabel) {
  return (val, field) => {
    if (val !== undefined && val !== null && !values.includes(val)) {
      return `${fieldLabel || field} 取值无效`;
    }
    return null;
  };
}

const sanitizeHtmlOptions = {
  allowedTags: sanitizeHtml.defaults.allowedTags.concat(['img', 'h1', 'h2', 'h3', 'figure', 'figcaption', 'video', 'source', 'iframe']),
  allowedAttributes: {
    ...sanitizeHtml.defaults.allowedAttributes,
    img: ['src', 'alt', 'width', 'height'],
    video: ['src', 'controls', 'width', 'height'],
    source: ['src', 'type'],
    iframe: ['src', 'width', 'height', 'frameborder', 'allowfullscreen'],
  },
  allowedSchemes: ['http', 'https', 'data'],
};

function sanitizeBody(req, res, next) {
  if (req.body && typeof req.body === 'object') {
    for (const key of Object.keys(req.body)) {
      if (typeof req.body[key] === 'string') {
        const skipFields = ['images', 'specs', 'skus', 'password', 'password_hash', 'oldPassword'];
        if (skipFields.includes(key)) continue;
        if (key === 'detailHtml' || key === 'detail_html' || key === 'content') {
          req.body[key] = sanitizeHtml(req.body[key], sanitizeHtmlOptions);
        } else {
          req.body[key] = req.body[key].replace(/<[^>]*>/g, '').trim();
        }
      }
    }
  }
  next();
}

module.exports = { requireFields, validateFields, sanitizeBody, minLength, maxLength, isNumber, isIn };
