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
    const follows = all(`
      SELECT sf.shop_id, s.name, s.description, s.logo, sf.created_at
      FROM shop_follows sf
      JOIN shops s ON s.id = sf.shop_id
      WHERE sf.username = ?
      ORDER BY sf.created_at DESC
    `, [req.username]);
    success(res, follows.map(f => ({
      shopId: f.shop_id,
      name: f.name,
      description: f.description,
      logo: f.logo,
      followedAt: f.created_at || '',
    })));
  } catch (err) {
    logger.error('get followed shops error: ' + err.message);
    fail(res, '获取关注店铺失败');
  }
});

router.post('/:shopId', async (req, res) => {
  try {
    const shopId = Number(req.params.shopId);
    if (!Number.isInteger(shopId) || shopId < 1) {
      return fail(res, '店铺ID无效', 'VALIDATION_ERROR', 400);
    }
    const { get, run } = await getDb();
    const shop = get('SELECT * FROM shops WHERE id = ?', [shopId]);
    if (!shop) return fail(res, '店铺不存在', 'NOT_FOUND', 404);

    const existing = get('SELECT id FROM shop_follows WHERE username = ? AND shop_id = ?', [req.username, shopId]);
    if (existing) {
      run('DELETE FROM shop_follows WHERE id = ?', [existing.id]);
      run('UPDATE shops SET followers = MAX(0, followers - 1) WHERE id = ?', [shopId]);
      success(res, { followed: false });
    } else {
      run('INSERT INTO shop_follows (username, shop_id) VALUES (?, ?)', [req.username, shopId]);
      run('UPDATE shops SET followers = followers + 1 WHERE id = ?', [shopId]);
      success(res, { followed: true });
    }
  } catch (err) {
    logger.error('toggle shop follow error: ' + err.message);
    fail(res, '操作关注失败');
  }
});

router.get('/check/:shopIds', async (req, res) => {
  try {
    const { all } = await getDb();
    const ids = req.params.shopIds.split(',').map(Number).filter(n => !isNaN(n));
    if (ids.length === 0) return success(res, { followedIds: [] });
    const placeholders = ids.map(() => '?').join(',');
    const rows = all(`SELECT shop_id FROM shop_follows WHERE username = ? AND shop_id IN (${placeholders})`, [req.username, ...ids]);
    success(res, { followedIds: rows.map(r => r.shop_id) });
  } catch (err) {
    logger.error('check shop follows error: ' + err.message);
    fail(res, '查询关注失败');
  }
});

module.exports = router;
