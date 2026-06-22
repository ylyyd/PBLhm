const express = require('express');
const { getDb } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const { all, get } = await getDb();
    const { page, pageSize } = req.query;
    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(50, Math.max(1, parseInt(pageSize) || 20));

    const { total } = get('SELECT COUNT(*) as total FROM shops') || { total: 0 };
    const shops = all('SELECT * FROM shops ORDER BY id LIMIT ? OFFSET ?', [ps, (p - 1) * ps]);

    success(res, {
      items: shops,
      total,
      page: p,
      pageSize: ps,
      totalPages: Math.ceil(total / ps),
    });
  } catch (err) {
    logger.error('get shops error: ' + err.message);
    fail(res, '获取店铺列表失败');
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { get, all } = await getDb();
    const shop = get('SELECT * FROM shops WHERE id = ?', [req.params.id]);
    if (!shop) return fail(res, '店铺不存在', 'NOT_FOUND', 404);
    const products = all("SELECT id, name, price, image, category FROM products WHERE shop_id = ? AND status = 'active'", [req.params.id]);
    const followerCount = get('SELECT COUNT(*) as count FROM shop_follows WHERE shop_id = ?', [req.params.id]);
    shop.products = products;
    shop.followerCount = followerCount.count || 0;
    success(res, shop);
  } catch (err) {
    logger.error('get shop detail error: ' + err.message);
    fail(res, '获取店铺详情失败');
  }
});

router.post('/register', authMiddleware, async (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name) return fail(res, '店铺名称不能为空', 'VALIDATION_ERROR', 400);
    const { run, get } = await getDb();
    const existing = get('SELECT id FROM shops WHERE owner_username = ?', [req.username]);
    if (existing) return fail(res, '您已拥有店铺，每个用户只能开一个店', 'CONFLICT', 400);
    const now = new Date().toISOString();
    run('INSERT INTO shops (name, description, owner_username, created_at) VALUES (?, ?, ?, ?)',
      [name, description || '', req.username, now]);
    success(res, { success: true });
  } catch (err) {
    logger.error('register shop error: ' + err.message);
    fail(res, '开店失败');
  }
});

module.exports = router;
