const express = require('express');
const { optionalAuth } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');
const { getDashboardStats } = require('../services/statsService');

const router = express.Router();

router.get('/dashboard', optionalAuth, async (req, res) => {
  try {
    const stats = await getDashboardStats();
    success(res, stats);
  } catch (err) {
    logger.error('stats dashboard error: ' + err.message);
    fail(res, '获取统计数据失败');
  }
});

module.exports = router;
