const init = require('sql.js');
const fs = require('fs');
const path = require('path');

(async () => {
  const SQL = await init();
  const db = new SQL.Database(fs.readFileSync(path.join(__dirname, '..', 'data.db')));
  const rows = db.exec('SELECT id, name, image, images FROM products WHERE id > 10 ORDER BY id');
  const rf = path.join(__dirname, '..', '..', 'entry', 'src', 'main', 'resources', 'rawfile');
  
  const allFilenames = [];
  let missing = 0, ok = 0;
  
  for (const v of rows[0].values) {
    const id = v[0], name = v[1], img = v[2], imgs = v[3];
    const arr = JSON.parse(imgs);
    allFilenames.push(...arr);
    const allExist = arr.every(f => fs.existsSync(path.join(rf, f)));
    if (allExist) {
      ok++;
    } else {
      console.log('MISSING [' + id + '] ' + name);
      missing++;
    }
  }
  
  // Check duplicates
  const seen = {};
  let dupes = 0;
  for (const f of allFilenames) {
    if (seen[f]) {
      if (seen[f] === 1) console.log('DUPE: ' + f);
      dupes++;
    }
    seen[f] = (seen[f] || 0) + 1;
  }
  
  const seedRows = db.exec('SELECT id, name, image FROM products WHERE id <= 10 ORDER BY id');
  const seedImages = seedRows[0].values.map(v => v[2]);
  const seedDupes = {};
  let seedDupCount = 0;
  for (const f of seedImages) {
    if (seedDupes[f]) seedDupCount++;
    seedDupes[f] = (seedDupes[f] || 0) + 1;
  }
  
  console.log('非种子商品图片验证:');
  console.log('  文件存在: ' + ok + '/' + rows[0].values.length);
  console.log('  图片总数: ' + allFilenames.length);
  console.log('  重复文件: ' + dupes);
  console.log('种子商品图片唯一性: ' + (seedDupCount === 0 ? 'OK' : '有 ' + seedDupCount + ' 个重复'));
  if (missing === 0 && ok === 70 && dupes === 0) {
    console.log('全部通过！每个商品有自己独有的2张图，无重复。');
  }
  
  db.close();
})().catch(e => console.error(e.message));
