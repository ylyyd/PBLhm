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
    const addresses = all('SELECT * FROM addresses WHERE username = ? ORDER BY is_default DESC, id ASC', [req.username]);
    success(res, addresses.map(a => ({
      id: a.id,
      label: a.label,
      recipientName: a.recipient_name || '',
      phone: a.phone || '',
      detail: a.detail,
      isDefault: !!a.is_default,
    })));
  } catch (err) {
    logger.error('get addresses error: ' + err.message);
    fail(res, '获取地址列表失败');
  }
});

router.post('/', async (req, res) => {
  try {
    const { label, recipientName, phone, detail, isDefault } = req.body;
    if (!label || !detail || !recipientName || !phone) return fail(res, '地址信息不完整', 'VALIDATION_ERROR', 400);
    if (typeof label !== 'string' || label.length < 1 || label.length > 50) return fail(res, '标签长度为1-50字', 'VALIDATION_ERROR', 400);
    if (typeof recipientName !== 'string' || recipientName.length < 1 || recipientName.length > 50) return fail(res, '收货人姓名长度为1-50字', 'VALIDATION_ERROR', 400);
    if (typeof phone !== 'string' || !/^1\d{10}$/.test(phone)) return fail(res, '手机号格式不正确', 'VALIDATION_ERROR', 400);
    if (typeof detail !== 'string' || detail.length < 5 || detail.length > 200) return fail(res, '详细地址长度为5-200字', 'VALIDATION_ERROR', 400);
    const { get, run, all } = await getDb();
    if (isDefault) run('UPDATE addresses SET is_default = 0 WHERE username = ?', [req.username]);
    run('INSERT INTO addresses (username, label, recipient_name, phone, detail, is_default) VALUES (?, ?, ?, ?, ?, ?)',
      [req.username, label, recipientName, phone, detail, isDefault ? 1 : 0]);
    const inserted = all('SELECT id FROM addresses WHERE username = ? ORDER BY id DESC LIMIT 1', [req.username]);
    const count = get('SELECT COUNT(*) as c FROM addresses WHERE username = ?', [req.username]);
    if (count.c === 1 && inserted.length > 0) {
      run('UPDATE addresses SET is_default = 1 WHERE id = ?', [inserted[0].id]);
    }
    success(res, { id: inserted.length > 0 ? inserted[0].id : null });
  } catch (err) {
    logger.error('add address error: ' + err.message);
    fail(res, '添加地址失败');
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { label, recipientName, phone, detail, isDefault } = req.body;
    // Validate at least one field to update
    if (label === undefined && recipientName === undefined && phone === undefined && detail === undefined && isDefault === undefined) {
      return fail(res, '请提供要更新的字段', 'VALIDATION_ERROR', 400);
    }
    if (label !== undefined && (typeof label !== 'string' || label.length < 1 || label.length > 50)) return fail(res, '标签长度为1-50字', 'VALIDATION_ERROR', 400);
    if (recipientName !== undefined && (typeof recipientName !== 'string' || recipientName.length < 1 || recipientName.length > 50)) return fail(res, '收货人姓名长度为1-50字', 'VALIDATION_ERROR', 400);
    if (phone !== undefined && !/^1\d{10}$/.test(phone)) return fail(res, '手机号格式不正确', 'VALIDATION_ERROR', 400);
    if (detail !== undefined && (typeof detail !== 'string' || detail.length < 5 || detail.length > 200)) return fail(res, '详细地址长度为5-200字', 'VALIDATION_ERROR', 400);
    const { get, run } = await getDb();
    const addr = get('SELECT * FROM addresses WHERE id = ? AND username = ?', [req.params.id, req.username]);
    if (!addr) return fail(res, '地址不存在', 'NOT_FOUND', 404);
    if (isDefault) run('UPDATE addresses SET is_default = 0 WHERE username = ?', [req.username]);
    run('UPDATE addresses SET label = ?, recipient_name = ?, phone = ?, detail = ?, is_default = ? WHERE id = ?',
      [label || addr.label, recipientName || addr.recipient_name, phone || addr.phone, detail || addr.detail, isDefault ? 1 : addr.is_default, req.params.id]);
    success(res, { success: true });
  } catch (err) {
    logger.error('update address error: ' + err.message);
    fail(res, '更新地址失败');
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { get, run } = await getDb();
    const addr = get('SELECT * FROM addresses WHERE id = ? AND username = ?', [req.params.id, req.username]);
    if (!addr) return fail(res, '地址不存在', 'NOT_FOUND', 404);
    run('DELETE FROM addresses WHERE id = ?', [req.params.id]);
    const remaining = get('SELECT COUNT(*) as c FROM addresses WHERE username = ?', [req.username]);
    if (remaining.c > 0) {
      const hasDefault = get('SELECT id FROM addresses WHERE username = ? AND is_default = 1', [req.username]);
      if (!hasDefault) {
        const first = get('SELECT id FROM addresses WHERE username = ? ORDER BY id ASC', [req.username]);
        if (first) run('UPDATE addresses SET is_default = 1 WHERE id = ?', [first.id]);
      }
    }
    success(res, { success: true });
  } catch (err) {
    logger.error('delete address error: ' + err.message);
    fail(res, '删除地址失败');
  }
});

router.put('/:id/default', async (req, res) => {
  try {
    const { get, run } = await getDb();
    const addr = get('SELECT * FROM addresses WHERE id = ? AND username = ?', [req.params.id, req.username]);
    if (!addr) return fail(res, '地址不存在', 'NOT_FOUND', 404);
    run('UPDATE addresses SET is_default = 0 WHERE username = ?', [req.username]);
    run('UPDATE addresses SET is_default = 1 WHERE id = ?', [req.params.id]);
    success(res, { success: true });
  } catch (err) {
    logger.error('set default address error: ' + err.message);
    fail(res, '设置默认地址失败');
  }
});

module.exports = router;
