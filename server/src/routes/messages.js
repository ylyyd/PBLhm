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
    const { type, page, pageSize } = req.query;
    let sql = 'SELECT * FROM messages WHERE username = ?';
    const params = [req.username];

    if (type) {
      sql += ' AND type = ?';
      params.push(type);
    }

    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(50, Math.max(1, parseInt(pageSize) || 20));

    const countSql = sql.replace('SELECT *', 'SELECT COUNT(*) as total');
    const { total } = all(countSql, params)[0];

    sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.push(ps, (p - 1) * ps);

    const messages = all(sql, params);
    success(res, {
      items: messages.map(m => ({
        id: m.id,
        orderNumber: m.order_number || '',
        type: m.type || 'system',
        title: m.title,
        content: m.content || '',
        isRead: !!m.is_read,
        createdAt: m.created_at || '',
      })),
      total,
      page: p,
      pageSize: ps,
      totalPages: Math.ceil(total / ps),
    });
  } catch (err) {
    logger.error('get messages error: ' + err.message);
    fail(res, '获取消息失败');
  }
});

router.get('/unread-count', async (req, res) => {
  try {
    const { get } = await getDb();
    const row = get('SELECT COUNT(*) as count FROM messages WHERE username = ? AND is_read = 0', [req.username]);
    success(res, { count: row.count });
  } catch (err) {
    logger.error('get unread count error: ' + err.message);
    fail(res, '获取未读数失败');
  }
});

router.put('/read-all', async (req, res) => {
  try {
    const { run } = await getDb();
    run('UPDATE messages SET is_read = 1 WHERE username = ? AND is_read = 0', [req.username]);
    success(res, { success: true });
  } catch (err) {
    logger.error('mark all read error: ' + err.message);
    fail(res, '标记全部已读失败');
  }
});

router.put('/:id/read', async (req, res) => {
  try {
    const { run, get } = await getDb();
    const msg = get('SELECT * FROM messages WHERE id = ? AND username = ?', [req.params.id, req.username]);
    if (!msg) return fail(res, '消息不存在', 'NOT_FOUND', 404);
    run('UPDATE messages SET is_read = 1 WHERE id = ?', [req.params.id]);
    success(res, { success: true });
  } catch (err) {
    logger.error('mark read error: ' + err.message);
    fail(res, '标记已读失败');
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { run, get } = await getDb();
    const msg = get('SELECT * FROM messages WHERE id = ? AND username = ?', [req.params.id, req.username]);
    if (!msg) return fail(res, '消息不存在', 'NOT_FOUND', 404);
    run('DELETE FROM messages WHERE id = ?', [req.params.id]);
    success(res, { success: true });
  } catch (err) {
    logger.error('delete message error: ' + err.message);
    fail(res, '删除消息失败');
  }
});

module.exports = router;
