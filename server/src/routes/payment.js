const express = require('express');
const { getDb, batch } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');
const bcrypt = require('bcryptjs');

const router = express.Router();

const isDev = (process.env.NODE_ENV || 'development') === 'development';
let alipaySdk = null;
if (!isDev) {
  try {
    if (process.env.ALIPAY_APP_ID && process.env.ALIPAY_APP_ID.length > 10) {
      const { AlipaySdk, AlipayFormData } = require('alipay-sdk');
      alipaySdk = new AlipaySdk({
        appId: process.env.ALIPAY_APP_ID,
        privateKey: (process.env.ALIPAY_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
        alipayPublicKey: (process.env.ALIPAY_PUBLIC_KEY || '').replace(/\\n/g, '\n'),
        gateway: process.env.ALIPAY_GATEWAY || 'https://openapi-sandbox.dl.alipaydev.com/gateway.do',
      });
      logger.info('Alipay SDK initialized');
    }
  } catch (err) {
    logger.warn('Alipay SDK init failed, falling back to mock: ' + err.message);
  }
}

router.post('/page/:orderNumber', authMiddleware, async (req, res) => {
  try {
    const orderNumber = String(req.params.orderNumber || '');
    const username = String(req.username || '');
    if (!orderNumber || !username) return fail(res, '参数错误', 'VALIDATION_ERROR', 400);

    const { get, run } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?', [orderNumber, username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (o.status !== '待付款') return fail(res, '当前订单状态不可支付', 'VALIDATION_ERROR', 400);

    const paymentToken = Math.random().toString(36).substring(2, 18);
    run('UPDATE orders SET payment_token = ? WHERE order_number = ?', [paymentToken, orderNumber]);
    const amount = Number(o.total_price) || 0;

    if (alipaySdk) {
      try {
        const formData = new (require('alipay-sdk').AlipayFormData)();
        formData.setMethod('get');
        const notifyHost = process.env.NOTIFY_HOST || 'http://10.0.2.2:3000';
        formData.addField('notifyUrl', notifyHost + '/api/payment/callback/' + o.order_number);
        formData.addField('bizContent', {
          outTradeNo: o.order_number,
          productCode: 'FAST_INSTANT_TRADE_PAY',
          totalAmount: amount.toFixed(2),
          subject: '开心购物 - ' + o.order_number.slice(-8),
        });
        const result = await alipaySdk.pageExec('alipay.trade.wap.pay', {}, { formData });
        return success(res, { payUrl: result, tradeNo: o.order_number });
      } catch (alipayErr) {
        logger.warn('Alipay SDK exec failed, falling back to mock: ' + alipayErr.message);
      }
    }
    const host = process.env.NOTIFY_HOST || 'http://' + req.get('host');
    const payUrl = host + '/payment/sandbox.html?orderNumber=' + o.order_number + '&amount=' + amount + '&token=' + paymentToken + '&username=' + encodeURIComponent(username);
    success(res, { payUrl, tradeNo: o.order_number, paymentToken });
  } catch (err) {
    logger.error('get payment page error: ' + err.message);
    fail(res, '获取支付页面失败');
  }
});

router.post('/callback/:orderNumber', async (req, res) => {
  try {
    const { get, all, run } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ?', [req.params.orderNumber]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (o.status !== '待付款') return success(res, { status: o.status });

    const reqToken = req.body.token || req.query.token || '';
    if (!reqToken || reqToken !== o.payment_token) {
      return fail(res, '无效的支付凭证', 'FORBIDDEN', 403);
    }

    const paymentPassword = req.body.paymentPassword;
    if (!paymentPassword) return fail(res, '请输入支付密码', 'VALIDATION_ERROR', 400);
    let user = get('SELECT payment_password_hash FROM users WHERE username = ?', [o.username]);
    if (!user || !user.payment_password_hash) {
      return fail(res, '请先设置支付密码', 'VALIDATION_ERROR', 400);
    }
    if (!bcrypt.compareSync(paymentPassword, user.payment_password_hash)) return fail(res, '支付密码错误', 'FORBIDDEN', 403);

    const now = new Date().toISOString();
    const payMethod = req.body.payMethod || '支付宝';

    batch(() => {
      run('UPDATE orders SET status = ?, pay_method = ?, pay_time = ?, payment_token = ? WHERE order_number = ?',
        ['待发货', payMethod, now, '', req.params.orderNumber]);
      const items = all('SELECT product_id, quantity FROM order_items WHERE order_number = ?', [req.params.orderNumber]);
      for (const item of items) {
        run('UPDATE products SET stock = stock - ?, sales_count = sales_count + ? WHERE id = ?', [item.quantity, item.quantity, item.product_id]);
      }
    });

    success(res, { status: '待发货', payMethod });
  } catch (err) {
    logger.error('payment callback error: ' + err.message);
    fail(res, '支付回调处理失败');
  }
});

router.get('/status/:orderNumber', async (req, res) => {
  try {
    const { get } = await getDb();
    const o = get('SELECT status FROM orders WHERE order_number = ?', [req.params.orderNumber]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    success(res, { status: o.status });
  } catch (err) {
    logger.error('get payment status error: ' + err.message);
    fail(res, '查询支付状态失败');
  }
});

router.use(authMiddleware);

router.post('/direct/:orderNumber', async (req, res) => {
  try {
    const { payMethod, paymentPassword } = req.body;
    const { get, all, run } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?', [req.params.orderNumber, req.username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (o.status !== '待付款') return fail(res, '当前订单状态不可支付', 'VALIDATION_ERROR', 400);
    if (!paymentPassword) return fail(res, '请输入支付密码', 'VALIDATION_ERROR', 400);
    const user = get('SELECT payment_password_hash FROM users WHERE username = ?', [req.username]);
    if (!user || !user.payment_password_hash) return fail(res, '请先设置支付密码', 'VALIDATION_ERROR', 400);
    if (!bcrypt.compareSync(paymentPassword, user.payment_password_hash)) return fail(res, '支付密码错误', 'FORBIDDEN', 403);
    const now = new Date().toISOString();
    batch(() => {
      run('UPDATE orders SET status = ?, pay_method = ?, pay_time = ? WHERE order_number = ?',
        ['待发货', payMethod || '支付宝', now, req.params.orderNumber]);
      const items = all('SELECT product_id, quantity FROM order_items WHERE order_number = ?', [req.params.orderNumber]);
      for (const item of items) {
        run('UPDATE products SET stock = stock - ?, sales_count = sales_count + ? WHERE id = ?', [item.quantity, item.quantity, item.product_id]);
      }
    });

    // Add payment success message and notification
    try {
      run('INSERT INTO messages (username, order_number, type, title, content, is_read, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)',
        [req.username, req.params.orderNumber, 'order', '支付成功', '您的订单已支付成功，等待商家发货', now]);
      const notificationService = require('../services/notificationService');
      notificationService.notify(req.username, 'order', '支付成功',
        `订单 ${req.params.orderNumber} 已支付成功，等待商家发货`);
    } catch (notifyErr) {
      logger.warn('Payment notification error: ' + notifyErr.message);
    }

    success(res, { status: '待发货' });
  } catch (err) {
    logger.error('direct pay error: ' + err.message);
    fail(res, '支付处理失败');
  }
});

module.exports = router;
