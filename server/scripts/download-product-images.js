const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const RAWFILE_DIR = path.join(__dirname, '..', '..', 'entry', 'src', 'main', 'resources', 'rawfile');
const UPLOAD_DIR = path.join(__dirname, '..', 'uploads');

const PRODUCT_IMAGES = {
  mate60pro: [
    'https://imgservice.suning.cn/uimg1/b2c/image/opAOQ0EifMrOZHr5bw6BcQ.jpg_800w_800h_4e',
    'https://imgservice.suning.cn/uimg1/b2c/image/oosCeQwwJkdtpAPjBgILFw.jpg_800w_800h_4e',
    'https://imgservice.suning.cn/uimg1/b2c/image/01TP8WW2XM5aRVVsskJsAQ.jpg_800w_800h_4e',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/P2fUeU9D1owlz8RD8KAh4Q.jpg',
  ],
  iphone15: [
    'https://www.apple.com/newsroom/images/2023/09/apple-debuts-iphone-15-and-iphone-15-plus/article/Apple-iPhone-15-lineup-hero-230912_inline.jpg.large.jpg',
    'https://www.apple.com/newsroom/images/2023/09/apple-debuts-iphone-15-and-iphone-15-plus/article/Apple-iPhone-15-lineup-color-lineup-230912_big.jpg.large.jpg',
    'https://www.apple.com/newsroom/images/2023/09/apple-debuts-iphone-15-and-iphone-15-plus/article/Apple-iPhone-15-lineup-design-230912_big.jpg.large.jpg',
    'https://www.apple.com/newsroom/images/2023/09/apple-debuts-iphone-15-and-iphone-15-plus/article/Apple-iPhone-15-48MP-01-230912_big.jpg.large.jpg',
  ],
  mi14ultra: [
    'https://imgservice.suning.cn/uimg1/b2c/image/atzZyRPIxegHzFqVsLYnmg.png_800w_800h_4e',
    'https://imgservice.suning.cn/uimg1/b2c/image/QFIo6dxEHWh4CeOseg6Ylw.jpg_800w_800h_4e',
    'https://imgservice.suning.cn/uimg1/b2c/image/JXkHz9tEPAaI2ShuLT2R2A.jpg_800w_800h_4e',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/9qb-GJ6U0FP9p96PMxNiag.jpg',
  ],
  redmik70: [
    'https://imgservice.suning.cn/uimg1/b2c/image/gEb2C8prSMIEbhhWa5BJgQ.png_800w_800h_4e',
    'https://imgservice.suning.cn/uimg1/b2c/image/mMsc8wFdhfO4TDq8EkCVRA.jpg_800w_800h_4e',
    'https://imgservice.suning.cn/uimg1/b2c/image/jbUfKiFFxm4uZlc52x7x5A.jpg_800w_800h_4e',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/3jUuVJv3wVOHFlw4rRo3jA.jpg',
  ],
  lenovo_xiaoxin: [
    'https://imgservice.suning.cn/uimg1/b2c/image/AZ5jErph7J3b5akNDXZDSw.jpg_800w_800h_4e',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/x3A2-b7amb3iYoXDl6u32Q.jpg',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/cHTp2fVK3w67hMvD2SglQA.jpg',
  ],
  macbookair: [
    'https://www.apple.com/newsroom/images/2024/03/apple-unveils-the-new-13-and-15-inch-macbook-air-with-the-powerful-m3-chip/article/Apple-MacBook-Air-2-up-hero-240304_big.jpg.large.jpg',
    'https://www.apple.com/newsroom/images/2024/03/apple-unveils-the-new-13-and-15-inch-macbook-air-with-the-powerful-m3-chip/article/Apple-MacBook-Air-2-up-front-240304_big.jpg.large.jpg',
    'https://www.apple.com/newsroom/images/2024/03/apple-unveils-the-new-13-and-15-inch-macbook-air-with-the-powerful-m3-chip/article/Apple-MacBook-Air-lifestyle-240304_big.jpg.large.jpg',
    'https://www.apple.com/newsroom/images/2024/03/apple-unveils-the-new-13-and-15-inch-macbook-air-with-the-powerful-m3-chip/article/Apple-MacBook-Air-keyboard-240304_big.jpg.large.jpg',
  ],
  matebookx: [
    'https://imgservice.suning.cn/uimg1/b2c/image/iWK-DbYNhbPmoh_CDhKioQ.png_800w_800h_4e',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/S__wB52dkjfYAahQ2LALMA.jpg',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/2DZycM_3G3qXjFxeo5-_0g.jpg',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/DGmRVdKdejOvJQtZenYTOw.jpg',
  ],
  airpodspro2: [
    'https://store.storeimages.cdn-apple.com/1/as-images.apple.com/is/MQD83?wid=2000&hei=2000&fmt=jpeg&qlt=95&.v=1661022070165',
    'https://store.storeimages.cdn-apple.com/1/as-images.apple.com/is/MQD83_AV1?wid=2000&hei=2000&fmt=jpeg&qlt=95&.v=1661022073165',
    'https://store.storeimages.cdn-apple.com/1/as-images.apple.com/is/MQD83_AV2?wid=2000&hei=2000&fmt=jpeg&qlt=95&.v=1661022071536',
    'https://store.storeimages.cdn-apple.com/1/as-images.apple.com/is/MQD83_AV5?wid=2000&hei=2000&fmt=jpeg&qlt=95&.v=1661022072882',
  ],
  mitvs75: [
    'https://imgservice.suning.cn/uimg1/b2c/image/KYkdF9cZXatuz_yrC_27Iw.jpg_800w_800h_4e',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/95-lCzICrdhuUq3cP4MjBQ.jpg',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/_LsuDAM0s-OPBjJmdzie5Q.jpg',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/XOKSPiQZkgozgXzyn2aHxA.jpg',
  ],
  gree_ac: [
    'https://imgservice.suning.cn/uimg1/b2c/image/NQWu9V70L3BVv6qx4Lp4zQ.png_800w_800h_4e',
    'https://uimgproxy.suning.cn/uimg1/sop/commodity/CXeM9YIjHiap4cFCugljeA.jpg',
    'https://imgservice.suning.cn/uimg1/b2c/image/EAOkA4dB_dcHt6gTskN8mQ.jpg',
  ],
};

function download(url) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    const req = client.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Referer': 'https://www.apple.com/',
      },
      timeout: 15000,
    }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        download(res.headers.location).then(resolve).catch(reject);
        return;
      }
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode} for ${url}`));
        return;
      }
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
  });
}

const FALLBACK_SVG = (name, price, category) => {
  const colors = {
    '手机': '#1a1a2e', '电脑': '#0f3460', '配件': '#533483', '家电': '#e94560',
  };
  const color = Object.entries(colors).find(([k]) => category?.startsWith(k))?.[1] || '#2d4059';
  const icon = { '手机': '📱', '电脑': '💻', '配件': '🎧', '家电': '🏠' };
  const emoji = Object.entries(icon).find(([k]) => category?.startsWith(k))?.[1] || '📦';
  return `<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
    <rect width="400" height="400" fill="${color}"/>
    <text x="200" y="170" font-size="80" text-anchor="middle" fill="rgba(255,255,255,0.12)" font-family="sans-serif">${emoji}</text>
    <text x="200" y="280" font-size="24" font-weight="bold" text-anchor="middle" fill="white" font-family="sans-serif">${name.length > 12 ? name.slice(0,12)+'…' : name}</text>
    <text x="200" y="340" font-size="20" text-anchor="middle" fill="#ffd700" font-family="sans-serif">¥${price}</text>
  </svg>`;
};

async function processImage(productKey, index, url, product) {
  const filename = `${productKey}_${index}.png`;
  const rawPath = path.join(RAWFILE_DIR, filename);
  const upPath = path.join(UPLOAD_DIR, filename);

  const catColors = {
    mate60pro: ['#1a1a2e','#16213e','#0f3460','#533483'],
    iphone15: ['#1a3a5c','#0d2137','#2d4059','#3b185f'],
    mi14ultra: ['#ff6900','#cc5500','#e94560','#c23152'],
    redmik70: ['#e94560','#c23152','#ff6900'],
    lenovo_xiaoxin: ['#005bac','#003d78','#0077b6'],
    macbookair: ['#555','#333','#2c3e50','#444'],
    matebookx: ['#cf0a2c','#8b071d','#a00b22','#cf0a2c'],
    airpodspro2: ['#533483','#3b185f','#6b3fa0','#4a2370'],
    mitvs75: ['#e94560','#c23152','#d4384a','#e94560'],
    gree_ac: ['#0077b6','#005082','#0096c7'],
  };

  try {
    const imgBuf = await download(url);
    await sharp(imgBuf)
      .resize(600, 600, { fit: 'inside', withoutEnlargement: true })
      .png()
      .toFile(rawPath);
    await sharp(rawPath).clone().toFile(upPath);
    return { filename, status: 'downloaded' };
  } catch (err) {
    const name = product.name || productKey;
    const price = product.price || 0;
    const category = product.category || '';
    const colors = catColors[productKey] || ['#2d4059','#1a1a2e'];
    const color = colors[(index - 1) % colors.length];
    const svg = `<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
      <rect width="400" height="400" fill="${color}"/>
      <text x="200" y="170" font-size="72" text-anchor="middle" fill="rgba(255,255,255,0.12)" font-family="sans-serif">📦</text>
      <text x="200" y="280" font-size="22" font-weight="bold" text-anchor="middle" fill="white" font-family="sans-serif">${name.length > 12 ? name.slice(0,12)+'…' : name}</text>
      <text x="200" y="320" font-size="13" text-anchor="middle" fill="rgba(255,255,255,0.5)" font-family="sans-serif">${'图片加载失败'}</text>
      <text x="200" y="360" font-size="18" text-anchor="middle" fill="#ffd700" font-family="sans-serif">¥${price}</text>
    </svg>`;
    await sharp(Buffer.from(svg)).png().toFile(rawPath);
    await sharp(rawPath).clone().toFile(upPath);
    return { filename, status: `fallback (${err.message.slice(0, 30)})` };
  }
}

async function main() {
  if (!fs.existsSync(RAWFILE_DIR)) fs.mkdirSync(RAWFILE_DIR, { recursive: true });
  if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

  const PRODUCT_META = {
    mate60pro: { name: '华为Mate60 Pro', price: 6999, category: '手机' },
    iphone15: { name: 'Apple iPhone 15', price: 7999, category: '手机' },
    mi14ultra: { name: '小米14 Ultra', price: 5999, category: '手机' },
    redmik70: { name: 'Redmi K70', price: 2499, category: '手机' },
    lenovo_xiaoxin: { name: '联想小新Pro 16', price: 5999, category: '电脑' },
    macbookair: { name: 'MacBook Air M3', price: 8999, category: '电脑' },
    matebookx: { name: '华为MateBook X Pro', price: 9999, category: '电脑' },
    airpodspro2: { name: 'AirPods Pro 2', price: 1899, category: '配件' },
    mitvs75: { name: '小米电视S75', price: 3999, category: '家电' },
    gree_ac: { name: '格力空调KFR-35GW', price: 3299, category: '家电' },
  };

  console.log('Downloading product images...\n');
  let success = 0, fail = 0;

  for (const [key, urls] of Object.entries(PRODUCT_IMAGES)) {
    const meta = PRODUCT_META[key];
    for (let i = 0; i < urls.length; i++) {
      const result = await processImage(key, i + 1, urls[i], meta);
      if (result.status === 'downloaded') {
        console.log(`  OK  ${result.filename}`);
        success++;
      } else {
        console.log(`  FALLBACK ${result.filename} (${result.status})`);
        fail++;
      }
    }
  }

  console.log(`\nDone! Downloaded: ${success}, Fallback: ${fail}`);
}

main().catch(err => { console.error('Fatal:', err.message); process.exit(1); });
