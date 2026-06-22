/**
 * 最终版：按品类匹配种子图片 + 其他品类生成清爽卡片图
 * 
 * 分配逻辑：
 *   手机→手机图  |  电脑→电脑图  |  家电→家电图  |  配件→配件图
 *   其余品类 → 生成干净的商品卡片图（无 emoji，只有商品名+价格）
 * 
 * 用法：node server/scripts/final-fix-images.js
 */
const path = require('path');
const fs = require('fs');
const UPLOAD_DIR = path.join(__dirname, '..', 'uploads');
const RAWFILE_DIR = path.join(__dirname, '..', '..', 'entry', 'src', 'main', 'resources', 'rawfile');

// ======== 种子图片集（3~4张一组）========
const SEED_SETS = {
  mate60pro:  { images: ['mate60pro_1.png','mate60pro_2.png','mate60pro_3.png','mate60pro_4.png'], category: '手机' },
  iphone15:   { images: ['iphone15_1.png','iphone15_2.png','iphone15_3.png','iphone15_4.png'], category: '手机' },
  mi14ultra:  { images: ['mi14ultra_1.png','mi14ultra_2.png','mi14ultra_3.png','mi14ultra_4.png'], category: '手机' },
  redmik70:   { images: ['redmik70_1.png','redmik70_2.png','redmik70_3.png','redmik70_4.png'], category: '手机' },
  lenovo_xiaoxin: { images: ['lenovo_xiaoxin_1.png','lenovo_xiaoxin_2.png','lenovo_xiaoxin_3.png'], category: '电脑' },
  macbookair: { images: ['macbookair_1.png','macbookair_2.png','macbookair_3.png','macbookair_4.png'], category: '电脑' },
  matebookx:  { images: ['matebookx_1.png','matebookx_2.png','matebookx_3.png','matebookx_4.png'], category: '电脑' },
  airpodspro2:{ images: ['airpodspro2_1.png','airpodspro2_2.png','airpodspro2_3.png','airpodspro2_4.png'], category: '配件' },
  mitvs75:    { images: ['mitvs75_1.png','mitvs75_2.png','mitvs75_3.png','mitvs75_4.png'], category: '家电' },
  gree_ac:    { images: ['gree_ac_1.png','gree_ac_2.png','gree_ac_3.png'], category: '家电' },
};

// 种子图片占位消耗跟踪
const seedUsage = {};
for (const [key, set] of Object.entries(SEED_SETS)) {
  seedUsage[key] = 0;
}

function getSeedImages(key, count) {
  const set = SEED_SETS[key];
  if (!set) return null;
  const imgs = [];
  for (let i = 0; i < count; i++) {
    const idx = (seedUsage[key] % set.images.length);
    imgs.push(set.images[idx]);
    seedUsage[key]++;
  }
  return imgs;
}

// ======== 品类→种子图片映射 ========
function assignSeedImages(product) {
  const cat = product.category || '';
  const needed = 2; // 每商品2张图给轮播

  // 手机类 → 循环用4套手机图
  if (cat.includes('手机')) {
    const phoneSets = ['mate60pro', 'iphone15', 'mi14ultra', 'redmik70'];
    // 按品类区分使用
    if (cat.includes('OPPO') || cat.includes('vivo')) return getSeedImages('mi14ultra', needed);
    if (cat.includes('三星')) return getSeedImages('mate60pro', needed);
    if (cat.includes('荣耀') || cat.includes('小米')) return getSeedImages('redmik70', needed);
    return getSeedImages('iphone15', needed);
  }

  // 电脑类 → 循环用3套电脑图
  if (cat.includes('电脑')) {
    const pcSets = ['lenovo_xiaoxin', 'macbookair', 'matebookx'];
    if (cat.includes('华硕')) return getSeedImages('lenovo_xiaoxin', needed);
    if (cat.includes('戴尔')) return getSeedImages('macbookair', needed);
    if (cat.includes('惠普')) return getSeedImages('matebookx', needed);
    return getSeedImages('matebookx', needed);
  }

  // 家电类 → 用空调/电视图
  if (cat.includes('家电')) {
    if (cat.includes('空调')) return getSeedImages('gree_ac', needed);
    return getSeedImages('mitvs75', needed);
  }

  // 配件类 → 用耳机图 + 手机图混杂
  if (cat.includes('配件')) {
    if (cat.includes('充电器') || cat.includes('数据线')) return getSeedImages('airpodspro2', needed);
    if (cat.includes('充电宝') || cat.includes('手机壳')) return getSeedImages('redmik70', needed);
    if (cat.includes('贴膜')) return getSeedImages('iphone15', needed);
    return getSeedImages('airpodspro2', needed);
  }

  return null; // 无匹配→需要生成
}

// ======== 无匹配品类→生成干净的卡片图（无 emoji）========
const CATEGORY_GRADIENTS = {
  '服装':   { from: '#e84393', to: '#c2185b' },
  '美妆':   { from: '#e91e63', to: '#ad1457' },
  '食品':   { from: '#e17055', to: '#c0392b' },
  '图书':   { from: '#8b4513', to: '#5d2e0c' },
  '运动':   { from: '#00b894', to: '#00815f' },
  '母婴':   { from: '#fd79a8', to: '#d63031' },
  '宠物':   { from: '#c08457', to: '#8d6e4a' },
  '家装':   { from: '#d68910', to: '#b7950b' },
  '汽车':   { from: '#2d3436', to: '#1a252f' },
  '医药':   { from: '#0984e3', to: '#0652DD' },
  '生活':   { from: '#00b894', to: '#00815f' },
};

function hexToRgb(hex) {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return { r, g, b };
}

function makeGradientPixels(w, h, c1, c2) {
  const a = hexToRgb(c1), b2 = hexToRgb(c2);
  const buf = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const t = y / h;
    const r = Math.round(a.r + (b2.r - a.r) * t);
    const g = Math.round(a.g + (b2.g - a.g) * t);
    const bl = Math.round(a.b + (b2.b - a.b) * t);
    for (let x = 0; x < w; x++) {
      const off = (y * w + x) * 4;
      buf[off] = r; buf[off + 1] = g; buf[off + 2] = bl; buf[off + 3] = 255;
    }
  }
  return buf;
}

function escapeXml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function getGradient(category) {
  if (!category) return { from: '#2d4059', to: '#1a1a2e' };
  const topLevel = category.split('>')[0];
  return CATEGORY_GRADIENTS[topLevel] || { from: '#2d4059', to: '#1a1a2e' };
}

function generateCleanCardSvg(product, idx, colors) {
  const nameStr = product.name.length > 14 ? product.name.slice(0, 14) + '…' : product.name;
  const shortCat = product.category ? product.category.split('>').pop() : '';
  const W = 400, H = 420;

  if (idx === 1) {
    // 卡片图1：大号商品名 + 装饰 + 价格
    return `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
      <rect width="${W}" height="${H}" fill="none"/>
      <!-- 品类标签 -->
      <rect x="20" y="18" width="80" height="26" rx="13" fill="rgba(255,255,255,0.10)"/>
      <text x="60" y="34" font-size="12" fill="rgba(255,255,255,0.6)" text-anchor="middle" font-family="sans-serif">${escapeXml(shortCat)}</text>
      <!-- 装饰圆 -->
      <circle cx="200" cy="155" r="85" fill="rgba(255,255,255,0.05)"/>
      <circle cx="200" cy="155" r="60" fill="rgba(255,255,255,0.03)"/>
      <!-- 商品名（大字） -->
      <text x="200" y="270" font-size="28" font-weight="bold" text-anchor="middle" fill="white" font-family="sans-serif">${escapeXml(nameStr)}</text>
      <!-- 价格 -->
      <rect x="100" y="370" width="200" height="36" rx="18" fill="rgba(255,255,255,0.10)"/>
      <text x="200" y="394" font-size="18" font-weight="bold" text-anchor="middle" fill="#ffd700" font-family="sans-serif">¥${product.price}</text>
      <!-- 页码 -->
      <circle cx="190" cy="345" r="5" fill="white"/>
      <circle cx="210" cy="345" r="3" fill="rgba(255,255,255,0.3)"/>
    </svg>`;
  } else {
    // 卡片图2：商品名 + 点缀色块 + 价格
    return `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
      <rect width="${W}" height="${H}" fill="none"/>
      <!-- 品类标签 -->
      <rect x="20" y="18" width="80" height="26" rx="13" fill="rgba(255,255,255,0.10)"/>
      <text x="60" y="34" font-size="12" fill="rgba(255,255,255,0.6)" text-anchor="middle" font-family="sans-serif">${escapeXml(shortCat)}</text>
      <!-- 装饰方块 -->
      <rect x="140" y="120" width="120" height="80" rx="12" fill="rgba(255,255,255,0.06)"/>
      <rect x="160" y="140" width="80" height="4" rx="2" fill="rgba(255,255,255,0.15)"/>
      <rect x="165" y="155" width="70" height="4" rx="2" fill="rgba(255,255,255,0.10)"/>
      <rect x="170" y="170" width="60" height="4" rx="2" fill="rgba(255,255,255,0.07)"/>
      <!-- 商品名 -->
      <text x="200" y="260" font-size="24" font-weight="bold" text-anchor="middle" fill="white" font-family="sans-serif">${escapeXml(nameStr)}</text>
      <text x="200" y="290" font-size="13" text-anchor="middle" fill="rgba(255,255,255,0.5)" font-family="sans-serif">${escapeXml(shortCat)}品类 · 品质优选</text>
      <!-- 价格 -->
      <rect x="100" y="370" width="200" height="36" rx="18" fill="rgba(255,255,255,0.10)"/>
      <text x="200" y="394" font-size="18" font-weight="bold" text-anchor="middle" fill="#ffd700" font-family="sans-serif">¥${product.price}</text>
      <!-- 页码 -->
      <circle cx="190" cy="345" r="3" fill="rgba(255,255,255,0.3)"/>
      <circle cx="210" cy="345" r="5" fill="white"/>
    </svg>`;
  }
}

async function generateCleanCards(product) {
  const sharp = require('sharp');
  const slug = product.name.replace(/[^a-zA-Z0-9\u4e00-\u9fa5]/g, '').slice(0, 16) || 'product';
  const ts = Date.now();
  const colors = getGradient(product.category);
  const W = 400, H = 420;

  const files = [];
  for (let idx = 1; idx <= 2; idx++) {
    const filename = `card_${slug}_${ts}_${idx}.png`;
    const filepath = path.join(UPLOAD_DIR, filename);
    const svg = generateCleanCardSvg(product, idx, colors);
    const gradient = makeGradientPixels(W, H, colors.from, colors.to);
    await sharp(gradient, { raw: { width: W, height: H, channels: 4 } })
      .composite([{ input: Buffer.from(svg), top: 0, left: 0 }])
      .png().toFile(filepath);
    files.push(filename);
  }
  return files;
}

// ======== 主流程 ========
async function main() {
  const initSqlJs = require('sql.js');
  const SQL = await initSqlJs();
  const db = new SQL.Database(fs.readFileSync(path.join(__dirname, '..', 'data.db')));

  const rows = db.exec('SELECT id, name, price, category, image, images FROM products WHERE id > 10 ORDER BY id');
  const products = rows[0].values.map(v => ({
    id: v[0], name: v[1], price: v[2], category: v[3], image: v[4], images: v[5]
  }));

  console.log(`\n处理 ${products.length} 个非种子商品：\n`);

  let seedAssigned = 0, cardGenerated = 0, failed = 0;

  for (const product of products) {
    try {
      const seedResult = assignSeedImages(product);
      let img1, img2;

      if (seedResult) {
        // 使用现有种子图片
        img1 = seedResult[0];
        img2 = seedResult[1];
        seedAssigned++;
        process.stdout.write(`  🖼️  [${product.id}] ${product.name} ← ${img1}, ${img2}`);
      } else {
        // 生成清爽卡片图
        const files = await generateCleanCards(product);
        img1 = files[0];
        img2 = files[1];
        cardGenerated++;
        process.stdout.write(`  ✨  [${product.id}] ${product.name} ← 生成卡片图`);
      }

      // 更新 DB
      db.run('UPDATE products SET image = ?, images = ? WHERE id = ?',
        [img1, JSON.stringify([img1, img2]), product.id]);

      console.log(' ✅');
    } catch (err) {
      console.error(`  ❌ [${product.id}] ${product.name}: ${err.message}`);
      failed++;
    }
  }

  // 写入 DB
  const buf = db.export();
  fs.writeFileSync(path.join(__dirname, '..', 'data.db'), Buffer.from(buf));
  db.close();

  // 复制新生成的卡片图到 rawfile
  if (cardGenerated > 0) {
    if (!fs.existsSync(RAWFILE_DIR)) {
      fs.mkdirSync(RAWFILE_DIR, { recursive: true });
    }
    let copied = 0;
    const uploadFiles = fs.readdirSync(UPLOAD_DIR);
    for (const f of uploadFiles) {
      if (f.startsWith('card_') && f.endsWith('.png')) {
        const src = path.join(UPLOAD_DIR, f);
        const dst = path.join(RAWFILE_DIR, f);
        if (!fs.existsSync(dst)) {
          fs.copyFileSync(src, dst);
          copied++;
        }
      }
    }
    console.log(`\n已复制 ${copied} 张卡片图到 rawfile`);
  }

  const totalSuccess = seedAssigned + cardGenerated;
  console.log(`\n=== 完成 ===`);
  console.log(`种子图分配: ${seedAssigned} 个商品`);
  console.log(`卡片图生成: ${cardGenerated} 个商品`);
  console.log(`失败: ${failed}`);
  console.log(`合计: ${totalSuccess}/${products.length}`);
}

main().catch(err => { console.error(err); process.exit(1); });
