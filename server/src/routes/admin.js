const express = require('express');
const { getDb, batch } = require('../db');
const { authMiddleware, adminOnly } = require('../middleware/auth');
const { success, fail, paginated } = require('../response');
const logger = require('../logger');
const { getDashboardStats } = require('../services/statsService');

const router = express.Router();
router.use(authMiddleware);
router.use(adminOnly);

function addMessage(run, username, orderNumber, type, title, content) {
  const now = new Date().toISOString();
  try {
    run('INSERT INTO messages (username, order_number, type, title, content, is_read, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)',
      [username, orderNumber, type, title, content, now]);
  } catch (e) {
    logger.error('addMessage error: ' + e.message);
  }
}

function logAudit(run, username, action, targetType, targetId, detail, ip) {
  try {
    run('INSERT INTO admin_audit_log (username, action, target_type, target_id, detail, ip) VALUES (?, ?, ?, ?, ?, ?)',
      [username, action, targetType, targetId || '', detail || '', ip || '']);
  } catch (e) {
    logger.error('logAudit error: ' + e.message);
  }
}

router.get('/dashboard', async (req, res) => {
  try {
    const stats = await getDashboardStats();
    success(res, stats);
  } catch (err) {
    logger.error('admin dashboard error: ' + err.message);
    fail(res, '获取数据失败');
  }
});

router.get('/products', async (req, res) => {
  try {
    const { page, pageSize, keyword } = req.query;
    const { all, get: getRow } = await getDb();
    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(100, Math.max(1, parseInt(pageSize) || 20));

    let sql = 'SELECT p.*, COALESCE(s.name, ?) as shop_name FROM products p LEFT JOIN shops s ON s.id = p.shop_id WHERE 1=1';
    let countSql = 'SELECT COUNT(*) as total FROM products p WHERE 1=1';
    const params = ['自营'];
    const countParams = [];

    if (keyword && keyword.trim()) {
      const kw = `%${keyword.trim()}%`;
      sql += ' AND (p.name LIKE ? OR p.category LIKE ?)';
      countSql += ' AND (p.name LIKE ? OR p.category LIKE ?)';
      params.push(kw, kw);
      countParams.push(kw, kw);
    }

    const { total } = getRow(countSql, countParams) || { total: 0 };
    sql += ' ORDER BY p.id DESC LIMIT ? OFFSET ?';
    params.push(ps, (p - 1) * ps);

    const products = all(sql, params);
    paginated(res, {
      items: products.map(p => {
        try { p.images = JSON.parse(p.images || '[]'); } catch { p.images = []; }
        try { p.specs = JSON.parse(p.specs || '[]'); } catch { p.specs = []; }
        try { p.skus = JSON.parse(p.skus || '[]'); } catch { p.skus = []; }
        return p;
      }),
      total, page: p, pageSize: ps,
    });
  } catch (err) {
    logger.error('admin get products error: ' + err.message);
    fail(res, '获取商品列表失败');
  }
});

router.post('/products', async (req, res) => {
  try {
    const { name, price, image, images, description, detailHtml, category, specs, skus, shopId, stock, videoUrl } = req.body;
    if (!name || price === undefined || price === null) {
      return fail(res, '商品名称和价格不能为空', 'VALIDATION_ERROR', 400);
    }
    const { run, all, get: getRow } = await getDb();
    if (category) {
      const catExists = getRow('SELECT id FROM categories WHERE full_path = ?', [category]);
      if (!catExists) return fail(res, `分类 "${category}" 不存在，请先在分类管理中添加`, 'INVALID_CATEGORY', 400);
    }

    let finalImage = image || '';
    let finalImages = images || [];

    if (!finalImage) {
      const slug = name.replace(/[^a-zA-Z0-9\u4e00-\u9fa5]/g, '').slice(0, 16) || 'product';
      const key = slug + '_' + Date.now();
      finalImage = key + '_1.png';
      try {
        const sharp = require('sharp');
        const path = require('path');
        const fs = require('fs');

        const uploadDir = path.join(__dirname, '..', '..', 'uploads');
        if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

        const svg = `<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
          <defs><linearGradient id="g" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style="stop-color:#2d4059"/>
            <stop offset="100%" style="stop-color:#1a1a2e"/>
          </linearGradient></defs>
          <rect width="400" height="400" fill="url(#g)"/>
          <circle cx="200" cy="160" r="90" fill="rgba(255,255,255,0.08)"/>
          <text x="200" y="175" font-size="80" text-anchor="middle" fill="rgba(255,255,255,0.2)">📦</text>
          <text x="200" y="310" font-size="24" font-family="sans-serif" font-weight="bold" text-anchor="middle" fill="white">${name.length > 12 ? name.slice(0, 12) + '...' : name}</text>
          <text x="200" y="350" font-size="22" font-family="sans-serif" font-weight="bold" text-anchor="middle" fill="#ffd700">¥${price}</text>
        </svg>`;

        await sharp(Buffer.from(svg)).resize(400, 400).png().toFile(path.join(uploadDir, finalImage));
      } catch (genErr) {
        logger.warn('Failed to generate product image: ' + genErr.message);
      }
    }

    run(
      'INSERT INTO products (name, price, image, images, description, detail_html, category, specs, skus, shop_id, stock, video_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [name, price, finalImage, JSON.stringify(finalImages), description || '', detailHtml || '', category || '', JSON.stringify(specs || []), JSON.stringify(skus || []), shopId ?? 0, stock ?? 999, videoUrl ?? '']
    );
    const inserted = all('SELECT id FROM products ORDER BY id DESC LIMIT 1');
    const productId = inserted.length > 0 ? inserted[0].id : null;
    logAudit(run, req.username, 'CREATE', 'product', String(productId), `创建商品: ${name}`);
    success(res, { id: productId, image: finalImage });
  } catch (err) {
    logger.error('admin create product error: ' + err.message);
    fail(res, '添加商品失败');
  }
});

router.put('/products/:id', async (req, res) => {
  try {
    const { name, price, image, images, description, detailHtml, category, specs, skus, shopId, stock, videoUrl, status } = req.body;
    // Validate provided fields
    if (name !== undefined && (typeof name !== 'string' || name.length < 1 || name.length > 200)) {
      return fail(res, '商品名称长度为1-200字', 'VALIDATION_ERROR', 400);
    }
    if (price !== undefined && (isNaN(Number(price)) || Number(price) < 0)) {
      return fail(res, '价格必须是有效正数', 'VALIDATION_ERROR', 400);
    }
    if (stock !== undefined && (!Number.isInteger(Number(stock)) || Number(stock) < 0)) {
      return fail(res, '库存必须是非负整数', 'VALIDATION_ERROR', 400);
    }
    if (status !== undefined && !['active', 'inactive'].includes(status)) {
      return fail(res, '状态值无效 (active/inactive)', 'VALIDATION_ERROR', 400);
    }
    const { run, get } = await getDb();
    if (category) {
      const catExists = get('SELECT id FROM categories WHERE full_path = ?', [category]);
      if (!catExists) return fail(res, `分类 "${category}" 不存在，请先在分类管理中添加`, 'INVALID_CATEGORY', 400);
    }
    const existing = get('SELECT * FROM products WHERE id = ?', [req.params.id]);
    if (!existing) return fail(res, '商品不存在', 'NOT_FOUND', 404);

    // Partial update: only overwrite fields that were actually provided
    const merged = {
      name: name !== undefined ? name : existing.name,
      price: price !== undefined ? price : existing.price,
      image: image !== undefined ? image : existing.image,
      images: images !== undefined ? JSON.stringify(images) : existing.images,
      description: description !== undefined ? description : (existing.description || ''),
      detailHtml: detailHtml !== undefined ? detailHtml : (existing.detail_html || ''),
      category: category !== undefined ? category : (existing.category || ''),
      specs: specs !== undefined ? JSON.stringify(specs) : existing.specs,
      skus: skus !== undefined ? JSON.stringify(skus) : existing.skus,
      shopId: shopId !== undefined ? shopId : existing.shop_id,
      stock: stock !== undefined ? stock : existing.stock,
      videoUrl: videoUrl !== undefined ? videoUrl : (existing.video_url || ''),
      status: status !== undefined ? status : (existing.status || 'active'),
    };

    run(
      'UPDATE products SET name=?, price=?, image=?, images=?, description=?, detail_html=?, category=?, specs=?, skus=?, shop_id=?, stock=?, video_url=?, status=? WHERE id=?',
      [merged.name, merged.price, merged.image, merged.images, merged.description, merged.detailHtml, merged.category, merged.specs, merged.skus, merged.shopId, merged.stock, merged.videoUrl, merged.status, req.params.id]
    );
    logAudit(run, req.username, 'UPDATE', 'product', String(req.params.id), `更新商品: ${merged.name}`);
    success(res, { success: true });
  } catch (err) {
    logger.error('admin update product error: ' + err.message);
    fail(res, '更新商品失败');
  }
});

router.delete('/products/:id', async (req, res) => {
  try {
    const { run, get } = await getDb();
    const existing = get('SELECT name FROM products WHERE id = ?', [req.params.id]);
    const productName = existing ? existing.name : '';
    batch(() => {
      run('DELETE FROM products WHERE id = ?', [req.params.id]);
      run('DELETE FROM cart_items WHERE product_id = ?', [req.params.id]);
      run('DELETE FROM favorites WHERE product_id = ?', [req.params.id]);
      run('UPDATE reviews SET is_deleted = 1 WHERE product_id = ?', [req.params.id]);
    });
    logAudit(run, req.username, 'DELETE', 'product', String(req.params.id), `删除商品: ${productName}`);
    success(res, { success: true });
  } catch (err) {
    logger.error('admin delete product error: ' + err.message);
    fail(res, '删除商品失败');
  }
});

router.get('/orders', async (req, res) => {
  try {
    const { page, pageSize, status, keyword } = req.query;
    const { all, get: getRow } = await getDb();
    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(100, Math.max(1, parseInt(pageSize) || 20));

    let sql = 'SELECT * FROM orders WHERE 1=1';
    let countSql = 'SELECT COUNT(*) as total FROM orders WHERE 1=1';
    const params = [];
    const countParams = [];

    if (status) {
      sql += ' AND status = ?';
      countSql += ' AND status = ?';
      params.push(status);
      countParams.push(status);
    }
    if (keyword && keyword.trim()) {
      const kw = `%${keyword.trim()}%`;
      sql += ' AND (order_number LIKE ? OR username LIKE ?)';
      countSql += ' AND (order_number LIKE ? OR username LIKE ?)';
      params.push(kw, kw);
      countParams.push(kw, kw);
    }

    const { total } = getRow(countSql, countParams) || { total: 0 };
    sql += ' ORDER BY create_time DESC LIMIT ? OFFSET ?';
    params.push(ps, (p - 1) * ps);

    const orders = all(sql, params);
    if (orders.length === 0) return paginated(res, { items: [], total, page: p, pageSize: ps });

    const orderNumbers = orders.map(o => o.order_number);
    const placeholders = orderNumbers.map(() => '?').join(',');
    const allItems = all(`SELECT * FROM order_items WHERE order_number IN (${placeholders})`, orderNumbers);
    const itemsByOrder = {};
    for (const item of allItems) {
      if (!itemsByOrder[item.order_number]) itemsByOrder[item.order_number] = [];
      itemsByOrder[item.order_number].push(item);
    }
    paginated(res, {
      items: orders.map(o => ({ ...o, items: itemsByOrder[o.order_number] || [] })),
      total, page: p, pageSize: ps,
    });
  } catch (err) {
    logger.error('admin get orders error: ' + err.message);
    fail(res, '获取订单列表失败');
  }
});

router.put('/orders/:orderNumber/ship', async (req, res) => {
  try {
    const { tracking_number: trackingNumber, express_company: expressCompany } = req.body;
    if (!trackingNumber || typeof trackingNumber !== 'string' || trackingNumber.length > 100) {
      return fail(res, '快递单号不能为空且不超过100字', 'VALIDATION_ERROR', 400);
    }
    if (!expressCompany || typeof expressCompany !== 'string' || expressCompany.length > 50) {
      return fail(res, '快递公司不能为空且不超过50字', 'VALIDATION_ERROR', 400);
    }
    const { run, get } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ?', [req.params.orderNumber]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    if (o.status !== '待发货') return fail(res, '当前订单状态不可发货', 'VALIDATION_ERROR', 400);
    const now = new Date().toISOString();
    run('UPDATE orders SET status = ?, tracking_number = ?, express_company = ?, ship_time = ?, estimated_delivery = ? WHERE order_number = ?',
      ['配送中', trackingNumber || '', expressCompany || '', now, req.body.estimatedDelivery || '', req.params.orderNumber]);
    addMessage(run, o.username, req.params.orderNumber, 'order', '订单已发货',
      '您的订单已发货' + (expressCompany ? '，快递：' + expressCompany : '') + (trackingNumber ? '，单号：' + trackingNumber : ''));
    logAudit(run, req.username, 'SHIP', 'order', req.params.orderNumber, `发货: ${expressCompany} ${trackingNumber}`);
    success(res, { success: true, status: '配送中' });
  } catch (err) {
    logger.error('admin ship order error: ' + err.message);
    fail(res, '发货失败');
  }
});

router.put('/orders/:orderNumber/status', async (req, res) => {
  try {
    const { status, cancelReason } = req.body;
    const validStatuses = ['待付款', '待发货', '配送中', '待收货', '已完成', '已取消', '退款中', '已退款'];
    if (!status || !validStatuses.includes(status)) {
      return fail(res, '无效的订单状态', 'VALIDATION_ERROR', 400);
    }
    const { run, get } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ?', [req.params.orderNumber]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);
    run('UPDATE orders SET status = ?, cancel_reason = ? WHERE order_number = ?', [status, cancelReason || '', req.params.orderNumber]);
    logAudit(run, req.username, 'UPDATE_STATUS', 'order', req.params.orderNumber, `订单状态变更: ${o.status} → ${status}`);
    success(res, { success: true });
  } catch (err) {
    logger.error('admin update order error: ' + err.message);
    fail(res, '更新订单状态失败');
  }
});

// ── AfterSales ──

router.get('/aftersales', async (req, res) => {
  try {
    const { all } = await getDb();
    const items = all(`
      SELECT a.*, o.status AS current_order_status
      FROM after_sales a
      LEFT JOIN orders o ON a.order_number = o.order_number
      ORDER BY a.apply_time DESC
    `);
    success(res, items);
  } catch (err) {
    logger.error('admin get after-sales error: ' + err.message);
    fail(res, '获取售后记录失败');
  }
});

// ── Category CRUD ──

router.get('/categories', async (req, res) => {
  try {
    const { all } = await getDb();
    const cats = all(`SELECT c.*, (SELECT COUNT(*) FROM products WHERE category = c.full_path OR category LIKE c.full_path || '>%') as product_count FROM categories c ORDER BY c.sort_order, c.id`);
    // Build tree
    const map = {};
    for (const c of cats) map[c.id] = { ...c, children: [] };
    const tree = [];
    for (const c of cats) {
      if (c.parent_id && map[c.parent_id]) {
        map[c.parent_id].children.push(map[c.id]);
      } else {
        tree.push(map[c.id]);
      }
    }
    success(res, { categories: tree, flat: cats });
  } catch (err) {
    logger.error('admin get categories error: ' + err.message);
    fail(res, '获取分类失败');
  }
});

router.post('/categories', async (req, res) => {
  try {
    const { name, parentId, icon } = req.body;
    if (!name || !name.trim()) return fail(res, '分类名称不能为空', 'VALIDATION_ERROR', 400);
    const { run, all } = await getDb();
    const parent = parentId ? all('SELECT * FROM categories WHERE id = ?', [parentId])[0] : null;
    const fullPath = parent ? parent.full_path + '>' + name.trim() : name.trim();
    const level = parent ? parent.level + 1 : 1;
    const maxOrder = all('SELECT MAX(sort_order) as m FROM categories WHERE parent_id = ?', [parentId || 0])[0];
    const sortOrder = (maxOrder?.m ?? -1) + 1;
    run('INSERT INTO categories (name, parent_id, level, full_path, sort_order, icon) VALUES (?, ?, ?, ?, ?, ?)',
      [name.trim(), parentId || 0, level, fullPath, sortOrder, icon || '']);
    logAudit(run, req.username, 'ADD_CATEGORY', 'category', fullPath, `新建分类: ${fullPath}`);
    success(res, { success: true, fullPath });
  } catch (err) {
    logger.error('admin add category error: ' + err.message);
    fail(res, '添加分类失败');
  }
});

router.put('/categories/:id', async (req, res) => {
  try {
    const { name, icon, sortOrder } = req.body;
    const { run, get } = await getDb();
    const cat = get('SELECT * FROM categories WHERE id = ?', [req.params.id]);
    if (!cat) return fail(res, '分类不存在', 'NOT_FOUND', 404);
    if (name && name.trim()) {
      // Update full_path for this category and all children
      const oldName = cat.name;
      const newName = name.trim();
      run('UPDATE categories SET name = ?, full_path = REPLACE(full_path, ?, ?) WHERE id = ?',
        [newName, cat.full_path, cat.full_path.replace(oldName, newName), cat.id]);
      run('UPDATE categories SET full_path = REPLACE(full_path, ?, ?) WHERE parent_id = ?',
        [cat.full_path, cat.full_path.replace(oldName, newName), cat.id]);
      // Update products using this category
      run('UPDATE products SET category = ? WHERE category = ?', [cat.full_path.replace(oldName, newName), cat.full_path]);
      logAudit(run, req.username, 'RENAME_CATEGORY', 'category', cat.full_path, `重命名分类: ${cat.full_path} → ${cat.full_path.replace(oldName, newName)}`);
    }
    if (icon !== undefined) {
      run('UPDATE categories SET icon = ? WHERE id = ?', [icon, cat.id]);
    }
    if (sortOrder !== undefined) {
      run('UPDATE categories SET sort_order = ? WHERE id = ?', [sortOrder, cat.id]);
    }
    success(res, { success: true });
  } catch (err) {
    logger.error('admin update category error: ' + err.message);
    fail(res, '更新分类失败');
  }
});

router.delete('/categories/:id', async (req, res) => {
  try {
    const { run, get } = await getDb();
    const cat = get('SELECT * FROM categories WHERE id = ?', [req.params.id]);
    if (!cat) return fail(res, '分类不存在', 'NOT_FOUND', 404);
    const productCount = get('SELECT COUNT(*) as c FROM products WHERE category = ?', [cat.full_path]);
    if (productCount.c > 0) {
      return fail(res, `该分类下有 ${productCount.c} 个商品，无法删除`, 'HAS_PRODUCTS', 400);
    }
    const childCount = get('SELECT COUNT(*) as c FROM categories WHERE parent_id = ?', [cat.id]);
    if (childCount.c > 0) {
      return fail(res, '该分类下有子分类，请先删除子分类', 'HAS_CHILDREN', 400);
    }
    run('DELETE FROM categories WHERE id = ?', [cat.id]);
    logAudit(run, req.username, 'DELETE_CATEGORY', 'category', cat.full_path, `删除分类: ${cat.full_path}`);
    success(res, { success: true });
  } catch (err) {
    logger.error('admin delete category error: ' + err.message);
    fail(res, '删除分类失败');
  }
});

router.put('/categories/sort', async (req, res) => {
  try {
    const { items } = req.body; // [{id, sortOrder}]
    if (!Array.isArray(items)) return fail(res, '参数错误', 'VALIDATION_ERROR', 400);
    const { run } = await getDb();
    for (const item of items) {
      run('UPDATE categories SET sort_order = ? WHERE id = ?', [item.sortOrder, item.id]);
    }
    success(res, { success: true });
  } catch (err) {
    logger.error('admin sort categories error: ' + err.message);
    fail(res, '排序失败');
  }
});

router.get('/users', async (req, res) => {
  try {
    const { page, pageSize, keyword } = req.query;
    const { all, get: getRow } = await getDb();
    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(100, Math.max(1, parseInt(pageSize) || 20));

    let sql = 'SELECT id, username, nickname, phone, points, member_level, address, created_at, is_admin FROM users WHERE 1=1';
    let countSql = 'SELECT COUNT(*) as total FROM users WHERE 1=1';
    const params = [];
    const countParams = [];

    if (keyword && keyword.trim()) {
      const kw = `%${keyword.trim()}%`;
      sql += ' AND (username LIKE ? OR nickname LIKE ? OR phone LIKE ?)';
      countSql += ' AND (username LIKE ? OR nickname LIKE ? OR phone LIKE ?)';
      params.push(kw, kw, kw);
      countParams.push(kw, kw, kw);
    }

    const { total } = getRow(countSql, countParams) || { total: 0 };
    sql += ' ORDER BY id DESC LIMIT ? OFFSET ?';
    params.push(ps, (p - 1) * ps);

    const users = all(sql, params);
    paginated(res, { items: users, total, page: p, pageSize: ps });
  } catch (err) {
    logger.error('admin get users error: ' + err.message);
    fail(res, '获取用户列表失败');
  }
});

router.get('/stats', async (req, res) => {
  try {
    const { all, get } = await getDb();
    const dailySales = all("SELECT date(create_time) as day, SUM(total_price) as total FROM orders WHERE status = '已完成' GROUP BY date(create_time) ORDER BY day DESC LIMIT 30");
    const categorySales = all("SELECT p.category, COUNT(*) as count FROM order_items oi JOIN products p ON p.id = oi.product_id GROUP BY p.category ORDER BY count DESC");
    const topProducts = all("SELECT p.id, p.name, p.price, p.image, SUM(oi.quantity) as total_sales FROM order_items oi JOIN products p ON p.id = oi.product_id GROUP BY p.id ORDER BY total_sales DESC LIMIT 10");
    success(res, { dailySales, categorySales, topProducts });
  } catch (err) {
    logger.error('admin get stats error: ' + err.message);
    fail(res, '获取统计数据失败');
  }
});

module.exports = router;
