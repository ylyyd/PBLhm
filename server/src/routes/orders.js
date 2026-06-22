const express = require('express');
const { getDb, batch } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');
const { ORDER_STATUS } = require('../constants');
const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();
const notificationService = require('../services/notificationService');

const router = express.Router();
router.use(authMiddleware);

function addMessage(run, username, orderNumber, type, title, content) {
  const now = new Date().toISOString();
  try {
    run('INSERT INTO messages (username, order_number, type, title, content, is_read, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)',
      [username, orderNumber, type, title, content, now]);
  } catch (e) {
    logger.error('addMessage error: ' + e.message);
  }
}

function formatOrder(o, items) {
  return {
    orderNumber: o.order_number,
    username: o.username,
    totalPrice: o.total_price,
    shippingFee: o.shipping_fee || 0,
    discountAmount: o.discount_amount || 0,
    createTime: o.create_time,
    status: o.status,
    address: o.address,
    cancelReason: o.cancel_reason || '',
    payMethod: o.pay_method || '',
    payTime: o.pay_time || '',
    trackingNumber: o.tracking_number || '',
    expressCompany: o.express_company || '',
    estimatedDelivery: o.estimated_delivery || '',
    shipTime: o.ship_time || '',
    receiveTime: o.receive_time || '',
    paymentDeadline: o.payment_deadline || '',
    items: items || [],
  };
}

function mapItem(i) {
  return {
    productId: i.product_id,
    productName: i.product_name,
    productPrice: i.product_price,
    productImage: i.product_image,
    quantity: i.quantity,
    subtotal: i.product_price * i.quantity,
    skuId: i.sku_id || '',
    skuDesc: i.sku_desc || '',
  };
}

router.post('/', async (req, res) => {
  try {
    const { address, items, couponId } = req.body;
    const { all, run, get } = await getDb();

    // Validate items structure if provided
    if (items !== undefined) {
      if (!Array.isArray(items) || items.length === 0) {
        return fail(res, 'items 必须是数组且不能为空', 'VALIDATION_ERROR', 400);
      }
      for (const item of items) {
        if (!item.product_id || !Number.isInteger(Number(item.product_id))) {
          return fail(res, '商品ID无效', 'VALIDATION_ERROR', 400);
        }
        if (item.quantity !== undefined && (!Number.isInteger(Number(item.quantity)) || Number(item.quantity) < 1)) {
          return fail(res, '数量必须是正整数', 'VALIDATION_ERROR', 400);
        }
      }
    }

    if (address) {
      const userAddresses = all('SELECT detail FROM addresses WHERE username = ?', [req.username]);
      const user = get('SELECT address FROM users WHERE username = ?', [req.username]);
      const validAddresses = userAddresses.map(a => a.detail);
      if (user && user.address) validAddresses.push(user.address);
      if (validAddresses.length > 0 && !validAddresses.includes(address)) {
        return fail(res, '地址不合法，请选择您的收货地址', 'VALIDATION_ERROR', 400);
      }
    }

    let cartItems;
    if (items && items.length > 0) {
      const conditions = items.map(() => '(ci.product_id = ? AND ci.sku_id = ?)').join(' OR ');
      const params = [];
      for (const item of items) {
        params.push(item.product_id, item.sku_id || '');
      }
      cartItems = all(`
        SELECT ci.*, p.name as product_name, p.price as product_price, p.image as product_image, p.skus, p.stock
        FROM cart_items ci
        JOIN products p ON p.id = ci.product_id
        WHERE ci.username = ? AND ci.selected = 1 AND (${conditions})
      `, [req.username, ...params]);
      for (const ci of cartItems) {
        const match = items.find(i => i.product_id === ci.product_id && (i.sku_id || '') === (ci.sku_id || ''));
        if (match) ci.quantity = match.quantity;
      }
    } else {
      cartItems = all(`
        SELECT ci.*, p.name as product_name, p.price as product_price, p.image as product_image, p.skus, p.stock
        FROM cart_items ci
        JOIN products p ON p.id = ci.product_id
        WHERE ci.username = ? AND ci.selected = 1
      `, [req.username]);
    }

    if (cartItems.length === 0) {
      return fail(res, '请选择要结算的商品', 'VALIDATION_ERROR', 400);
    }

    for (const ci of cartItems) {
      const product = get('SELECT stock, skus FROM products WHERE id = ?', [ci.product_id]);
      if (!product) return fail(res, `商品 ${ci.product_name} 不存在`, 'NOT_FOUND', 400);
      if (ci.sku_id) {
        const skus = JSON.parse(product.skus || '[]');
        const sku = skus.find(s => s.id === ci.sku_id);
        if (!sku) return fail(res, `SKU不存在: ${ci.sku_id}`, 'NOT_FOUND', 400);
        if (sku.stock < ci.quantity) return fail(res, `商品 ${ci.product_name} 库存不足`, 'INSUFFICIENT_STOCK', 400);
      } else {
        if (product.stock < ci.quantity) return fail(res, `商品 ${ci.product_name} 库存不足`, 'INSUFFICIENT_STOCK', 400);
      }
    }

    for (const ci of cartItems) {
      if (ci.sku_id) {
        try {
          const skus = JSON.parse(ci.skus || '[]');
          const matched = skus.find(s => s.id === ci.sku_id);
          if (matched && matched.price) ci.product_price = matched.price;
        } catch {}
      }
    }

    const orderNumber = 'DD' + uuidv4().replace(/-/g, '').substring(0, 20).toUpperCase();
    const now = new Date();
    const createTime = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    let totalPrice = cartItems.reduce((sum, i) => sum + i.product_price * i.quantity, 0);
    const shippingFee = totalPrice >= 99 ? 0 : 10;
    let discountAmount = 0;

    if (couponId) {
      const coupon = get('SELECT * FROM coupons WHERE id = ? AND status = ?', [couponId, 'active']);
      if (coupon && totalPrice >= coupon.min_amount) {
        discountAmount = coupon.value;
        run('INSERT INTO user_coupons (username, coupon_id, used, used_time, order_number) VALUES (?, ?, 1, ?, ?)',
          [req.username, couponId, now.toISOString(), orderNumber]);
      }
    }

    const finalAmount = Math.max(0, totalPrice + shippingFee - discountAmount);
    const deadline = new Date(now.getTime() + 30 * 60 * 1000).toISOString();

    batch(() => {
      run('INSERT INTO orders (order_number, username, total_price, shipping_fee, discount_amount, create_time, address, status, payment_deadline, coupon_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [orderNumber, req.username, finalAmount, shippingFee, discountAmount, createTime, address || '', ORDER_STATUS.PENDING_PAYMENT, deadline, couponId || 0]);
      for (const item of cartItems) {
        run('INSERT INTO order_items (order_number, product_id, product_name, product_price, product_image, quantity, sku_id, sku_desc) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [orderNumber, item.product_id, item.product_name, item.product_price, item.product_image, item.quantity, item.sku_id || '', item.sku_desc || '']);
      }
      for (const item of cartItems) {
        run('DELETE FROM cart_items WHERE username = ? AND product_id = ? AND (sku_id = ? OR (sku_id IS NULL AND ? IS NULL))',
          [req.username, item.product_id, item.sku_id || '', item.sku_id || null]);
      }
    });

    success(res, {
      orderNumber,
      totalPrice: finalAmount,
      originalTotal: totalPrice,
      shippingFee,
      discountAmount,
      createTime,
      status: ORDER_STATUS.PENDING_PAYMENT,
      address: address || '',
      paymentDeadline: deadline,
    });

    notificationService.notify(req.username, 'order', '订单创建成功',
      `订单 ${orderNumber} 已创建，金额 ¥${finalAmount}，请尽快支付`);
  } catch (err) {
    logger.error('create order error: ' + err.message);
    fail(res, '创建订单失败');
  }
});

router.get('/', async (req, res) => {
  try {
    const { all } = await getDb();
    const { status, page, pageSize } = req.query;

    let orderSql = 'SELECT * FROM orders WHERE username = ?';
    const orderParams = [req.username];
    if (status) {
      orderSql += ' AND status = ?';
      orderParams.push(status);
    }

    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(50, Math.max(1, parseInt(pageSize) || 20));

    const countSql = orderSql.replace('SELECT *', 'SELECT COUNT(*) as total');
    const { total } = all(countSql, orderParams)[0];

    orderSql += ' ORDER BY create_time DESC LIMIT ? OFFSET ?';
    orderParams.push(ps, (p - 1) * ps);

    const orders = all(orderSql, orderParams);
    if (orders.length === 0) return success(res, { items: [], total: 0, page: p, pageSize: ps, totalPages: 0 });

    const orderNumbers = orders.map(o => o.order_number);
    const placeholders = orderNumbers.map(() => '?').join(',');
    const allItems = all(`SELECT * FROM order_items WHERE order_number IN (${placeholders})`, orderNumbers);
    const itemsByOrder = {};
    for (const item of allItems) {
      if (!itemsByOrder[item.order_number]) itemsByOrder[item.order_number] = [];
      itemsByOrder[item.order_number].push(mapItem(item));
    }

    success(res, {
      items: orders.map(o => ({
        ...formatOrder(o, itemsByOrder[o.order_number] || []),
        countdown: o.payment_deadline && o.status === ORDER_STATUS.PENDING_PAYMENT
          ? Math.max(0, new Date(o.payment_deadline).getTime() - Date.now())
          : 0,
      })),
      total,
      page: p,
      pageSize: ps,
      totalPages: Math.ceil(total / ps),
    });
  } catch (err) {
    logger.error('get orders error: ' + err.message);
    fail(res, '获取订单列表失败');
  }
});

router.get('/:orderNumber', async (req, res) => {
  try {
    const { get, all: allDb } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?', [req.params.orderNumber, req.username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    const items = allDb('SELECT * FROM order_items WHERE order_number = ?', [o.order_number]);
    success(res, {
      ...formatOrder(o, items.map(mapItem)),
      countdown: o.payment_deadline && o.status === ORDER_STATUS.PENDING_PAYMENT
        ? Math.max(0, new Date(o.payment_deadline).getTime() - Date.now())
        : 0,
    });
  } catch (err) {
    logger.error('get order detail error: ' + err.message);
    fail(res, '获取订单详情失败');
  }
});

router.put('/:orderNumber/cancel', async (req, res) => {
  try {
    const { reason } = req.body;
    if (reason !== undefined && reason !== null && (typeof reason !== 'string' || reason.length > 200)) {
      return fail(res, '取消原因不能超过200字', 'VALIDATION_ERROR', 400);
    }
    const { get, all, run } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?', [req.params.orderNumber, req.username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (![ORDER_STATUS.PENDING_PAYMENT, ORDER_STATUS.PENDING_SHIPPING, ORDER_STATUS.SHIPPING].includes(o.status)) {
      return fail(res, '当前订单状态不可取消', 'VALIDATION_ERROR', 400);
    }
    batch(() => {
      run('UPDATE orders SET status = ?, cancel_reason = ? WHERE order_number = ?',
        [ORDER_STATUS.CANCELLED, reason || '', req.params.orderNumber]);
      if (o.status === ORDER_STATUS.PENDING_SHIPPING || o.status === ORDER_STATUS.SHIPPING) {
        const items = all('SELECT product_id, quantity FROM order_items WHERE order_number = ?', [req.params.orderNumber]);
        for (const item of items) {
          run('UPDATE products SET stock = stock + ? WHERE id = ?', [item.quantity, item.product_id]);
        }
      }
      addMessage(run, req.username, req.params.orderNumber, 'order', '订单已取消', '您的订单已取消' + (reason ? '，原因：' + reason : ''));
    });
    success(res, { success: true });

    notificationService.notify(req.username, 'order', '订单已取消',
      `订单 ${req.params.orderNumber} 已取消` + (reason ? '，原因：' + reason : ''));
  } catch (err) {
    logger.error('cancel order error: ' + err.message);
    fail(res, '取消订单失败');
  }
});

router.put('/:orderNumber/receive', async (req, res) => {
  try {
    const { get, run } = await getDb();
    if (!req.params.orderNumber || typeof req.params.orderNumber !== 'string') {
      return fail(res, '订单号无效', 'VALIDATION_ERROR', 400);
    }
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?', [req.params.orderNumber, req.username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (![ORDER_STATUS.SHIPPING, ORDER_STATUS.PENDING_RECEIPT].includes(o.status)) return fail(res, '当前订单状态不可确认收货', 'VALIDATION_ERROR', 400);
    const now = new Date().toISOString();
    run('UPDATE orders SET status = ?, receive_time = ? WHERE order_number = ?',
      [ORDER_STATUS.COMPLETED, now, req.params.orderNumber]);
    addMessage(run, req.username, req.params.orderNumber, 'order', '订单已完成', '您已确认收货，感谢您的购买！');
    success(res, { success: true, status: ORDER_STATUS.COMPLETED, receiveTime: now });

    notificationService.notify(req.username, 'order', '订单已完成',
      `订单 ${req.params.orderNumber} 已确认收货，感谢您的购买！`);
  } catch (err) {
    logger.error('receive order error: ' + err.message);
    fail(res, '确认收货失败');
  }
});

router.put('/:orderNumber/refund', async (req, res) => {
  try {
    const { reason } = req.body;
    const { get, run } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?', [req.params.orderNumber, req.username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (![ORDER_STATUS.PENDING_PAYMENT, ORDER_STATUS.PENDING_SHIPPING, ORDER_STATUS.PENDING_RECEIPT].includes(o.status)) {
      return fail(res, '当前订单状态不可申请退款', 'VALIDATION_ERROR', 400);
    }
    run('UPDATE orders SET status = ?, cancel_reason = ? WHERE order_number = ?',
      [ORDER_STATUS.REFUNDING, (reason || o.cancel_reason || ''), req.params.orderNumber]);
    addMessage(run, req.username, req.params.orderNumber, 'order', '退款申请已提交', '您的退款申请已提交，商家将尽快处理');
    success(res, { success: true, status: ORDER_STATUS.REFUNDING });

    notificationService.notify(req.username, 'order', '退款申请已提交',
      `订单 ${req.params.orderNumber} 退款申请已提交，商家将尽快处理`);
  } catch (err) {
    logger.error('refund order error: ' + err.message);
    fail(res, '申请退款失败');
  }
});

router.delete('/:orderNumber', async (req, res) => {
  try {
    const { get, run } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?', [req.params.orderNumber, req.username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (![ORDER_STATUS.COMPLETED, ORDER_STATUS.CANCELLED, ORDER_STATUS.REFUNDED].includes(o.status)) {
      return fail(res, '当前订单状态不可删除', 'VALIDATION_ERROR', 400);
    }
    batch(() => {
      run('DELETE FROM order_items WHERE order_number = ?', [req.params.orderNumber]);
      run('DELETE FROM orders WHERE order_number = ?', [req.params.orderNumber]);
    });
    success(res, { success: true });
  } catch (err) {
    logger.error('delete order error: ' + err.message);
    fail(res, '删除订单失败');
  }
});

module.exports = router;
