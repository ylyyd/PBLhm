/**
 * 最终方案：为全部 70 个非种子商品生成独立卡片图
 * 每商品 2 张，完全唯一，不和任何其他商品共用
 */
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');

const UPLOAD_DIR = path.join(__dirname, '..', 'uploads');
const RAWFILE_DIR = path.join(__dirname, '..', '..', 'entry', 'src', 'main', 'resources', 'rawfile');
const W = 400, H = 420;

// 品类配色（仅用于生成时区分 -- 不对图片内容作任何品类标注）
const CAT_COLORS = {
  '手机':   ['#1a1a2e','#16213e'],  '电脑':   ['#2c3e50','#1a252f'],
  '家电':   ['#0077b6','#005082'],  '配件':   ['#6c5ce7','#4834d4'],
  '服装':   ['#e84393','#c2185b'],  '美妆':   ['#e91e63','#ad1457'],
  '食品':   ['#e17055','#c0392b'],  '图书':   ['#8b4513','#5d2e0c'],
  '运动':   ['#00b894','#00815f'],  '母婴':   ['#fd79a8','#d63031'],
  '宠物':   ['#c08457','#8d6e4a'],  '家装':   ['#d68910','#b7950b'],
  '汽车':   ['#2d3436','#1a252f'],  '医药':   ['#0984e3','#0652DD'],
  '生活':   ['#00b894','#00815f'],
};

function getColor(cat) {
  if (!cat) return ['#2d4059','#1a1a2e'];
  const top = cat.split('>')[0];
  return CAT_COLORS[top] || ['#2d4059','#1a1a2e'];
}

function hex2rgb(h) {
  return { r: parseInt(h.slice(1,3),16), g: parseInt(h.slice(3,5),16), b: parseInt(h.slice(5,7),16) };
}

function gradientPixels(w, h, c1, c2) {
  const a = hex2rgb(c1), b2 = hex2rgb(c2);
  const buf = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const t = y / h;
    const r = Math.round(a.r + (b2.r - a.r) * t);
    const g = Math.round(a.g + (b2.g - a.g) * t);
    const bl = Math.round(a.b + (b2.b - a.b) * t);
    for (let x = 0; x < w; x++) {
      const off = (y * w + x) * 4;
      buf[off] = r; buf[off+1] = g; buf[off+2] = bl; buf[off+3] = 255;
    }
  }
  return buf;
}

function esc(s) { return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

function cardSvg(product, idx) {
  const name = product.name.length > 14 ? product.name.slice(0, 14) + '…' : product.name;
  const [frm, to] = getColor(product.category);

  if (idx === 1) {
    return `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
      <rect width="${W}" height="${H}" fill="none"/>
      <rect x="20" y="18" width="70" height="26" rx="13" fill="rgba(255,255,255,0.10)"/>
      <text x="55" y="34" font-size="11" fill="rgba(255,255,255,0.6)" text-anchor="middle" font-family="sans-serif">${esc(product.category ? product.category.split('>').pop() : '商品')}</text>
      <circle cx="200" cy="155" r="85" fill="rgba(255,255,255,0.05)"/>
      <circle cx="200" cy="155" r="60" fill="rgba(255,255,255,0.03)"/>
      <text x="200" y="275" font-size="26" font-weight="bold" text-anchor="middle" fill="white" font-family="sans-serif">${esc(name)}</text>
      <rect x="100" y="370" width="200" height="36" rx="18" fill="rgba(255,255,255,0.10)"/>
      <text x="200" y="394" font-size="18" font-weight="bold" text-anchor="middle" fill="#ffd700" font-family="sans-serif">¥${product.price}</text>
    </svg>`;
  } else {
    return `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
      <rect width="${W}" height="${H}" fill="none"/>
      <rect x="20" y="18" width="70" height="26" rx="13" fill="rgba(255,255,255,0.10)"/>
      <text x="55" y="34" font-size="11" fill="rgba(255,255,255,0.6)" text-anchor="middle" font-family="sans-serif">${esc(product.category ? product.category.split('>').pop() : '商品')}</text>
      <rect x="145" y="120" width="110" height="80" rx="12" fill="rgba(255,255,255,0.05)"/>
      <rect x="170" y="140" width="60" height="4" rx="2" fill="rgba(255,255,255,0.12)"/>
      <rect x="175" y="155" width="50" height="4" rx="2" fill="rgba(255,255,255,0.08)"/>
      <rect x="180" y="170" width="40" height="4" rx="2" fill="rgba(255,255,255,0.05)"/>
      <text x="200" y="265" font-size="24" font-weight="bold" text-anchor="middle" fill="white" font-family="sans-serif">${esc(name)}</text>
      <text x="200" y="295" font-size="13" text-anchor="middle" fill="rgba(255,255,255,0.45)" font-family="sans-serif">${esc(product.category ? product.category.split('>').pop() : '品质')} · 开心购物</text>
      <rect x="100" y="370" width="200" height="36" rx="18" fill="rgba(255,255,255,0.10)"/>
      <text x="200" y="394" font-size="18" font-weight="bold" text-anchor="middle" fill="#ffd700" font-family="sans-serif">¥${product.price}</text>
    </svg>`;
  }
}

async function main() {
  const initSqlJs = require('sql.js');
  const SQL = await initSqlJs();
  const db = new SQL.Database(fs.readFileSync(path.join(__dirname, '..', 'data.db')));

  // 读非种子商品
  const rows = db.exec('SELECT id, name, price, category FROM products WHERE id > 10 ORDER BY id');
  const products = rows[0].values.map(v => ({ id: v[0], name: v[1], price: v[2], category: v[3] }));

  if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

  console.log(`为 ${products.length} 个商品生成独立卡片图...\n`);

  let ok = 0, fail = 0;

  for (const p of products) {
    try {
      const slug = p.name.replace(/[^a-zA-Z0-9\u4e00-\u9fa5]/g, '').slice(0, 16) || 'product';
      const ts = Date.now();
      const f1 = `p_${slug}_${ts}_1.png`;
      const f2 = `p_${slug}_${ts}_2.png`;
      const col = getColor(p.category);
      const [c1, c2] = col;

      // 图1
      await sharp(gradientPixels(W, H, c1, c2), { raw: { width: W, height: H, channels: 4 } })
        .composite([{ input: Buffer.from(cardSvg(p, 1)), top: 0, left: 0 }])
        .png().toFile(path.join(UPLOAD_DIR, f1));

      // 图2
      await sharp(gradientPixels(W, H, c1, c2), { raw: { width: W, height: H, channels: 4 } })
        .composite([{ input: Buffer.from(cardSvg(p, 2)), top: 0, left: 0 }])
        .png().toFile(path.join(UPLOAD_DIR, f2));

      // 更新 DB
      db.run('UPDATE products SET image = ?, images = ? WHERE id = ?',
        [f1, JSON.stringify([f1, f2]), p.id]);

      console.log(`  [${p.id}] ${p.name} ✅`);
      ok++;
    } catch (err) {
      console.error(`  [${p.id}] ${p.name} ❌ ${err.message}`);
      fail++;
    }
  }

  // 写回 DB
  const buf = db.export();
  fs.writeFileSync(path.join(__dirname, '..', 'data.db'), Buffer.from(buf));
  db.close();

  // 复制到 rawfile
  if (!fs.existsSync(RAWFILE_DIR)) fs.mkdirSync(RAWFILE_DIR, { recursive: true });
  let copied = 0;
  for (const f of fs.readdirSync(UPLOAD_DIR)) {
    if (f.startsWith('p_') && f.endsWith('.png')) {
      const dst = path.join(RAWFILE_DIR, f);
      if (!fs.existsSync(dst)) {
        fs.copyFileSync(path.join(UPLOAD_DIR, f), dst);
        copied++;
      }
    }
  }

  console.log(`\n完成！成功 ${ok}，失败 ${fail}，复制 ${copied} 张到 rawfile`);
}

main().catch(err => { console.error(err); process.exit(1); });
