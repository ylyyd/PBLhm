/**
 * download_images.js - Download product images from JD.com CDN
 * 
 * Usage: node download_images.js <sku> <output_filename>
 * 
 * Fetches JD.com product page, extracts the first image from pageConfig.imageList,
 * and downloads it to the rawfile directory.
 */

const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

const RAWFILE_DIR = path.resolve(__dirname, '../../entry/src/main/resources/rawfile');

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith('https') ? https : http;
    mod.get(url, { 
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      timeout: 15000
    }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        const redirect = res.headers.location.startsWith('http') 
          ? res.headers.location 
          : new URL(res.headers.location, url).href;
        return fetchUrl(redirect).then(resolve).catch(reject);
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    }).on('error', reject);
  });
}

function extractImageList(html) {
  // Match imageList in pageConfig: imageList: ["jfs/t1/...","jfs/t1/..."]
  const match = html.match(/imageList:\s*\[([^\]]+)\]/);
  if (!match) return null;
  
  // JD uses double quotes: "jfs/t1/XXXX/XX/XXXX/XXXX.jpg"
  const items = match[1].match(/"([^"]+\.(?:jpg|jpeg|png))"/g);
  if (!items || items.length === 0) return null;
  
  return items.map(i => i.replace(/"/g, ''));
}

async function downloadFromJdSku(sku, outputFilename) {
  const url = `https://item.jd.com/${sku}.html`;
  console.log(`Fetching ${url}...`);
  
  try {
    const html = await fetchUrl(url);
    const htmlStr = html.toString('utf8');
    
    if (htmlStr.includes('验证') || htmlStr.includes('risk')) {
      console.log(`  ⚠ SKU ${sku}: Hit anti-scraping page`);
      return null;
    }
    
    const images = extractImageList(htmlStr);
    if (!images || images.length === 0) {
      console.log(`  ⚠ SKU ${sku}: No images found`);
      return null;
    }
    
    const firstImage = images[0];
    // Try multiple CDN hosts
    const cdnHosts = [
      'img10.360buyimg.com',
      'img14.360buyimg.com', 
      'img13.360buyimg.com',
      'img11.360buyimg.com'
    ];
    
    for (const host of cdnHosts) {
      const imageUrl = `https://${host}/n1/${firstImage}`;
      console.log(`  Downloading ${imageUrl}...`);
      
      try {
        const imgData = await fetchUrl(imageUrl);
        if (imgData.length > 2000) {
          const outPath = path.join(RAWFILE_DIR, outputFilename);
          fs.writeFileSync(outPath, imgData);
          console.log(`  ✅ Saved ${outPath} (${(imgData.length/1024).toFixed(1)} KB)`);
          return imgData.length;
        }
      } catch (e) {
        // Try next CDN host
        continue;
      }
    }
    
    console.log(`  ⚠ SKU ${sku}: Failed on all CDN hosts`);
    return null;
  } catch (e) {
    console.log(`  ❌ SKU ${sku}: ${e.message}`);
    return null;
  }
}

// Main - process command line args or batch file
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length >= 2) {
    // Single SKU mode
    const [sku, outputFilename] = args;
    await downloadFromJdSku(sku, outputFilename);
  } else if (args.length === 1 && fs.existsSync(args[0])) {
    // Batch mode: read CSV file with sku,outputFilename lines
    const batchFile = args[0];
    const lines = fs.readFileSync(batchFile, 'utf8').trim().split('\n').filter(l => l.trim());
    
    console.log(`Batch processing ${lines.length} products...\n`);
    
    for (const line of lines) {
      const [sku, outputFile] = line.split(',').map(s => s.trim());
      if (sku && outputFile) {
        await downloadFromJdSku(sku, outputFile);
        // Small delay between requests
        await new Promise(r => setTimeout(r, 1000));
      }
    }
  } else {
    console.log('Usage:');
    console.log('  node download_images.js <sku> <output_filename>');
    console.log('  node download_images.js <batch_csv_file>');
    console.log('');
    console.log('Batch CSV format: sku,output_filename.png');
    console.log('Example: 10068469442135,p_海尔滚筒洗衣机_1.png');
  }
}

main().catch(console.error);
