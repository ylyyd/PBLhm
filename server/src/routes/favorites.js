const express = require('express');
const { getDb, batch } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const { all } = await getDb();
    const rows = all(`
      SELECT f.product_id
      FROM favorites f
      JOIN products p ON p.id = f.product_id
      WHERE f.username = ?
      ORDER BY f.id DESC
    `, [req.username]);
    success(res, rows.map(r => r.product_id));
  } catch (err) {
    logger.error('get favorites error: ' + err.message);
    fail(res, '获取收藏失败');
  }
});

router.post('/:productId', async (req, res) => {
  try {
    const productId = Number(req.params.productId);
    if (!Number.isInteger(productId) || productId < 1) {
      return fail(res, '商品ID无效', 'VALIDATION_ERROR', 400);
    }
    const { get, run } = await getDb();
    const existing = get('SELECT id FROM favorites WHERE username = ? AND product_id = ?', [req.username, productId]);
    if (existing) {
      run('DELETE FROM favorites WHERE id = ?', [existing.id]);
      success(res, { favorited: false });
    } else {
      run('INSERT INTO favorites (username, product_id) VALUES (?, ?)', [req.username, productId]);
      success(res, { favorited: true });
    }
  } catch (err) {
    logger.error('toggle favorite error: ' + err.message);
    fail(res, '操作收藏失败');
  }
});

router.post('/batch/add', async (req, res) => {
  try {
    const { productIds } = req.body;
    if (!productIds || !Array.isArray(productIds) || productIds.length === 0) {
      return fail(res, '参数错误', 'VALIDATION_ERROR', 400);
    }
    const { run } = await getDb();
    batch(() => {
      for (const pid of productIds) {
        try {
          run('INSERT OR IGNORE INTO favorites (username, product_id) VALUES (?, ?)', [req.username, pid]);
        } catch {}
      }
    });
    success(res, { success: true });
  } catch (err) {
    logger.error('batch add favorites error: ' + err.message);
    fail(res, '批量收藏失败');
  }
});

router.delete('/clear', async (req, res) => {
  try {
    const { run } = await getDb();
    run('DELETE FROM favorites WHERE username = ?', [req.username]);
    success(res, { success: true });
  } catch (err) {
    logger.error('clear favorites error: ' + err.message);
    fail(res, '清空收藏失败');
  }
});

router.get('/check/:productIds', async (req, res) => {
  try {
    const { all } = await getDb();
    const ids = req.params.productIds.split(',').map(Number).filter(n => !isNaN(n));
    if (ids.length === 0) return success(res, { favoritedIds: [] });
    const placeholders = ids.map(() => '?').join(',');
    const rows = all(`SELECT product_id FROM favorites WHERE username = ? AND product_id IN (${placeholders})`, [req.username, ...ids]);
    success(res, { favoritedIds: rows.map(r => r.product_id) });
  } catch (err) {
    logger.error('check favorites error: ' + err.message);
    fail(res, '查询收藏失败');
  }
});

module.exports = router;
