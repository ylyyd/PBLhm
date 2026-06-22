const express = require('express');
const { getDb, batch } = require('../db');
const { authMiddleware, adminOnly } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');
const { AFTER_SALE_STATUS } = require('../constants');

const router = express.Router();
router.use(authMiddleware);

router.post('/', async (req, res) => {
  try {
    const { orderNumber, productId, type, reason, refundAmount, imageEvidence } = req.body;
    if (!orderNumber || typeof orderNumber !== 'string') return fail(res, '订单号无效', 'VALIDATION_ERROR', 400);
    if (!type || !['refund', 'exchange', 'return'].includes(type)) return fail(res, '售后类型无效 (refund/exchange/return)', 'VALIDATION_ERROR', 400);
    if (reason !== undefined && (typeof reason !== 'string' || reason.length > 500)) return fail(res, '原因不能超过500字', 'VALIDATION_ERROR', 400);

    const { get, run } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?', [orderNumber, req.username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (!['待发货', '待收货', '已完成'].includes(o.status)) {
      return fail(res, '当前订单状态不可申请售后', 'VALIDATION_ERROR', 400);
    }

    const existing = get("SELECT id FROM after_sales WHERE order_number = ? AND product_id = ? AND status IN (?,?)",
      [orderNumber, productId || 0, AFTER_SALE_STATUS.PENDING, AFTER_SALE_STATUS.PROCESSING]);
    if (existing) return fail(res, '已有进行中的售后申请', 'CONFLICT', 400);

    const now = new Date().toISOString();
    batch(() => {
      run('INSERT INTO after_sales (order_number, username, product_id, type, reason, image_evidence, status, apply_time, refund_amount, order_status) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [orderNumber, req.username, productId || 0, type || 'refund', reason || '', imageEvidence || '', AFTER_SALE_STATUS.PENDING, now, refundAmount || o.total_price, o.status]);
      run("UPDATE orders SET status = ? WHERE order_number = ?", ['退款中', orderNumber]);
    });

    success(res, { message: '售后申请已提交' });
  } catch (err) {
    logger.error('create after-sales error: ' + err.message);
    fail(res, '提交售后申请失败');
  }
});

router.get('/', async (req, res) => {
  try {
    const { all } = await getDb();
    const items = all(`
      SELECT a.*, o.status AS current_order_status
      FROM after_sales a
      LEFT JOIN orders o ON a.order_number = o.order_number
      WHERE a.username = ?
      ORDER BY a.apply_time DESC
    `, [req.username]);
    success(res, items);
  } catch (err) {
    logger.error('get after-sales error: ' + err.message);
    fail(res, '获取售后记录失败');
  }
});

router.get('/:orderNumber', async (req, res) => {
  try {
    const { all } = await getDb();
    const items = all(`
      SELECT a.*, o.status AS current_order_status
      FROM after_sales a
      LEFT JOIN orders o ON a.order_number = o.order_number
      WHERE a.order_number = ? AND a.username = ?
      ORDER BY a.apply_time DESC
    `, [req.params.orderNumber, req.username]);
    if (items.length === 0) return fail(res, '售后记录不存在', 'NOT_FOUND', 404);
    success(res, items[0]);
  } catch (err) {
    logger.error('get after-sales detail error: ' + err.message);
    fail(res, '获取售后详情失败');
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { get, run } = await getDb();
    const item = get('SELECT * FROM after_sales WHERE id = ? AND username = ?', [req.params.id, req.username]);
    if (!item) return fail(res, '售后记录不存在', 'NOT_FOUND', 404);
    batch(() => {
      run('DELETE FROM after_sales WHERE id = ?', [req.params.id]);
      // 只有待处理状态的取消才恢复订单状态
      if (item.status === AFTER_SALE_STATUS.PENDING) {
        run("UPDATE orders SET status = ? WHERE order_number = ?", [item.order_status || '待收货', item.order_number]);
      }
    });
    success(res, { success: true });
  } catch (err) {
    logger.error('delete after-sales error: ' + err.message);
    fail(res, '删除售后记录失败');
  }
});

router.put('/:id/process', adminOnly, async (req, res) => {
  try {
    const { status, processNote } = req.body;
    if (!status || !['approved', 'rejected'].includes(status)) {
      return fail(res, '无效的处理状态 (approved/rejected)', 'VALIDATION_ERROR', 400);
    }
    const { get, all, run } = await getDb();
    const item = get('SELECT * FROM after_sales WHERE id = ?', [req.params.id]);
    if (!item) return fail(res, '售后记录不存在', 'NOT_FOUND', 404);

    const now = new Date().toISOString();
    batch(() => {
      run('UPDATE after_sales SET status = ?, process_time = ?, process_note = ? WHERE id = ?',
        [status, now, processNote || '', req.params.id]);
      if (status === 'approved') {
        run("UPDATE orders SET status = ? WHERE order_number = ?", ['已退款', item.order_number]);
        const items = all('SELECT product_id, quantity FROM order_items WHERE order_number = ?', [item.order_number]);
        for (const oi of items) {
          run('UPDATE products SET stock = stock + ? WHERE id = ?', [oi.quantity, oi.product_id]);
        }
      } else if (status === 'rejected') {
        run("UPDATE orders SET status = ? WHERE order_number = ?", [item.order_status || '待收货', item.order_number]);
      }
    });
    success(res, { success: true });
  } catch (err) {
    logger.error('process after-sales error: ' + err.message);
    fail(res, '处理售后失败');
  }
});

module.exports = router;
