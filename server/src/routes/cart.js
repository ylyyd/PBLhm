const express = require('express');
const { getDb, batch } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const { all } = await getDb();
    const items = all(`
      SELECT ci.*, p.name as product_name, p.price as product_price, p.image as product_image, p.skus, p.stock
      FROM cart_items ci
      JOIN products p ON p.id = ci.product_id
      WHERE ci.username = ?
      ORDER BY ci.id DESC
    `, [req.username]);
    success(res, items.map(i => {
      let finalPrice = i.product_price;
      let finalImage = i.product_image;
      let finalStock = i.stock || 0;
      if (i.sku_id) {
        try {
          const skus = JSON.parse(i.skus || '[]');
          const matched = skus.find(s => s.id === i.sku_id);
          if (matched) {
            finalPrice = matched.price || finalPrice;
            finalImage = matched.image || finalImage;
            finalStock = matched.stock || 0;
          }
        } catch {}
      }
      return {
        id: i.id,
        productId: i.product_id,
        productName: i.product_name,
        productPrice: finalPrice,
        productImage: finalImage,
        quantity: i.quantity,
        skuId: i.sku_id || '',
        skuDesc: i.sku_desc || '',
        selected: !!i.selected,
        stock: finalStock,
      };
    }));
  } catch (err) {
    logger.error('get cart error: ' + err.message);
    fail(res, '获取购物车失败');
  }
});

router.post('/', async (req, res) => {
  try {
    const { productId, quantity, skuId } = req.body;
    if (!productId || !Number.isInteger(Number(productId))) {
      return fail(res, '商品ID无效', 'VALIDATION_ERROR', 400);
    }
    if (quantity !== undefined && quantity !== null) {
      if (!Number.isInteger(Number(quantity)) || Number(quantity) < 1 || Number(quantity) > 999) {
        return fail(res, '数量必须是1-999的整数', 'VALIDATION_ERROR', 400);
      }
    }
    const qty = Math.max(1, Math.floor(Number(quantity) || 1));
    const { get, run } = await getDb();
    const product = get('SELECT id, price, name, image, skus, stock, status FROM products WHERE id = ?', [productId]);
    if (!product) return fail(res, '商品不存在', 'NOT_FOUND', 404);
    if (product.status !== 'active') return fail(res, '商品已下架', 'FORBIDDEN', 403);

    let finalSkuId = skuId || '';
    let finalSkuDesc = '';
    let availStock = product.stock || 0;

    if (finalSkuId) {
      const skus = JSON.parse(product.skus || '[]');
      const matched = skus.find(s => s.id === finalSkuId);
      if (matched) {
        finalSkuDesc = Object.values(matched.specs || {}).join(', ');
        availStock = matched.stock || 0;
      }
    }

    const existing = get('SELECT * FROM cart_items WHERE username = ? AND product_id = ? AND sku_id = ?',
      [req.username, productId, finalSkuId]);
    const inCart = existing ? existing.quantity : 0;
    if (availStock < inCart + qty) {
      return fail(res, '库存不足', 'INSUFFICIENT_STOCK', 400);
    }

    if (existing) {
      run('UPDATE cart_items SET quantity = quantity + ? WHERE username = ? AND product_id = ? AND sku_id = ?',
        [qty, req.username, productId, finalSkuId]);
    } else {
      run('INSERT INTO cart_items (username, product_id, quantity, sku_id, sku_desc) VALUES (?, ?, ?, ?, ?)',
        [req.username, productId, qty, finalSkuId, finalSkuDesc]);
    }
    success(res, { success: true });
  } catch (err) {
    logger.error('add to cart error: ' + err.message);
    fail(res, '添加购物车失败');
  }
});

router.put('/:productId', async (req, res) => {
  try {
    const { quantity, skuId, selected } = req.body;
    const { get, run } = await getDb();

    // Validate at least one updatable field
    if (quantity === undefined && selected === undefined) {
      return fail(res, '请提供要更新的字段 (quantity 或 selected)', 'VALIDATION_ERROR', 400);
    }

    const existing = get('SELECT * FROM cart_items WHERE username = ? AND product_id = ? AND sku_id = ?',
      [req.username, req.params.productId, skuId || '']);
    if (!existing) return fail(res, '购物车商品不存在', 'NOT_FOUND', 404);

    if (quantity !== undefined) {
      if (!Number.isInteger(Number(quantity)) || Number(quantity) < 1 || Number(quantity) > 999) {
        return fail(res, '数量必须是1-999的整数', 'VALIDATION_ERROR', 400);
      }
      const qty = Math.max(1, Math.floor(Number(quantity) || 1));
      const product = get('SELECT skus, stock FROM products WHERE id = ?', [req.params.productId]);
      let availStock = product ? product.stock : 0;
      if (skuId && product) {
        try {
          const skus = JSON.parse(product.skus || '[]');
          const matched = skus.find(s => s.id === skuId);
          if (matched) availStock = matched.stock || 0;
        } catch {}
      }
      if (availStock < qty) return fail(res, '库存不足', 'INSUFFICIENT_STOCK', 400);
      run('UPDATE cart_items SET quantity = ? WHERE username = ? AND product_id = ? AND sku_id = ?',
        [qty, req.username, req.params.productId, skuId || '']);
    }

    if (selected !== undefined) {
      if (typeof selected !== 'boolean') {
        return fail(res, 'selected 必须是布尔值', 'VALIDATION_ERROR', 400);
      }
      run('UPDATE cart_items SET selected = ? WHERE username = ? AND product_id = ? AND sku_id = ?',
        [selected ? 1 : 0, req.username, req.params.productId, skuId || '']);
    }

    success(res, { success: true });
  } catch (err) {
    logger.error('update cart error: ' + err.message);
    fail(res, '更新购物车失败');
  }
});

router.put('/select-all', async (req, res) => {
  try {
    const { selected } = req.body;
    if (selected === undefined || selected === null || typeof selected !== 'boolean') {
      return fail(res, 'selected 必须是布尔值', 'VALIDATION_ERROR', 400);
    }
    const { run } = await getDb();
    run('UPDATE cart_items SET selected = ? WHERE username = ?', [selected ? 1 : 0, req.username]);
    success(res, { success: true });
  } catch (err) {
    logger.error('select all cart error: ' + err.message);
    fail(res, '操作失败');
  }
});

router.delete('/batch', async (req, res) => {
  try {
    const { items } = req.body;
    if (!items || !Array.isArray(items) || items.length === 0) {
      return fail(res, '请选择要删除的商品', 'VALIDATION_ERROR', 400);
    }
    const { run } = await getDb();
    batch(() => {
      for (const item of items) {
        run('DELETE FROM cart_items WHERE username = ? AND product_id = ? AND sku_id = ?',
          [req.username, item.productId, item.skuId || '']);
      }
    });
    success(res, { success: true });
  } catch (err) {
    logger.error('batch delete cart error: ' + err.message);
    fail(res, '批量删除失败');
  }
});

router.delete('/:productId', async (req, res) => {
  try {
    const skuId = req.query.skuId || '';
    const { run } = await getDb();
    run('DELETE FROM cart_items WHERE username = ? AND product_id = ? AND sku_id = ?',
      [req.username, req.params.productId, skuId]);
    success(res, { success: true });
  } catch (err) {
    logger.error('delete cart item error: ' + err.message);
    fail(res, '删除购物车商品失败');
  }
});

router.delete('/', async (req, res) => {
  try {
    const { run } = await getDb();
    run('DELETE FROM cart_items WHERE username = ?', [req.username]);
    success(res, { success: true });
  } catch (err) {
    logger.error('clear cart error: ' + err.message);
    fail(res, '清空购物车失败');
  }
});

router.post('/check-prices', async (req, res) => {
  try {
    const { all } = await getDb();
    const items = all(`
      SELECT ci.*, p.name as product_name, p.price as product_price, p.image as product_image, p.skus, p.stock
      FROM cart_items ci
      JOIN products p ON p.id = ci.product_id
      WHERE ci.username = ? AND ci.selected = 1
    `, [req.username]);

    const results = items.map(i => {
      let price = i.product_price;
      let stock = i.stock;
      let valid = true;
      if (i.sku_id) {
        try {
          const skus = JSON.parse(i.skus || '[]');
          const matched = skus.find(s => s.id === i.sku_id);
          if (matched) {
            price = matched.price || price;
            stock = matched.stock || 0;
          }
        } catch {}
      }
      if (stock < i.quantity) valid = false;
      return {
        productId: i.product_id,
        skuId: i.sku_id || '',
        price,
        stock,
        quantity: i.quantity,
        subtotal: price * i.quantity,
        valid,
      };
    });

    const total = results.reduce((sum, r) => sum + (r.valid ? r.subtotal : 0), 0);
    success(res, { items: results, total });
  } catch (err) {
    logger.error('check prices error: ' + err.message);
    fail(res, '校验价格失败');
  }
});

module.exports = router;
