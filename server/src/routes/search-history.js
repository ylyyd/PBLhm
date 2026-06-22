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
    const items = all("SELECT DISTINCT keyword, MAX(created_at) as last_searched FROM search_history WHERE username = ? GROUP BY keyword ORDER BY last_searched DESC LIMIT 20", [req.username]);
    success(res, items.map(i => i.keyword));
  } catch (err) {
    logger.error('get search history error: ' + err.message);
    fail(res, '获取搜索历史失败');
  }
});

router.post('/', async (req, res) => {
  try {
    const { keyword } = req.body;
    if (!keyword || !keyword.trim()) return fail(res, '关键词不能为空', 'VALIDATION_ERROR', 400);
    const { run } = await getDb();
    run("INSERT INTO search_history (username, keyword) VALUES (?, ?)", [req.username, keyword.trim()]);
    success(res, { success: true });
  } catch (err) {
    logger.error('save search history error: ' + err.message);
    fail(res, '保存搜索历史失败');
  }
});

router.delete('/', async (req, res) => {
  try {
    const { run } = await getDb();
    run('DELETE FROM search_history WHERE username = ?', [req.username]);
    success(res, { success: true });
  } catch (err) {
    logger.error('clear search history error: ' + err.message);
    fail(res, '清空搜索历史失败');
  }
});

module.exports = router;
