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
    const items = all(`
      SELECT bh.product_id, p.name, p.price, p.image, p.category, MAX(bh.created_at) as last_viewed
      FROM browsing_history bh
      JOIN products p ON p.id = bh.product_id
      WHERE bh.username = ?
      GROUP BY bh.product_id
      ORDER BY last_viewed DESC
      LIMIT 50
    `, [req.username]);
    success(res, items.map(i => ({
      productId: i.product_id,
      name: i.name,
      price: i.price,
      image: i.image,
      category: i.category,
      lastViewed: i.last_viewed || '',
    })));
  } catch (err) {
    logger.error('get browsing history error: ' + err.message);
    fail(res, '获取浏览历史失败');
  }
});

router.post('/', async (req, res) => {
  try {
    const { productId } = req.body;
    if (!productId) return fail(res, '商品ID不能为空', 'VALIDATION_ERROR', 400);
    const { run, get } = await getDb();
    const product = get('SELECT id FROM products WHERE id = ?', [productId]);
    if (!product) return fail(res, '商品不存在', 'NOT_FOUND', 404);
    run('INSERT INTO browsing_history (username, product_id) VALUES (?, ?)', [req.username, productId]);
    success(res, { success: true });
  } catch (err) {
    logger.error('save browsing history error: ' + err.message);
    fail(res, '保存浏览记录失败');
  }
});

router.delete('/', async (req, res) => {
  try {
    const { run } = await getDb();
    run('DELETE FROM browsing_history WHERE username = ?', [req.username]);
    success(res, { success: true });
  } catch (err) {
    logger.error('clear browsing history error: ' + err.message);
    fail(res, '清空浏览历史失败');
  }
});

module.exports = router;
