const express = require('express');
const { getDb, batch } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();

router.get('/', authMiddleware, async (req, res) => {
  try {
    const { all } = await getDb();
    const now = new Date().toISOString();
    const coupons = all("SELECT * FROM coupons WHERE status = 'active' AND (end_time = '' OR end_time > ?) AND total_count > used_count ORDER BY id", [now]);
    const userCouponIds = all('SELECT coupon_id FROM user_coupons WHERE username = ? AND used = 0', [req.username]).map(r => r.coupon_id);

    success(res, coupons.map(c => {
      const perUserLimit = c.per_user_limit || 1;
      const userUsedCount = all('SELECT COUNT(*) as count FROM user_coupons WHERE username = ? AND coupon_id = ?', [req.username, c.id])[0]?.count || 0;
      return {
        id: c.id,
        name: c.name,
        type: c.type,
        value: c.value,
        minAmount: c.min_amount || 0,
        startTime: c.start_time || '',
        endTime: c.end_time || '',
        perUserLimit,
        userUsedCount,
        canClaim: userUsedCount < perUserLimit && !userCouponIds.includes(c.id),
        remaining: c.total_count - c.used_count,
      };
    }));
  } catch (err) {
    logger.error('get coupons error: ' + err.message);
    fail(res, '获取优惠券列表失败');
  }
});

router.get('/mine', authMiddleware, async (req, res) => {
  try {
    const { all } = await getDb();
    const coupons = all(`
      SELECT uc.*, c.name, c.type, c.value, c.min_amount, c.end_time
      FROM user_coupons uc
      JOIN coupons c ON c.id = uc.coupon_id
      WHERE uc.username = ? AND uc.used = 0
      ORDER BY uc.created_at DESC
    `, [req.username]);

    success(res, coupons.map(c => ({
      id: c.id,
      couponId: c.coupon_id,
      name: c.name,
      type: c.type,
      value: c.value,
      minAmount: c.min_amount || 0,
      endTime: c.end_time || '',
      createdAt: c.created_at || '',
      expired: c.end_time ? new Date(c.end_time) < new Date() : false,
    })));
  } catch (err) {
    logger.error('get my coupons error: ' + err.message);
    fail(res, '获取我的优惠券失败');
  }
});

router.post('/:id/claim', authMiddleware, async (req, res) => {
  try {
    const { get, run, all } = await getDb();
    const coupon = get("SELECT * FROM coupons WHERE id = ? AND status = 'active'", [req.params.id]);
    if (!coupon) return fail(res, '优惠券不存在', 'NOT_FOUND', 404);
    if (coupon.total_count <= coupon.used_count) return fail(res, '优惠券已领完', 'CONFLICT', 400);

    const userCount = all('SELECT COUNT(*) as count FROM user_coupons WHERE username = ? AND coupon_id = ?', [req.username, req.params.id])[0]?.count || 0;
    const limit = coupon.per_user_limit || 1;
    if (userCount >= limit) return fail(res, '您已领过该优惠券', 'CONFLICT', 400);

    batch(() => {
      run('UPDATE coupons SET used_count = used_count + 1 WHERE id = ?', [req.params.id]);
      run('INSERT INTO user_coupons (username, coupon_id) VALUES (?, ?)', [req.username, req.params.id]);
    });

    success(res, { success: true });
  } catch (err) {
    logger.error('claim coupon error: ' + err.message);
    fail(res, '领取优惠券失败');
  }
});

router.get('/available/:totalPrice', authMiddleware, async (req, res) => {
  try {
    const { all } = await getDb();
    const price = Number(req.params.totalPrice) || 0;
    const coupons = all(`
      SELECT c.* FROM user_coupons uc
      JOIN coupons c ON c.id = uc.coupon_id
      WHERE uc.username = ? AND uc.used = 0 AND c.min_amount <= ? AND c.status = 'active' AND (c.end_time = '' OR c.end_time > ?)
      ORDER BY c.value DESC
    `, [req.username, price, new Date().toISOString()]);

    success(res, coupons.map(c => ({
      id: c.id,
      name: c.name,
      type: c.type,
      value: c.value,
      minAmount: c.min_amount || 0,
    })));
  } catch (err) {
    logger.error('get available coupons error: ' + err.message);
    fail(res, '获取可用优惠券失败');
  }
});

module.exports = router;
