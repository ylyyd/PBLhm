const express = require('express');
const { getDb } = require('../db');
const { optionalAuth } = require('../middleware/auth');
const { success, fail, paginated } = require('../response');
const logger = require('../logger');

const router = express.Router();

function parseCategoryFilter(category) {
  if (!category || category === '全部') return { sql: '', params: [] };
  const idx = category.indexOf('>');
  if (idx === -1) {
    return { sql: ' AND (p.category = ? OR p.category LIKE ?)', params: [category, category + '>%'] };
  }
  return { sql: ' AND p.category = ?', params: [category] };
}

function parseProduct(p) {
  try { p.images = JSON.parse(p.images || '[]'); } catch { p.images = []; }
  try { p.specs = JSON.parse(p.specs || '[]'); } catch { p.specs = []; }
  try { p.skus = JSON.parse(p.skus || '[]'); } catch { p.skus = []; }
  return p;
}

router.get('/', async (req, res) => {
  try {
    const { keyword, category, sortBy, priceMin, priceMax, page, pageSize } = req.query;
    const { all } = await getDb();

    let sql = `SELECT p.*, COALESCE(s.name, '自营') as shop_name,
      COALESCE(ROUND((SELECT AVG(CAST(rating AS REAL)) FROM reviews WHERE product_id = p.id AND is_deleted = 0), 1), 0) as rating
      FROM products p LEFT JOIN shops s ON s.id = p.shop_id WHERE p.status = 'active'`;
    const params = [];

    const catFilter = parseCategoryFilter(category);
    sql += catFilter.sql;
    params.push(...catFilter.params);

    if (keyword && keyword.trim()) {
      const kw = `%${keyword.trim()}%`;
      sql += ' AND (p.name LIKE ? OR p.category LIKE ? OR p.description LIKE ?)';
      params.push(kw, kw, kw);
    }

    const p = Math.max(1, parseInt(page) || 1);
    const ps = Math.min(50, Math.max(1, parseInt(pageSize) || 20));

    let products = all(sql, params);

    let filtered = products;
    if (priceMin || priceMax) {
      filtered = products.filter(item => {
        let effectivePrice = item.price;
        if (item.skus && item.skus !== '[]') {
          try {
            const skus = JSON.parse(item.skus);
            if (skus.length > 0) {
              const minSkuPrice = Math.min(...skus.map(s => s.price));
              effectivePrice = Math.min(effectivePrice, minSkuPrice);
            }
          } catch {}
        }
        if (priceMin && effectivePrice < Number(priceMin)) return false;
        if (priceMax && effectivePrice > Number(priceMax)) return false;
        return true;
      });
    }

    const filteredTotal = filtered.length;

    if (sortBy === 'price_asc') {
      filtered.sort((a, b) => a.price - b.price);
    } else if (sortBy === 'price_desc') {
      filtered.sort((a, b) => b.price - a.price);
    } else if (sortBy === 'sales') {
      filtered.sort((a, b) => (b.sales_count || 0) - (a.sales_count || 0));
    } else {
      filtered.sort((a, b) => b.id - a.id);
    }

    const paginatedItems = filtered.slice((p - 1) * ps, p * ps);

    paginated(res, {
      items: paginatedItems.map(parseProduct),
      total: filteredTotal,
      page: p,
      pageSize: ps,
    });
  } catch (err) {
    logger.error('get products error: ' + err.message);
    fail(res, '获取商品列表失败');
  }
});

router.get('/categories', async (req, res) => {
  try {
    const { all } = await getDb();
    const parents = all("SELECT c.*, (SELECT COUNT(*) FROM products WHERE category = c.full_path AND status = 'active') as product_count FROM categories c WHERE c.level = 1 ORDER BY c.sort_order, c.id");
    const tree = parents.map(p => ({
      name: p.name,
      icon: p.icon || '',
      productCount: p.product_count,
      children: all("SELECT c.name FROM categories c WHERE c.parent_id = ? AND EXISTS (SELECT 1 FROM products WHERE category = c.full_path AND status = 'active') ORDER BY c.sort_order, c.id", [p.id]).map(c => c.name)
    }));
    success(res, { categories: tree });
  } catch (err) {
    logger.error('get categories error: ' + err.message);
    fail(res, '获取分类失败');
  }
});

router.get('/hot-keywords', async (req, res) => {
  try {
    const { all } = await getDb();
    const keywords = all("SELECT keyword, COUNT(*) as count FROM search_history GROUP BY keyword ORDER BY count DESC LIMIT 10");
    success(res, { keywords: keywords.map(k => k.keyword) });
  } catch (err) {
    logger.error('get hot keywords error: ' + err.message);
    fail(res, '获取热门搜索失败');
  }
});

router.get('/recommendations', async (req, res) => {
  try {
    const { all } = await getDb();
    const products = all(`SELECT p.*, COALESCE(s.name, '自营') as shop_name,
      COALESCE(ROUND((SELECT AVG(CAST(rating AS REAL)) FROM reviews WHERE product_id = p.id AND is_deleted = 0), 1), 0) as rating
      FROM products p LEFT JOIN shops s ON s.id = p.shop_id WHERE p.status = 'active' ORDER BY p.sales_count DESC, p.id DESC LIMIT 10`);
    success(res, { items: products.map(parseProduct) });
  } catch (err) {
    logger.error('get recommendations error: ' + err.message);
    fail(res, '获取推荐失败');
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { get, all, run } = await getDb();
    const product = get("SELECT p.*, COALESCE(s.name, '自营') as shop_name FROM products p LEFT JOIN shops s ON s.id = p.shop_id WHERE p.id = ?", [req.params.id]);
    if (!product) return fail(res, '商品不存在', 'NOT_FOUND', 404);
    parseProduct(product);

    // Increment view count
    run('UPDATE products SET view_count = COALESCE(view_count, 0) + 1 WHERE id = ?', [product.id]);
    product.viewCount = (product.view_count || 0) + 1;

    const related = all("SELECT id, name, price, image FROM products WHERE category = ? AND id != ? AND status = 'active' ORDER BY id DESC LIMIT 6", [product.category, product.id]);
    product.relatedProducts = related;

    const { get: getRow } = await getDb();
    const avgRow = getRow('SELECT AVG(rating) as avg, COUNT(*) as count FROM reviews WHERE product_id = ? AND is_deleted = 0', [product.id]);
    product.rating = avgRow.avg ? Math.round(avgRow.avg * 10) / 10 : 0;
    product.reviewCount = avgRow.count || 0;

    success(res, product);
  } catch (err) {
    logger.error('get product detail error: ' + err.message);
    fail(res, '获取商品详情失败');
  }
});

module.exports = router;
