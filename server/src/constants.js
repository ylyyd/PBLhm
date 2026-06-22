const ORDER_STATUS = {
  PENDING_PAYMENT: '待付款',
  PENDING_SHIPPING: '待发货',
  SHIPPING: '配送中',
  PENDING_RECEIPT: '待收货',
  COMPLETED: '已完成',
  CANCELLED: '已取消',
  REFUNDING: '退款中',
  REFUNDED: '已退款',
};

const ORDER_STATUS_LIST = Object.values(ORDER_STATUS);

const AFTER_SALE_STATUS = {
  PENDING: 'pending',
  PROCESSING: 'processing',
  APPROVED: 'approved',
  REJECTED: 'rejected',
};

const MESSAGE_TYPE = {
  SYSTEM: 'system',
  ORDER: 'order',
  PROMOTION: 'promotion',
};

const PAY_METHODS = ['支付宝', '微信支付', '余额支付'];

const SORT_OPTIONS = {
  price_asc: 'price_asc',
  price_desc: 'price_desc',
  sales: 'sales',
  rating: 'rating',
  newest: 'newest',
};

const ERROR_CODES = {
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  NOT_FOUND: 'NOT_FOUND',
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  CONFLICT: 'CONFLICT',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  RATE_LIMITED: 'RATE_LIMITED',
  INSUFFICIENT_STOCK: 'INSUFFICIENT_STOCK',
};

module.exports = {
  ORDER_STATUS,
  ORDER_STATUS_LIST,
  AFTER_SALE_STATUS,
  MESSAGE_TYPE,
  PAY_METHODS,
  SORT_OPTIONS,
  ERROR_CODES,
};
