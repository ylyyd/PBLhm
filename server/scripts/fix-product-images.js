/**
 * 修复商品图片 — 为没有专属图片集的商品生成正确的占位图
 * 
 * 原理：
 * - 前 10 个种子商品（华为Mate60、iPhone15 等）已有正确专属图片集
 * - ID 11~80 的商品图片张冠李戴（比如"防蓝光眼镜"用着"MateBook"的图）
 * - 本脚本为这些图片不正确的商品生成新的 SVG 占位图（商品名 + 价格）
 * - 更新 DB 中 image 和 images 字段
 * 
 * 用法：node server/scripts/fix-product-images.js
 */

const path = require('path');
const fs = require('fs');
const { getDb } = require('../src/db');

const UPLOAD_DIR = path.join(__dirname, '..', 'uploads');
const SVG_WIDTH = 400;
const SVG_HEIGHT = 400;

// 前10个种子商品的 imageKey → 它们已经有正确的图片集
const SEED_IMAGE_KEYS = ['mate60pro', 'iphone15', 'mi14ultra', 'redmik70',
  'lenovo_xiaoxin', 'macbookair', 'matebookx', 'airpodspro2', 'mitvs75', 'gree_ac'];

// 种子商品 ID → 它应该用的图片 key
const SEED_ID_KEY_MAP = {
  1: 'mate60pro', 2: 'iphone15', 3: 'mi14ultra', 4: 'redmik70',
  5: 'lenovo_xiaoxin', 6: 'macbookair', 7: 'matebookx',
  8: 'airpodspro2', 9: 'mitvs75', 10: 'gree_ac'
};

// 检查一个图片文件名是否属于种子商品
function isSeedImage(filename) {
  if (!filename) return false;
  return SEED_IMAGE_KEYS.some(key => filename.startsWith(key + '_'));
}

// 获取图片的种子 key（如果图片属于某个种子商品）
function getSeedKey(filename) {
  if (!filename) return null;
  for (const key of SEED_IMAGE_KEYS) {
    if (filename.startsWith(key + '_')) return key;
  }
  return null;
}

/**
 * 读取所有商品，返回需要修复的列表
 */
async function getProductsToFix() {
  const db = await getDb();
  const { all } = db;
  const products = all('SELECT id, name, price, category, image, images FROM products ORDER BY id');

  const toFix = [];
  const alreadyCorrect = [];

  for (const p of products) {
    const curImage = (p.image || '').trim();
    const expectedKey = SEED_ID_KEY_MAP[p.id];

    if (expectedKey) {
      // 这是前10个种子商品 → 检查它用的是否是自己的图片
      const actualKey = getSeedKey(curImage);
      if (actualKey === expectedKey) {
        alreadyCorrect.push({ id: p.id, name: p.name, image: curImage, reason: 'seed-correct' });
        continue;
      }
      // 种子商品用了别人的种子图片 → 需要修复
      toFix.push(p);
      continue;
    }

    // 非种子商品（ID 11+）
    // 如果用的是种子图片（eg. matebookx_1.png）→ 错误的，需要修复
    if (isSeedImage(curImage)) {
      toFix.push(p);
      continue;
    }

    // 图片为空或文件不存在 → 需要修复
    if (!curImage || !fs.existsSync(path.join(UPLOAD_DIR, curImage))) {
      toFix.push(p);
      continue;
    }

    // 非种子图片且文件存在 → 已经正确
    alreadyCorrect.push({ id: p.id, name: p.name, image: curImage, reason: 'custom-image' });
  }

  console.log(`\n=== 扫描结果 ===`);
  console.log(`总商品数: ${products.length}`);
  console.log(`已有正确图片: ${alreadyCorrect.length}`);
  console.log(`需要修复: ${toFix.length}`);

  if (alreadyCorrect.length > 0) {
    console.log(`\n--- 已有正确图片的商品 ---`);
    for (const c of alreadyCorrect) {
      console.log(`  [${c.id}] ${c.name} → ${c.image}`);
    }
  }

  if (toFix.length > 0) {
    console.log(`\n--- 需要修复的商品 ---`);
    for (const p of toFix) {
      const cur = (p.image || '(空)').trim();
      console.log(`  [${p.id}] ${p.name} | 当前: ${cur} | 分类: ${p.category || '无'}`);
    }
  }

  return { toFix, db };
}

/**
 * 生成 SVG 占位图并保存到 uploads 目录
 */
async function generateImage(product) {
  const sharp = require('sharp');

  const slug = product.name
    .replace(/[^a-zA-Z0-9\u4e00-\u9fa5]/g, '')
    .slice(0, 16) || 'product';

  const filename = slug + '_' + Date.now() + '_1.png';
  const filepath = path.join(UPLOAD_DIR, filename);

  const nameDisplay = product.name.length > 12
    ? product.name.slice(0, 12) + '...'
    : product.name;

  const svg = `<svg width="${SVG_WIDTH}" height="${SVG_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
    <defs><linearGradient id="g" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#2d4059"/>
      <stop offset="100%" style="stop-color:#1a1a2e"/>
    </linearGradient></defs>
    <rect width="${SVG_WIDTH}" height="${SVG_HEIGHT}" fill="url(#g)"/>
    <circle cx="200" cy="160" r="90" fill="rgba(255,255,255,0.08)"/>
    <text x="200" y="175" font-size="80" text-anchor="middle" fill="rgba(255,255,255,0.2)">📦</text>
    <text x="200" y="310" font-size="24" font-family="sans-serif" font-weight="bold" text-anchor="middle" fill="white">${nameDisplay}</text>
    <text x="200" y="350" font-size="22" font-family="sans-serif" font-weight="bold" text-anchor="middle" fill="#ffd700">¥${product.price}</text>
  </svg>`;

  await sharp(Buffer.from(svg)).resize(SVG_WIDTH, SVG_HEIGHT).png().toFile(filepath);
  return filename;
}

/**
 * 更新 DB 中商品的 image 和 images 字段
 */
function updateProduct(db, id, filename) {
  const { run } = db;
  const imagesJson = JSON.stringify([filename]);
  run('UPDATE products SET image = ?, images = ? WHERE id = ?',
    [filename, imagesJson, id]);
}

async function main() {
  if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  }

  const { toFix, db } = await getProductsToFix();

  if (toFix.length === 0) {
    console.log('\n✅ 所有商品图片都正确，无需修复。');
    return;
  }

  console.log(`\n=== 开始生成图片 ===`);
  let generated = 0;
  let failed = 0;

  for (const product of toFix) {
    try {
      const filename = await generateImage(product);
      updateProduct(db, product.id, filename);
      console.log(`  ✅ [${product.id}] ${product.name} → ${filename}`);
      generated++;
    } catch (err) {
      console.error(`  ❌ [${product.id}] ${product.name} 生成失败: ${err.message}`);
      failed++;
    }
  }

  console.log(`\n=== 完成 ===`);
  console.log(`生成成功: ${generated}`);
  console.log(`生成失败: ${failed}`);

  // 验证确认
  const { all } = db;
  const updated = all('SELECT id, name, image FROM products ORDER BY id');
  const fixCount = updated.filter(p => !isSeedImage(p.image)).length;
  console.log(`\n当前非种子图片的商品数: ${fixCount}（应为 ${toFix.length}）`);
  console.log(`前10个种子商品确认: ${updated.slice(0, 10).map(p => `[${p.id}]${p.image}`).join(', ')}`);
}

main().catch(err => {
  console.error('脚本执行失败:', err);
  process.exit(1);
});
