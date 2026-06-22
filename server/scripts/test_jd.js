// Test JD.com page access with different approaches
const https = require('https');
const http = require('http');
const zlib = require('zlib');

function fetchUrl(url, encoding = null) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith('https') ? https : http;
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Cache-Control': 'max-age=0'
      },
      timeout: 15000
    };
    
    // Only set encoding if not gzip (for raw buffer access)
    if (encoding) {
      options.headers['Accept-Encoding'] = encoding;
    }

    const req = mod.get(options, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        
        // Handle gzip if needed
        if (res.headers['content-encoding'] === 'gzip') {
          zlib.gunzip(buffer, (err, decompressed) => {
            if (err) reject(err);
            else resolve(decompressed.toString('utf8'));
          });
        } else if (res.headers['content-encoding'] === 'br') {
          zlib.brotliDecompress(buffer, (err, decompressed) => {
            if (err) reject(err);
            else resolve(decompressed.toString('utf8'));
          });
        } else {
          resolve(buffer.toString('utf8'));
        }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    req.end();
  });
}

async function main() {
  const testSkus = ['100105010052', '100204018751', '100026961629'];
  
  for (const sku of testSkus) {
    console.log(`\n=== Testing SKU ${sku} ===`);
    
    // Try different approaches
    const urls = [
      `https://item.jd.com/${sku}.html`,
      `https://item.m.jd.com/product/${sku}.html`,
      `http://item.jd.com/${sku}.html`
    ];
    
    for (const url of urls) {
      try {
        const html = await fetchUrl(url);
        console.log(`  ${url}: ${html.length} chars`);
        
        const hasImageList = html.includes('imageList');
        const hasJfs = html.includes('jfs/t');
        const hasCaptcha = html.includes('验证') || html.includes('top.webp') || html.includes('risk');
        const hasProduct = html.includes('海尔') || html.includes('product') || html.includes('wareId');
        
        console.log(`    imageList:${hasImageList} jfs:${hasJfs} captcha:${hasCaptcha} product:${hasProduct}`);
        
        // Try to find imageList
        const match = html.match(/imageList:\s*\[([^\]]+)\]/);
        if (match) {
          const imgs = match[1].match(/"([^"]+\.(?:jpg|jpeg|png))"/g) || [];
          console.log(`    FOUND imageList with ${imgs.length} images`);
          imgs.slice(0, 3).forEach(img => console.log(`      ${img.replace(/"/g, '')}`));
        }
        
        // Try to find any n1/n5 jfs paths
        const n1match = html.match(/n[15]\/jfs\/t\d+\/[^"';\s<>]+\.(?:jpg|jpeg|png)/g);
        if (n1match) {
          console.log(`    Found ${n1match.length} n1/n5 product images`);
          n1match.slice(0, 3).forEach(p => console.log(`      https://img10.360buyimg.com/${p}`));
        }
        
        // Try mobile specific patterns
        if (url.includes('m.jd.com')) {
          // Look for image CDN URLs
          const imgMatches = html.match(/\/\/img\d+\.360buyimg\.com\/[^"';\s<>]+\.(?:jpg|jpeg|png)/g);
          if (imgMatches) {
            const productImgs = imgMatches.filter(u => u.includes('/n') || !u.includes('imagetools'));
            console.log(`    Found ${imgMatches.length} CDN URLs, ${productImgs.length} likely product images`);
            productImgs.slice(0, 5).forEach(p => console.log(`      https:${p}`));
          }
        }
        
      } catch (e) {
        console.log(`  ${url}: ERROR - ${e.message}`);
      }
    }
  }
}

main().catch(console.error);
