const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const RAWFILE_DIR = path.join(__dirname, '..', '..', 'entry', 'src', 'main', 'resources', 'rawfile');
const OUTPUT_DIR = path.join(__dirname, '..', 'uploads');

const W = 400, H = 420;
const force = process.argv.includes('--force');

const CATEGORY_COLORS = {
  '手机>华为':   { from: '#1a1a2e', to: '#16213e', icon: '📱' },
  '手机>iPhone': { from: '#1a3a5c', to: '#0d2137', icon: '📱' },
  '手机>小米':   { from: '#ff6900', to: '#cc5500', icon: '📱' },
  '电脑>联想':   { from: '#005bac', to: '#003d78', icon: '💻' },
  '电脑>苹果':   { from: '#555555', to: '#333333', icon: '💻' },
  '电脑>华为':   { from: '#cf0a2c', to: '#8b071d', icon: '💻' },
  '配件>耳机':   { from: '#533483', to: '#3b185f', icon: '🎧' },
  '家电>电视':   { from: '#e94560', to: '#c23152', icon: '🏠' },
  '家电>空调':   { from: '#0077b6', to: '#005082', icon: '❄️' },
};

const PRODUCT_DETAILS = {
  mate60pro: [
    { subtitle: '麒麟9000S · 卫星通话' },
    { subtitle: '雅丹黑 · 512GB', tagColor: '#333' },
    { subtitle: '雅川青 · 256GB', tagColor: '#2d5a4a' },
    { subtitle: '昆仑玻璃 · 鸿蒙4.0' },
  ],
  iphone15: [
    { subtitle: 'A16仿生 · 4800万像素' },
    { subtitle: '黑色 · 256GB', tagColor: '#222' },
    { subtitle: '粉色 · 128GB', tagColor: '#ffb6c1' },
    { subtitle: '灵动岛 · USB-C' },
  ],
  mi14ultra: [
    { subtitle: '骁龙8Gen3 · 徕卡光学' },
    { subtitle: '黑色 · 512GB', tagColor: '#333' },
    { subtitle: '白色 · 256GB', tagColor: '#f0f0f0' },
    { subtitle: '2K屏 · 超级快充' },
  ],
  redmik70: [
    { subtitle: '骁龙8Gen2 · 性价比之王' },
    { subtitle: '2K直屏 · 120W快充' },
    { subtitle: '5000万主摄 · 狂暴引擎' },
  ],
  lenovo_xiaoxin: [
    { subtitle: 'i7处理器 · 16英寸2.5K' },
    { subtitle: '32GB内存 · 1TB固态' },
    { subtitle: '轻薄本 · 全金属机身' },
  ],
  macbookair: [
    { subtitle: 'M3芯片 · 13.6英寸' },
    { subtitle: 'Liquid Retina · P3广色域' },
    { subtitle: '18小时续航 · 无风扇' },
    { subtitle: '午夜色 · 8GB+512GB', tagColor: '#2c3e50' },
  ],
  matebookx: [
    { subtitle: '3.1K OLED · 酷睿Ultra' },
    { subtitle: '超级终端 · 多屏协同' },
    { subtitle: '1.26kg · 超轻薄机身' },
    { subtitle: '拂晓粉 · 32GB+1TB', tagColor: '#e8b4b8' },
  ],
  airpodspro2: [
    { subtitle: '主动降噪 · H2芯片' },
    { subtitle: '自适应音频 · 通透模式' },
    { subtitle: 'MagSafe充电盒' },
    { subtitle: '个性化空间音频' },
  ],
  mitvs75: [
    { subtitle: '75英寸4K · 120Hz' },
    { subtitle: '杜比视界 · HDR10+' },
    { subtitle: '65英寸款 · 2999元', tagColor: '#555' },
    { subtitle: '85英寸款 · 5999元', tagColor: '#8b0000' },
  ],
  gree_ac: [
    { subtitle: '1.5匹变频 · 新一级能效' },
    { subtitle: '自清洁 · 56℃高温除菌' },
    { subtitle: '智能WiFi · 远程控温' },
  ],
};

function getColors(category) {
  return CATEGORY_COLORS[category] || { from: '#2d4059', to: '#1a1a2e', icon: '📦' };
}

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
    const b = Math.round(a.b + (b2.b - a.b) * t);
    for (let x = 0; x < w; x++) {
      const off = (y * w + x) * 4;
      buf[off] = r; buf[off + 1] = g; buf[off + 2] = b; buf[off + 3] = 255;
    }
  }
  return buf;
}

function escapeXml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

const PRODUCTS = [
  { imageKey: 'mate60pro',  name: '华为Mate60 Pro',      price: 6999,  category: '手机>华为' },
  { imageKey: 'iphone15',   name: 'Apple iPhone 15',     price: 7999,  category: '手机>iPhone' },
  { imageKey: 'mi14ultra',  name: '小米14 Ultra',        price: 5999,  category: '手机>小米' },
  { imageKey: 'redmik70',   name: 'Redmi K70',           price: 2499,  category: '手机>小米' },
  { imageKey: 'lenovo_xiaoxin', name: '联想小新Pro 16',  price: 5999,  category: '电脑>联想' },
  { imageKey: 'macbookair', name: 'MacBook Air M3',      price: 8999,  category: '电脑>苹果' },
  { imageKey: 'matebookx',  name: '华为MateBook X Pro',  price: 9999,  category: '电脑>华为' },
  { imageKey: 'airpodspro2', name: 'AirPods Pro 2',      price: 1899,  category: '配件>耳机' },
  { imageKey: 'mitvs75',    name: '小米电视S75',         price: 3999,  category: '家电>电视' },
  { imageKey: 'gree_ac',    name: '格力空调KFR-35GW',    price: 3299,  category: '家电>空调' },
];

async function generateOne(product, index) {
  const key = product.imageKey;
  const filename = `${key}_${index}.png`;
  const rawPath = path.join(RAWFILE_DIR, filename);
  const upPath = path.join(OUTPUT_DIR, filename);

  if (!force && fs.existsSync(rawPath)) {
    return { filename, skipped: true };
  }

  const colors = getColors(product.category);
  const details = (PRODUCT_DETAILS[key] || [])[index - 1] || { subtitle: '' };

  const subtitle = details.subtitle;
  const tagColor = details.tagColor || null;

  const nameStr = product.name.length > 12 ? product.name.slice(0, 12) + '…' : product.name;

  let badgeSvg = '';
  if (tagColor) {
    const tc = escapeXml(tagColor);
    badgeSvg = `<rect x="140" y="228" width="120" height="26" rx="13" fill="${tc}" opacity="0.9"/>
      <text x="200" y="246" font-size="12" fill="white" text-anchor="middle" font-family="sans-serif">${escapeXml(subtitle.split('·')[0]?.trim() || subtitle)}</text>`;
  }

  const svg = `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
    <!-- Spec badge top-left -->
    <rect x="16" y="16" width="64" height="24" rx="12" fill="rgba(255,255,255,0.12)"/>
    <text x="48" y="32" font-size="11" fill="rgba(255,255,255,0.7)" text-anchor="middle" font-family="sans-serif">${escapeXml(key === 'mate60pro' ? '麒麟' : key === 'iphone15' ? 'A16' : key === 'mi14ultra' ? '骁龙' : key === 'macbookair' ? 'M3' : key === 'mitvs75' ? '4K' : key === 'gree_ac' ? '变频' : '新品')}</text>

    <!-- Large product icon -->
    <text x="200" y="155" font-size="96" text-anchor="middle" dominant-baseline="central" font-family="sans-serif">${colors.icon}</text>

    <!-- Decorative ring -->
    <circle cx="200" cy="155" r="80" fill="none" stroke="rgba(255,255,255,0.06)" stroke-width="2"/>

    <!-- Product name -->
    <text x="200" y="270" font-size="26" font-weight="bold" text-anchor="middle" fill="white" font-family="sans-serif">${escapeXml(nameStr)}</text>

    <!-- Subtitle / feature -->
    ${subtitle ? (tagColor ? badgeSvg :
      `<text x="200" y="300" font-size="13" text-anchor="middle" fill="rgba(255,255,255,0.6)" font-family="sans-serif">${escapeXml(subtitle)}</text>`
    ) : ''}

    <!-- Index dots -->
    ${[1,2,3,4].filter(i => (PRODUCT_DETAILS[key] || []).length >= i).map(i =>
      `<circle cx="${200 + (i - 3) * 20}" cy="345" r="${i === index ? 5 : 3}" fill="${i === index ? 'white' : 'rgba(255,255,255,0.3)'}"/>`
    ).join('')}

    <!-- Price bar -->
    <rect x="100" y="370" width="200" height="36" rx="18" fill="rgba(255,255,255,0.10)"/>
    <text x="200" y="394" font-size="18" font-weight="bold" text-anchor="middle" fill="#ffd700" font-family="sans-serif">¥${product.price}</text>
  </svg>`;

  const gradient = makeGradientPixels(W, H, colors.from, colors.to);
  await sharp(gradient, { raw: { width: W, height: H, channels: 4 } })
    .composite([{ input: Buffer.from(svg), top: 0, left: 0 }])
    .png()
    .toFile(rawPath);

  await sharp(rawPath).clone().toFile(upPath);

  return { filename, skipped: false };
}

async function main() {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  console.log(`Output: ${RAWFILE_DIR}`);
  console.log(`Upload: ${OUTPUT_DIR}`);
  console.log(`Mode: ${force ? '--force (overwrite)' : 'skip existing'}\n`);

  let gen = 0, skip = 0;
  for (const product of PRODUCTS) {
    const count = (PRODUCT_DETAILS[product.imageKey] || []).length;
    for (let i = 1; i <= count; i++) {
      const r = await generateOne(product, i);
      if (r.skipped) { skip++; }
      else { console.log(`  ${r.filename}`); gen++; }
    }
  }
  console.log(`\nDone! Generated: ${gen}, Skipped: ${skip}`);
}

main().catch(err => { console.error(err); process.exit(1); });
