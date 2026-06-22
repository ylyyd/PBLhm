const express = require('express');
const { getDb } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const { all } = await getDb();
    const invoices = all('SELECT * FROM invoices WHERE username = ? ORDER BY created_at DESC', [req.username]);
    success(res, invoices.map(i => ({
      id: i.id,
      orderNumber: i.order_number,
      type: i.type || 'personal',
      title: i.title || '',
      taxId: i.tax_id || '',
      email: i.email || '',
      amount: i.amount || 0,
      status: i.status || 'pending',
      createdAt: i.created_at || '',
    })));
  } catch (err) {
    logger.error('get invoices error: ' + err.message);
    fail(res, '获取发票列表失败');
  }
});

router.post('/', async (req, res) => {
  try {
    const { orderNumber, type, title, taxId, email } = req.body;
    if (!orderNumber || typeof orderNumber !== 'string') return fail(res, '订单号不能为空', 'VALIDATION_ERROR', 400);
    if (type !== undefined && !['personal', 'company'].includes(type)) return fail(res, '发票类型无效 (personal/company)', 'VALIDATION_ERROR', 400);
    if (title !== undefined && (typeof title !== 'string' || title.length > 100)) return fail(res, '发票抬头不能超过100字', 'VALIDATION_ERROR', 400);
    if (taxId !== undefined && (typeof taxId !== 'string' || taxId.length > 50)) return fail(res, '税号不能超过50字', 'VALIDATION_ERROR', 400);
    if (email !== undefined && (typeof email !== 'string' || email.length > 100)) return fail(res, '邮箱不能超过100字', 'VALIDATION_ERROR', 400);

    const { get, run } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?', [orderNumber, req.username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (o.status !== '已完成') return fail(res, '只有已完成的订单才能申请发票', 'VALIDATION_ERROR', 400);

    const existing = get('SELECT id FROM invoices WHERE order_number = ?', [orderNumber]);
    if (existing) return fail(res, '该订单已申请过发票', 'CONFLICT', 400);

    run('INSERT INTO invoices (username, order_number, type, title, tax_id, email, amount) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [req.username, orderNumber, type || 'personal', title || '', taxId || '', email || '', o.total_price]);
    success(res, { success: true });
  } catch (err) {
    logger.error('create invoice error: ' + err.message);
    fail(res, '申请发票失败');
  }
});

module.exports = router;
