const express = require('express');
const bcrypt = require('bcryptjs');
const { getDb } = require('../db');
const { authMiddleware, generateToken, generateAccessToken, generateRefreshToken, JWT_SECRET } = require('../middleware/auth');
const { requireFields, validateFields, minLength } = require('../middleware/validate');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();

router.post('/register',
  requireFields('username', 'password'),
  validateFields({ username: [minLength(2)], password: [minLength(6)] }),
  async (req, res) => {
    try {
      const { username, password, nickname, phone, address } = req.body;
      const { get, run } = await getDb();

      if (!/^[a-zA-Z0-9_\u4e00-\u9fa5]{2,20}$/.test(username)) {
        return fail(res, '用户名只能包含字母、数字、下划线和中文，长度2-20', 'VALIDATION_ERROR', 400);
      }
      if (!/^(?=.*[a-zA-Z])(?=.*\d).{6,20}$/.test(password)) {
        return fail(res, '密码必须包含字母和数字，长度6-20', 'VALIDATION_ERROR', 400);
      }

      const exists = get('SELECT id FROM users WHERE username = ?', [username]);
      if (exists) return fail(res, '用户名已存在', 'CONFLICT', 409);

      const hash = await bcrypt.hash(password, 10);
      run('INSERT INTO users (username, password_hash, nickname, phone, address) VALUES (?, ?, ?, ?, ?)',
        [username, hash, nickname || username, phone || '', address || '']);
      const token = generateAccessToken(username);
      const refreshToken = generateRefreshToken(username);
      success(res, { token, refreshToken, username, nickname: nickname || username });
    } catch (err) {
      logger.error('register error: ' + err.message);
      fail(res, '注册失败');
    }
  }
);

router.post('/login', requireFields('username', 'password'), async (req, res) => {
  try {
    const { username, password } = req.body;
    const { get } = await getDb();
    const user = get('SELECT * FROM users WHERE username = ?', [username]);
    if (!user) return fail(res, '用户不存在', 'NOT_FOUND', 401);
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return fail(res, '密码错误', 'UNAUTHORIZED', 401);
    const token = generateAccessToken(username);
    const refreshToken = generateRefreshToken(username);
    success(res, {
      token,
      refreshToken,
      username,
      nickname: user.nickname || '',
      avatar: user.avatar || '',
      points: user.points || 0,
      memberLevel: user.member_level || 0,
      isAdmin: user.is_admin === 1,
    });
  } catch (err) {
    logger.error('login error: ' + err.message);
    fail(res, '登录失败');
  }
});

router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const { get } = await getDb();
    const user = get('SELECT username, nickname, avatar, phone, address, points, member_level, created_at, gender, age, is_admin FROM users WHERE username = ?', [req.username]);
    if (!user) return fail(res, '用户不存在', 'NOT_FOUND', 404);
    success(res, {
      username: user.username,
      nickname: user.nickname || '',
      avatar: user.avatar || '',
      phone: user.phone || '',
      address: user.address || '',
      points: user.points || 0,
      memberLevel: user.member_level || 0,
      createdAt: user.created_at || '',
      gender: user.gender || '保密',
      age: user.age || 0,
      isAdmin: user.is_admin === 1,
    });
  } catch (err) {
    logger.error('get profile error: ' + err.message);
    fail(res, '获取用户信息失败');
  }
});

router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const { nickname, avatar, phone, address, gender, age, password, oldPassword } = req.body;
    const { get, run } = await getDb();
    const user = get('SELECT * FROM users WHERE username = ?', [req.username]);
    if (!user) return fail(res, '用户不存在', 'NOT_FOUND', 404);

    if (password) {
      if (!oldPassword) return fail(res, '请输入当前密码', 'VALIDATION_ERROR', 400);
      if (password.length < 6) return fail(res, '新密码长度不能少于6位', 'VALIDATION_ERROR', 400);
      if (!/^(?=.*[a-zA-Z])(?=.*\d).{6,20}$/.test(password)) {
        return fail(res, '密码必须包含字母和数字', 'VALIDATION_ERROR', 400);
      }
      const ok = await bcrypt.compare(oldPassword, user.password_hash);
      if (!ok) return fail(res, '当前密码错误', 'UNAUTHORIZED', 401);
      const hash = await bcrypt.hash(password, 10);
      run('UPDATE users SET password_hash = ?, nickname = ?, avatar = ?, phone = ?, address = ?, gender = ?, age = ? WHERE username = ?',
        [hash, nickname || user.nickname, avatar || user.avatar, phone || user.phone, address || user.address,
         gender !== undefined ? gender : user.gender, age !== undefined ? age : user.age, req.username]);
    } else {
      run('UPDATE users SET nickname = ?, avatar = ?, phone = ?, address = ?, gender = ?, age = ? WHERE username = ?',
        [nickname || user.nickname, avatar || user.avatar, phone || user.phone, address || user.address,
         gender !== undefined ? gender : user.gender, age !== undefined ? age : user.age, req.username]);
    }
    success(res, { success: true });
  } catch (err) {
    logger.error('update profile error: ' + err.message);
    fail(res, '更新失败');
  }
});

router.post('/payment-password', authMiddleware, async (req, res) => {
  try {
    const { password } = req.body;
    if (!password || password.length !== 6 || isNaN(Number(password))) {
      return fail(res, '支付密码需为6位数字', 'VALIDATION_ERROR', 400);
    }
    const { get, run } = await getDb();
    const hash = await bcrypt.hash(password, 10);
    run('UPDATE users SET payment_password_hash = ? WHERE username = ?', [hash, req.username]);
    success(res, { success: true });
  } catch (err) {
    logger.error('set payment password error: ' + err.message);
    fail(res, '设置支付密码失败');
  }
});

router.post('/verify-payment-password', authMiddleware, async (req, res) => {
  try {
    const { password } = req.body;
    if (!password) return fail(res, '请输入支付密码', 'VALIDATION_ERROR', 400);
    const { get } = await getDb();
    const user = get('SELECT payment_password_hash FROM users WHERE username = ?', [req.username]);
    if (!user || !user.payment_password_hash) {
      return fail(res, '未设置支付密码', 'NOT_FOUND', 400);
    }
    const ok = await bcrypt.compare(password, user.payment_password_hash);
    if (!ok) return fail(res, '支付密码错误', 'UNAUTHORIZED', 401);
    success(res, { success: true });
  } catch (err) {
    logger.error('verify payment password error: ' + err.message);
    fail(res, '验证支付密码失败');
  }
});

router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken || typeof refreshToken !== 'string') {
      return fail(res, '缺少 refreshToken', 'VALIDATION_ERROR', 400);
    }
    const jwt = require('jsonwebtoken');
    let decoded;
    try {
      decoded = jwt.verify(refreshToken, JWT_SECRET);
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return fail(res, 'refreshToken 已过期，请重新登录', 'TOKEN_EXPIRED', 401);
      }
      return fail(res, '无效的 refreshToken', 'UNAUTHORIZED', 401);
    }
    if (decoded.type !== 'refresh') {
      return fail(res, '无效的 refreshToken', 'UNAUTHORIZED', 401);
    }
    const { get } = await getDb();
    const user = get('SELECT username FROM users WHERE username = ?', [decoded.username]);
    if (!user) return fail(res, '用户不存在', 'NOT_FOUND', 404);

    const newToken = generateAccessToken(decoded.username);
    const newRefreshToken = generateRefreshToken(decoded.username);
    success(res, { token: newToken, refreshToken: newRefreshToken });
  } catch (err) {
    logger.error('refresh token error: ' + err.message);
    fail(res, '刷新token失败');
  }
});

router.get('/payment-password-status', authMiddleware, async (req, res) => {
  try {
    const { get } = await getDb();
    const user = get('SELECT payment_password_hash FROM users WHERE username = ?', [req.username]);
    const exists = !!(user && user.payment_password_hash);
    success(res, { exists });
  } catch (err) {
    logger.error('check payment password status error: ' + err.message);
    fail(res, '检查支付密码状态失败');
  }
});

module.exports = router;
