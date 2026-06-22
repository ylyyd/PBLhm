/**
 * 重新生成所有商品（ID 11-80）的图片
 * 
 * 问题：之前生成的图片全是暗色渐变+📦，所有品类一模一样
 * 修复：按品类区分颜色和图标，每个商品生成 2 张图用于轮播
 * 
 * 用法：node server/scripts/regenerate-product-images.js
 */

const path = require('path');
const fs = require('fs');
const sharp = require('sharp');

const UPLOAD_DIR = path.join(__dirname, '..', 'uploads');
const W = 400, H = 420;

// ===== 品类配色方案（三级分类 → 颜色+图标）=====
// 按照分类层级匹配，先匹配精确三级，再回退到二级，最后回退到一级
const CATEGORY_STYLES = {
  // ---- 手机 ----
  '手机':       { from: '#1a1a2e', to: '#16213e', icon: '📱' },
  '手机>华为':   { from: '#cf0a2c', to: '#8b071d', icon: '📱' },
  '手机>iPhone': { from: '#1a3a5c', to: '#0d2137', icon: '📱' },
  '手机>小米':   { from: '#ff6900', to: '#cc5500', icon: '📱' },
  '手机>OPPO':   { from: '#1e8449', to: '#145a32', icon: '📱' },
  '手机>vivo':   { from: '#4158d0', to: '#283593', icon: '📱' },
  '手机>三星':   { from: '#1428a0', to: '#0d1b6e', icon: '📱' },
  '手机>荣耀':   { from: '#e91e63', to: '#ad1457', icon: '📱' },
  // ---- 电脑 ----
  '电脑':       { from: '#2c3e50', to: '#1a252f', icon: '💻' },
  '电脑>联想':   { from: '#005bac', to: '#003d78', icon: '💻' },
  '电脑>苹果':   { from: '#555555', to: '#333333', icon: '💻' },
  '电脑>华为':   { from: '#cf0a2c', to: '#8b071d', icon: '💻' },
  '电脑>华硕':   { from: '#1a6fb5', to: '#0e4779', icon: '💻' },
  '电脑>戴尔':   { from: '#007db8', to: '#005a87', icon: '💻' },
  '电脑>惠普':   { from: '#0096d6', to: '#006699', icon: '💻' },
  // ---- 家电 ----
  '家电':       { from: '#0077b6', to: '#005082', icon: '🏠' },
  '家电>电视':   { from: '#e94560', to: '#c23152', icon: '📺' },
  '家电>空调':   { from: '#0077b6', to: '#005082', icon: '❄️' },
  '家电>洗衣机': { from: '#00b4d8', to: '#0077b6', icon: '🧺' },
  '家电>冰箱':   { from: '#48cae4', to: '#0096c7', icon: '🧊' },
  '家电>扫地机器人': { from: '#6c63ff', to: '#4a42d4', icon: '🤖' },
  '家电>热水器': { from: '#e07c24', to: '#b6601c', icon: '🔥' },
  // ---- 配件 ----
  '配件':       { from: '#6c5ce7', to: '#4834d4', icon: '🔌' },
  '配件>耳机':   { from: '#533483', to: '#3b185f', icon: '🎧' },
  '配件>充电器': { from: '#fd79a8', to: '#e84393', icon: '🔋' },
  '配件>充电宝': { from: '#fdcb6e', to: '#e17055', icon: '🔋' },
  '配件>数据线': { from: '#74b9ff', to: '#0984e3', icon: '🔌' },
  '配件>手机壳': { from: '#a29bfe', to: '#6c5ce7', icon: '📱' },
  '配件>贴膜':   { from: '#81ecec', to: '#00cec9', icon: '🛡️' },
  // ---- 服装 ----
  '服装':       { from: '#e84393', to: '#c2185b', icon: '👕' },
  '服装>男装':   { from: '#2d3436', to: '#1a1a2e', icon: '👔' },
  '服装>女装':   { from: '#fd79a8', to: '#e84393', icon: '👗' },
  '服装>运动鞋': { from: '#00b894', to: '#00815f', icon: '👟' },
  '服装>休闲鞋': { from: '#6c5ce7', to: '#4834d4', icon: '👞' },
  '服装>包包':   { from: '#e17055', to: '#c0392b', icon: '👜' },
  // ---- 美妆 ----
  '美妆':       { from: '#e91e63', to: '#c2185b', icon: '💄' },
  '美妆>彩妆':   { from: '#ff6b81', to: '#e84393', icon: '💄' },
  '美妆>护肤':   { from: '#f8a5c2', to: '#e84393', icon: '🧴' },
  '美妆>香水':   { from: '#a29bfe', to: '#6c5ce7', icon: '🧪' },
  '美妆>洗护':   { from: '#74b9ff', to: '#0984e3', icon: '🚿' },
  // ---- 食品 ----
  '食品':       { from: '#e17055', to: '#c0392b', icon: '🍜' },
  '食品>零食':   { from: '#fdcb6e', to: '#e17055', icon: '🍿' },
  '食品>茶饮':   { from: '#27ae60', to: '#1e8449', icon: '🍵' },
  '食品>粮油调味': { from: '#f39c12', to: '#d68910', icon: '🌾' },
  '食品>生鲜':   { from: '#00b894', to: '#00815f', icon: '🥩' },
  '食品>酒水':   { from: '#8e44ad', to: '#6c3483', icon: '🍷' },
  // ---- 图书 ----
  '图书':       { from: '#8b4513', to: '#5d2e0c', icon: '📚' },
  '图书>文学':   { from: '#a0522d', to: '#6b3410', icon: '📖' },
  '图书>科技':   { from: '#2c3e50', to: '#1a252f', icon: '📘' },
  '图书>童书':   { from: '#e17055', to: '#d63031', icon: '📙' },
  '图书>教育':   { from: '#0984e3', to: '#0652DD', icon: '📕' },
  '图书>生活':   { from: '#00b894', to: '#00815f', icon: '📗' },
  // ---- 运动 ----
  '运动':       { from: '#00b894', to: '#00815f', icon: '🏃' },
  '运动>运动鞋服': { from: '#e17055', to: '#c0392b', icon: '👟' },
  '运动>瑜伽':   { from: '#a29bfe', to: '#6c5ce7', icon: '🧘' },
  '运动>户外装备': { from: '#2d3436', to: '#1a252f', icon: '🏕️' },
  '运动>健身器材': { from: '#fdcb6e', to: '#e17055', icon: '🏋️' },
  '运动>骑行':   { from: '#0984e3', to: '#0652DD', icon: '🚴' },
  // ---- 母婴 ----
  '母婴':       { from: '#fd79a8', to: '#e84393', icon: '👶' },
  '母婴>奶粉':   { from: '#74b9ff', to: '#0984e3', icon: '🍼' },
  '母婴>纸尿裤': { from: '#81ecec', to: '#00cec9', icon: '👶' },
  '母婴>玩具':   { from: '#fdcb6e', to: '#e17055', icon: '🧸' },
  '母婴>童装':   { from: '#f8a5c2', to: '#e84393', icon: '👚' },
  '母婴>推车':   { from: '#a29bfe', to: '#6c5ce7', icon: '🚼' },
  // ---- 宠物 ----
  '宠物':       { from: '#c08457', to: '#8d6e4a', icon: '🐾' },
  '宠物>狗粮':   { from: '#e17055', to: '#c0392b', icon: '🐕' },
  '宠物>猫粮':   { from: '#fdcb6e', to: '#e17055', icon: '🐱' },
  '宠物>宠物用品': { from: '#74b9ff', to: '#0984e3', icon: '🐾' },
  '宠物>宠物玩具': { from: '#a29bfe', to: '#6c5ce7', icon: '🧶' },
  '宠物>宠物医疗': { from: '#55efc4', to: '#00b894', icon: '💊' },
  // ---- 家装 ----
  '家装':       { from: '#d68910', to: '#b7950b', icon: '🛋️' },
  '家装>灯具':   { from: '#fdcb6e', to: '#e17055', icon: '💡' },
  '家装>家纺':   { from: '#f8a5c2', to: '#e84393', icon: '🛏️' },
  '家装>家具':   { from: '#8b4513', to: '#5d2e0c', icon: '🪑' },
  '家装>厨具':   { from: '#3498db', to: '#2980b9', icon: '🍳' },
  '家装>装饰':   { from: '#a29bfe', to: '#6c5ce7', icon: '🖼️' },
  // ---- 汽车 ----
  '汽车':       { from: '#2d3436', to: '#1a252f', icon: '🚗' },
  '汽车>车载电器': { from: '#0984e3', to: '#0652DD', icon: '🔌' },
  '汽车>汽车用品': { from: '#00b894', to: '#00815f', icon: '🧹' },
  '汽车>维修保养': { from: '#e17055', to: '#c0392b', icon: '🔧' },
  '汽车>车饰':   { from: '#6c5ce7', to: '#4834d4', icon: '✨' },
  '汽车>脚垫':   { from: '#2d3436', to: '#636e72', icon: '🚗' },
  // ---- 医药 ----
  '医药':       { from: '#0984e3', to: '#0652DD', icon: '💊' },
  '医药>常备药': { from: '#00b894', to: '#00815f', icon: '💊' },
  '医药>保健品': { from: '#fdcb6e', to: '#e17055', icon: '💊' },
  '医药>医疗器械': { from: '#74b9ff', to: '#0984e3', icon: '🩺' },
  '医药>计生用品': { from: '#e84393', to: '#c2185b', icon: '🛡️' },
  '医药>眼镜':   { from: '#2d3436', to: '#636e72', icon: '👓' },
  // ---- 生活 ----
  '生活':       { from: '#00b894', to: '#00815f', icon: '🎯' },
  '生活>智能设备': { from: '#6c5ce7', to: '#4834d4', icon: '🔊' },
  '生活>个护健康': { from: '#fd79a8', to: '#e84393', icon: '🪥' },
  '生活>办公设备': { from: '#0984e3', to: '#0652DD', icon: '🖨️' },
  '生活>家居':   { from: '#a29bfe', to: '#6c5ce7', icon: '🏡' },
  '生活>厨房用品': { from: '#e17055', to: '#c0392b', icon: '🍳' },
};

// 默认样式（无匹配时）
const DEFAULT_STYLE = { from: '#2d4059', to: '#1a1a2e', icon: '📦' };

function getStyle(category) {
  // 1. 精确三级匹配（手机>华为）
  if (category && CATEGORY_STYLES[category]) {
    return CATEGORY_STYLES[category];
  }
  // 2. 回退到二级匹配（手机）
  if (category) {
    const topLevel = category.split('>')[0];
    if (CATEGORY_STYLES[topLevel]) {
      return CATEGORY_STYLES[topLevel];
    }
  }
  return DEFAULT_STYLE;
}

function hexToRgb(hex) {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return { r, g, b };
}

function makeGradientPixels(w, h, c1, c2) {
  const a = hexToRgb(c1), b = hexToRgb(c2);
  const buf = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const t = y / h;
    const r = Math.round(a.r + (b.r - a.r) * t);
    const g = Math.round(a.g + (b.g - a.g) * t);
    const bl = Math.round(a.b + (b.b - a.b) * t);
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

/**
 * 为商品生成一张 SVG 占位图
 * @param {*} product  商品对象
 * @param {number} idx 图片序号（1 或 2）
 * @param {number} totalVariants 总张数
 */
function generateSvg(product, idx, totalVariants) {
  const style = getStyle(product.category);
  const nameStr = product.name.length > 12 ? product.name.slice(0, 12) + '…' : product.name;
  const shortCat = product.category ? product.category.split('>').pop() : '商品';

  // 变体 1：大图标 + 名称，变体 2：展示分类信息 + 不同布局
  let iconY = 155, nameY = 270, priceY = 350;

  if (idx === 1) {
    // 第一张：大图标 + 名称 + 价格
    return `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
      <rect width="${W}" height="${H}" fill="none"/>
      <!-- 分类标签 -->
      <rect x="20" y="16" width="80" height="24" rx="12" fill="rgba(255,255,255,0.12)"/>
      <text x="60" y="32" font-size="11" fill="rgba(255,255,255,0.7)" text-anchor="middle" font-family="sans-serif">${escapeXml(shortCat)}</text>
      <!-- 大图标 -->
      <text x="200" y="160" font-size="96" text-anchor="middle" dominant-baseline="central" font-family="sans-serif">${style.icon}</text>
      <!-- 装饰环 -->
      <circle cx="200" cy="160" r="80" fill="none" stroke="rgba(255,255,255,0.06)" stroke-width="2"/>
      <!-- 商品名 -->
      <text x="200" y="275" font-size="24" font-weight="bold" text-anchor="middle" fill="white" font-family="sans-serif">${escapeXml(nameStr)}</text>
      <!-- 价格 -->
      <rect x="100" y="370" width="200" height="36" rx="18" fill="rgba(255,255,255,0.10)"/>
      <text x="200" y="394" font-size="18" font-weight="bold" text-anchor="middle" fill="#ffd700" font-family="sans-serif">¥${product.price}</text>
      <!-- 页码指示器 -->
      <circle cx="190" cy="340" r="5" fill="white"/>
      <circle cx="210" cy="340" r="3" fill="rgba(255,255,255,0.3)"/>
    </svg>`;
  } else {
    // 第二张：展示特点描述
    const descText = getProductDescription(product);
    return `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
      <rect width="${W}" height="${H}" fill="none"/>
      <!-- 分类标签 -->
      <rect x="20" y="16" width="80" height="24" rx="12" fill="rgba(255,255,255,0.12)"/>
      <text x="60" y="32" font-size="11" fill="rgba(255,255,255,0.7)" text-anchor="middle" font-family="sans-serif">${escapeXml(shortCat)}</text>
      <!-- 小图标 -->
      <text x="200" y="155" font-size="64" text-anchor="middle" dominant-baseline="central" font-family="sans-serif">${style.icon}</text>
      <!-- 商品名 -->
      <text x="200" y="230" font-size="22" font-weight="bold" text-anchor="middle" fill="white" font-family="sans-serif">${escapeXml(nameStr)}</text>
      <!-- 特点描述 -->
      <text x="200" y="270" font-size="14" text-anchor="middle" fill="rgba(255,255,255,0.6)" font-family="sans-serif">${escapeXml(descText)}</text>
      <!-- 价格 -->
      <rect x="100" y="370" width="200" height="36" rx="18" fill="rgba(255,255,255,0.10)"/>
      <text x="200" y="394" font-size="18" font-weight="bold" text-anchor="middle" fill="#ffd700" font-family="sans-serif">¥${product.price}</text>
      <!-- 页码指示器 -->
      <circle cx="190" cy="340" r="3" fill="rgba(255,255,255,0.3)"/>
      <circle cx="210" cy="340" r="5" fill="white"/>
    </svg>`;
  }
}

/**
 * 根据分类生成简短描述
 */
function getProductDescription(product) {
  const cat = product.category || '';
  if (cat.includes('手机')) return '5G全网通 · 旗舰性能';
  if (cat.includes('电脑')) return '高性能 · 轻薄便携';
  if (cat.includes('电视')) return '4K HDR · 智能系统';
  if (cat.includes('空调')) return '变频节能 · 静音运行';
  if (cat.includes('冰箱')) return '风冷无霜 · 大容量';
  if (cat.includes('洗衣机')) return '变频静音 · 智能洗涤';
  if (cat.includes('耳机')) return 'HiFi音质 · 降噪技术';
  if (cat.includes('配件') || cat.includes('充电')) return '品质之选 · 安全快充';
  if (cat.includes('服装') || cat.includes('鞋')) return '舒适面料 · 时尚设计';
  if (cat.includes('美妆') || cat.includes('护肤')) return '温和配方 · 焕亮肌肤';
  if (cat.includes('食品') || cat.includes('零食')) return '精选原料 · 美味健康';
  if (cat.includes('图书')) return '正版保障 · 畅享阅读';
  if (cat.includes('运动') || cat.includes('健身')) return '专业品质 · 运动必备';
  if (cat.includes('母婴')) return '安全材质 · 呵护成长';
  if (cat.includes('宠物')) return '营养均衡 · 爱宠首选';
  if (cat.includes('家装') || cat.includes('家具')) return '简约设计 · 品质生活';
  if (cat.includes('汽车') || cat.includes('车载')) return '爱车必备 · 安全实用';
  if (cat.includes('医药') || cat.includes('保健')) return '品质保障 · 健康守护';
  if (cat.includes('厨房')) return '轻松烹饪 · 美味佳肴';
  return '品质生活 · 开心购物';
}

async function generateProductImage(product, index) {
  const slug = product.name
    .replace(/[^a-zA-Z0-9\u4e00-\u9fa5]/g, '')
    .slice(0, 16) || 'product';

  const filename = slug + '_' + Date.now() + '_' + index + '.png';
  const filepath = path.join(UPLOAD_DIR, filename);
  const style = getStyle(product.category);

  const svgContent = generateSvg(product, index, 2);
  const gradient = makeGradientPixels(W, H, style.from, style.to);

  await sharp(gradient, { raw: { width: W, height: H, channels: 4 } })
    .composite([{ input: Buffer.from(svgContent), top: 0, left: 0 }])
    .png()
    .toFile(filepath);

  return filename;
}

async function main() {
  const initSqlJs = require('sql.js');
  const SQL = await initSqlJs();
  const db = new SQL.Database(fs.readFileSync(path.join(__dirname, '..', 'data.db')));

  if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  }

  // 读取所有非种子商品
  const rows = db.exec('SELECT id, name, price, category, image, images FROM products WHERE id > 10 ORDER BY id');
  const products = rows[0].values.map(v => ({
    id: v[0], name: v[1], price: v[2], category: v[3], image: v[4], images: v[5]
  }));

  console.log(`共计 ${products.length} 个非种子商品需要生成图片`);
  console.log('');

  let success = 0, fail = 0;

  for (const product of products) {
    try {
      // 生成 2 张图
      const img1 = await generateProductImage(product, 1);
      const img2 = await generateProductImage(product, 2);
      const imagesJson = JSON.stringify([img1, img2]);

      // 更新 DB
      db.run('UPDATE products SET image = ?, images = ? WHERE id = ?', [img1, imagesJson, product.id]);

      console.log(`  ✅ [${product.id}] ${product.name}`);
      console.log(`     ${img1}`);
      console.log(`     ${img2}`);
      success++;
    } catch (err) {
      console.error(`  ❌ [${product.id}] ${product.name} 失败: ${err.message}`);
      fail++;
    }
  }

  // 保存 DB
  const dbBuf = db.export();
  fs.writeFileSync(path.join(__dirname, '..', 'data.db'), Buffer.from(dbBuf));
  db.close();

  console.log('');
  console.log(`完成！成功: ${success}, 失败: ${fail}`);
}

main().catch(err => { console.error('脚本异常:', err); process.exit(1); });
