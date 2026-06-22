const express = require('express');
const { getDb } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();

function formatReview(r) {
  let images = [];
  try { images = JSON.parse(r.images || '[]'); } catch {}
  return {
    id: r.id,
    productId: r.product_id,
    username: r.username,
    rating: r.rating,
    date: r.date,
    comment: r.comment,
    images,
    orderNumber: r.order_number || '',
  };
}

router.get('/product/:productId', async (req, res) => {
  try {
    const { all, get } = await getDb();
    const { rating, page, pageSize } = req.query;
    let sql = 'SELECT * FROM reviews WHERE product_id = ? AND is_deleted = 0';
    const params = [req.params.productId];

    if (rating) {
      sql += ' AND rating = ?';
      params.push(Number(rating));
    }

    const { total } = get('SELECT COUNT(*) as total FROM reviews WHERE product_id = ? AND is_deleted = 0', [req.params.productId]);
    const ratingStats = all('SELECT rating, COUNT(*) as count FROM reviews WHERE product_id = ? AND is_deleted = 0 GROUP BY rating', [req.params.productId]);
    const avgRow = get('SELECT AVG(rating) as avg FROM reviews WHERE product_id = ? AND is_deleted = 0', [req.params.productId]);

    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(50, Math.max(1, parseInt(pageSize) || 20));
    sql += ' ORDER BY date DESC LIMIT ? OFFSET ?';
    params.push(ps, (p - 1) * ps);

    const reviews = all(sql, params);
    success(res, {
      items: reviews.map(formatReview),
      total,
      ratingStats: {
        1: 0, 2: 0, 3: 0, 4: 0, 5: 0,
        ...Object.fromEntries(ratingStats.map(r => [r.rating, r.count])),
      },
      average: avgRow.avg ? Math.round(avgRow.avg * 10) / 10 : 0,
    });
  } catch (err) {
    logger.error('get reviews error: ' + err.message);
    fail(res, '获取评价失败');
  }
});

router.post('/product/:productId', authMiddleware, async (req, res) => {
  try {
    const { rating, comment, images, orderNumber } = req.body;
    if (!rating) return fail(res, '请给出评分', 'VALIDATION_ERROR', 400);
    const ratingNum = Number(rating);
    if (!Number.isInteger(ratingNum) || ratingNum < 1 || ratingNum > 5) {
      return fail(res, '评分必须在1-5之间', 'VALIDATION_ERROR', 400);
    }
    const { get, run } = await getDb();
    const purchased = get(
      "SELECT oi.id FROM order_items oi JOIN orders o ON o.order_number = oi.order_number WHERE oi.product_id = ? AND o.username = ? AND o.status = ?",
      [req.params.productId, req.username, '已完成']
    );
    if (!purchased) return fail(res, '请先购买该商品后再评价', 'FORBIDDEN', 403);

    const exists = get('SELECT id FROM reviews WHERE product_id = ? AND username = ? AND order_number = ? AND is_deleted = 0',
      [req.params.productId, req.username, orderNumber || '']);
    if (exists) return fail(res, '您已经评价过该商品', 'CONFLICT', 409);

    const now = new Date();
    const date = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    const imagesJson = JSON.stringify(Array.isArray(images) ? images.slice(0, 9) : []);
    run('INSERT INTO reviews (product_id, username, rating, date, comment, images, order_number, is_deleted) VALUES (?, ?, ?, ?, ?, ?, ?, 0)',
      [req.params.productId, req.username, ratingNum, date, (comment || '').slice(0, 500), imagesJson, orderNumber || '']);
    success(res, { success: true });
  } catch (err) {
    logger.error('submit review error: ' + err.message);
    fail(res, '提交评价失败');
  }
});

router.delete('/product/:productId', authMiddleware, async (req, res) => {
  try {
    const { run } = await getDb();
    const orderNumber = req.query.orderNumber || '';
    if (orderNumber) {
      run('UPDATE reviews SET is_deleted = 1 WHERE product_id = ? AND username = ? AND order_number = ?', [req.params.productId, req.username, orderNumber]);
    } else {
      run('UPDATE reviews SET is_deleted = 1 WHERE product_id = ? AND username = ?', [req.params.productId, req.username]);
    }
    success(res, { success: true });
  } catch (err) {
    logger.error('delete review error: ' + err.message);
    fail(res, '删除评价失败');
  }
});

router.get('/product/:productId/average', async (req, res) => {
  try {
    const { get } = await getDb();
    const row = get('SELECT AVG(rating) as avg FROM reviews WHERE product_id = ? AND is_deleted = 0', [req.params.productId]);
    success(res, { average: row.avg ? Math.round(row.avg * 10) / 10 : 0 });
  } catch (err) {
    logger.error('get average rating error: ' + err.message);
    fail(res, '获取平均评分失败');
  }
});

router.get('/user/:username', authMiddleware, async (req, res) => {
  try {
    const { all, get } = await getDb();
    const { page, pageSize } = req.query;
    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(50, Math.max(1, parseInt(pageSize) || 20));

    const { total } = get('SELECT COUNT(*) as total FROM reviews WHERE username = ? AND is_deleted = 0', [req.params.username]);
    const reviews = all('SELECT * FROM reviews WHERE username = ? AND is_deleted = 0 ORDER BY date DESC LIMIT ? OFFSET ?',
      [req.params.username, ps, (p - 1) * ps]);

    success(res, {
      items: reviews.map(formatReview),
      total,
      page: p,
      pageSize: ps,
      totalPages: Math.ceil(total / ps),
    });
  } catch (err) {
    logger.error('get user reviews error: ' + err.message);
    fail(res, '获取用户评价失败');
  }
});

router.get('/user/:username/history', authMiddleware, async (req, res) => {
  try {
    const { all } = await getDb();
    const reviews = all('SELECT product_id, order_number FROM reviews WHERE username = ?', [req.username]);
    success(res, reviews.map(r => ({
      productId: r.product_id,
      orderNumber: r.order_number || ''
    })));
  } catch (err) {
    logger.error('get review history error: ' + err.message);
    fail(res, '获取评价历史失败');
  }
});

module.exports = router;
