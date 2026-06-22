const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');
(async () => {
  const SQL = await initSqlJs();
  const buf = fs.readFileSync(path.join(__dirname, 'data.db'));
  const db = new SQL.Database(buf);
  
  console.log('=== All Categories ===');
  let st = db.prepare('SELECT * FROM categories ORDER BY id');
  while (st.step()) console.log(JSON.stringify(st.getAsObject()));
  st.free();
  
  console.log('\n=== Product categories (distinct) ===');
  st = db.prepare("SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != '' ORDER BY category");
  while (st.step()) console.log(st.getAsObject().category);
  st.free();
  
  console.log('\n=== Products count ===');
  st = db.prepare('SELECT COUNT(*) as c FROM products');
  st.step();
  console.log(st.getAsObject().c + ' products');
  st.free();
  
  db.close();
})();
