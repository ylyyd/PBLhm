// Batch download product images from Suning.com
const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const querystring = require('querystring');

const RAWFILE_DIR = path.resolve(__dirname, '../../entry/src/main/resources/rawfile');
const MIN_GOOD_SIZE = 20000; // 20KB minimum for a real image

// Helper: fetch URL and return body as string
function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    const isHttps = url.startsWith('https');
    const mod = isHttps ? https : http;
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate'
      },
      timeout: 15000
    };

    const req = mod.get(options, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        const encoding = res.headers['content-encoding'];
        if (encoding === 'gzip') {
          zlib.gunzip(buffer, (err, data) => err ? reject(err) : resolve(data.toString('utf8')));
        } else if (encoding === 'deflate') {
          zlib.inflate(buffer, (err, data) => err ? reject(err) : resolve(data.toString('utf8')));
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

// Helper: download binary data
function downloadBinary(url) {
  return new Promise((resolve, reject) => {
    const isHttps = url.startsWith('https');
    const mod = isHttps ? https : http;
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://product.suning.com/'
      },
      timeout: 30000
    };

    const req = mod.get(options, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    req.end();
  });
}

// Search Suning for a product and return first product page URL
async function searchSuning(productName) {
  const encoded = encodeURIComponent(productName);
  const url = `https://search.suning.com/${encoded}/`;
  
  try {
    const html = await fetchUrl(url);
    
    // Look for product URLs matching product.suning.com
    const regex = /\/\/product\.suning\.com\/[^"'\s<>]+\.html/g;
    const matches = html.match(regex);
    
    if (matches && matches.length > 0) {
      // Return first unique URL (avoid duplicates with # anchors)
      for (const match of matches) {
        if (!match.includes('#')) {
          return 'https:' + match;
        }
      }
      return 'https:' + matches[0].split('#')[0];
    }
    return null;
  } catch (e) {
    console.error(`  Search error for "${productName}": ${e.message}`);
    return null;
  }
}

// Extract src2 image URLs from Suning product page
function extractSuningImages(html) {
  const images = new Set();
  
  // Pattern 1: src2="url" (lazy loaded)
  const src2Regex = /src2="([^"]+\.(?:jpg|jpeg|png))"/g;
  let match;
  while ((match = src2Regex.exec(html)) !== null) {
    let url = match[1];
    if (url.startsWith('//')) url = 'https:' + url;
    if (url.startsWith('/')) url = 'https://product.suning.com' + url;
    images.add(url);
  }
  
  // Pattern 2: direct uimgproxy/suning CDN URLs
  const cdnRegex = /(?:https?:)?\/\/uimgproxy\.suning\.cn\/uimg[^"'\s<>]+\.(?:jpg|jpeg|png)/g;
  while ((match = cdnRegex.exec(html)) !== null) {
    let url = match[0];
    if (url.startsWith('//')) url = 'https:' + url;
    images.add(url);
  }
  
  // Pattern 3: imgservice.suning.cn
  const cdn2Regex = /(?:https?:)?\/\/imgservice\.suning\.cn\/uimg[^"'\s<>]+\.(?:jpg|jpeg|png)/g;
  while ((match = cdn2Regex.exec(html)) !== null) {
    let url = match[0];
    if (url.startsWith('//')) url = 'https:' + url;
    images.add(url);
  }
  
  return Array.from(images);
}

// Get product images from Suning product page
async function getImagesFromSuning(pageUrl) {
  try {
    const html = await fetchUrl(pageUrl);
    const images = extractSuningImages(html);
    console.log(`    Found ${images.length} images on page`);
    return images;
  } catch (e) {
    console.error(`    Page fetch error: ${e.message}`);
    return [];
  }
}

// Download and save image
async function saveImage(imageUrl, outputPath) {
  try {
    const data = await downloadBinary(imageUrl);
    fs.writeFileSync(outputPath, data);
    const sizeKB = Math.round(data.length / 1024);
    return { success: true, sizeKB };
  } catch (e) {
    return { success: false, error: e.message };
  }
}

// Map of known product names to Suning product URLs (to avoid searching)
const KNOWN_SUNING_URLS = {
  // These are from the previous successful Suning tests
  '科沃斯扫地机器人': 'https://product.suning.com/0000000000/12358438244.html',
};

// Main function
async function main() {
  console.log('=== Suning Batch Product Image Downloader ===\n');
  
  // Read all p_*1.png files
  const files = fs.readdirSync(RAWFILE_DIR)
    .filter(f => f.startsWith('p_') && f.endsWith('_1.png'))
    .sort();
  
  console.log(`Total product files: ${files.length}`);
  
  // Process small files (placeholders)
  let processed = 0;
  let succeeded = 0;
  let failed = 0;
  let skipped = 0;
  
  for (const file of files) {
    const filePath = path.join(RAWFILE_DIR, file);
    const stat = fs.statSync(filePath);
    const sizeKB = Math.round(stat.size / 1024);
    
    if (stat.size >= MIN_GOOD_SIZE) {
      skipped++;
      continue; // Skip already-real images
    }
    
    processed++;
    
    // Extract product name from filename
    // Format: p_{PRODUCT_NAME}_{TIMESTAMP}_{N}.png
    const nameMatch = file.match(/^p_(.+?)_\d+_\d+\.png$/);
    if (!nameMatch) {
      console.log(`[${processed}] Cannot parse name from: ${file}`);
      failed++;
      continue;
    }
    
    const productName = nameMatch[1];
    const outputFile1 = file; // Keep same name for _1
    const outputFile2 = file.replace('_1.png', '_2.png'); // Corresponding _2
    const outputPath1 = path.join(RAWFILE_DIR, outputFile1);
    const outputPath2 = path.join(RAWFILE_DIR, outputFile2);
    
    // Get the _2 file too so we know what to save
    const hasFile2 = fs.existsSync(outputPath2);
    
    console.log(`\n[${processed}/${files.length}] ${productName} (${sizeKB}KB)`);
    
    // Find product page URL
    let pageUrl = KNOWN_SUNING_URLS[productName];
    if (!pageUrl) {
      console.log(`  Searching Suning for "${productName}"...`);
      pageUrl = await searchSuning(productName);
    }
    
    if (!pageUrl) {
      console.log(`  No Suning page found, trying web search...`);
      // As final fallback, try web search - but we skip for now
      console.log(`  SKIPPED - no Suning product found`);
      failed++;
      continue;
    }
    
    console.log(`  Page: ${pageUrl}`);
    
    // Get images from product page
    const images = await getImagesFromSuning(pageUrl);
    
    if (images.length === 0) {
      console.log(`  No images found on page`);
      failed++;
      continue;
    }
    
    // Filter out small/icon images
    const mainImages = images.filter(u => !u.includes('80x80') && !u.includes('s80'));
    const imageToUse = mainImages.length > 0 ? mainImages[0] : images[0];
    
    console.log(`  Downloading: ${imageToUse.substring(0, 100)}...`);
    
    // Download _1 image
    const result1 = await saveImage(imageToUse, outputPath1);
    if (result1.success) {
      console.log(`  Saved _1: ${result1.sizeKB}KB`);
      succeeded++;
      
      // Try to download _2 as well (different angle)
      if (images.length > 1) {
        const img2 = (mainImages.length > 1 ? mainImages[1] : (images.length > 1 ? images[1] : null));
        if (img2) {
          const result2 = await saveImage(img2, outputPath2);
          if (result2.success) {
            console.log(`  Saved _2: ${result2.sizeKB}KB`);
          }
        }
      }
    } else {
      console.log(`  FAILED: ${result1.error}`);
      failed++;
    }
  }
  
  console.log(`\n=== Done ===`);
  console.log(`Processed: ${processed}, Succeeded: ${succeeded}, Failed: ${failed}, Skipped: ${skipped}`);
}

main().catch(console.error);
