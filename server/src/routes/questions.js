const express = require('express');
const { getDb } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();

router.get('/product/:productId', async (req, res) => {
  try {
    const { all } = await getDb();
    const { page, pageSize } = req.query;
    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(50, Math.max(1, parseInt(pageSize) || 20));

    const { get } = await getDb();
    const { total } = get('SELECT COUNT(*) as total FROM product_questions WHERE product_id = ?', [req.params.productId]);

    const questions = all('SELECT * FROM product_questions WHERE product_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [req.params.productId, ps, (p - 1) * ps]);

    success(res, {
      items: questions.map(q => ({
        id: q.id,
        productId: q.product_id,
        username: q.username,
        content: q.content,
        reply: q.reply || '',
        replyTime: q.reply_time || '',
        createdAt: q.created_at || '',
      })),
      total,
      page: p,
      pageSize: ps,
      totalPages: Math.ceil(total / ps),
    });
  } catch (err) {
    logger.error('get questions error: ' + err.message);
    fail(res, '获取问答失败');
  }
});

router.post('/product/:productId', authMiddleware, async (req, res) => {
  try {
    const { content } = req.body;
    if (!content || !content.trim()) return fail(res, '请输入问题内容', 'VALIDATION_ERROR', 400);
    if (content.length > 500) return fail(res, '问题内容不能超过500字', 'VALIDATION_ERROR', 400);

    const { run, get } = await getDb();
    const product = get('SELECT id FROM products WHERE id = ?', [req.params.productId]);
    if (!product) return fail(res, '商品不存在', 'NOT_FOUND', 404);

    run('INSERT INTO product_questions (product_id, username, content) VALUES (?, ?, ?)',
      [req.params.productId, req.username, content.trim()]);
    success(res, { success: true });
  } catch (err) {
    logger.error('post question error: ' + err.message);
    fail(res, '提交问题失败');
  }
});

router.post('/:id/reply', authMiddleware, async (req, res) => {
  try {
    const { reply } = req.body;
    if (!reply || !reply.trim()) return fail(res, '请输入回复内容', 'VALIDATION_ERROR', 400);
    if (req.username !== 'admin') return fail(res, '无权回复', 'FORBIDDEN', 403);

    const { run, get } = await getDb();
    const question = get('SELECT * FROM product_questions WHERE id = ?', [req.params.id]);
    if (!question) return fail(res, '问题不存在', 'NOT_FOUND', 404);

    const now = new Date().toISOString();
    run('UPDATE product_questions SET reply = ?, reply_time = ? WHERE id = ?', [reply.trim(), now, req.params.id]);
    success(res, { success: true });
  } catch (err) {
    logger.error('reply question error: ' + err.message);
    fail(res, '回复失败');
  }
});

module.exports = router;
