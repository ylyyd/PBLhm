const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');
(async () => {
  const SQL = await initSqlJs();
  const buf = fs.readFileSync(path.join(__dirname, 'data.db'));
  const db = new SQL.Database(buf);
  
  console.log('=== Categories Table (' + db.exec("SELECT COUNT(*) as c FROM categories")[0].values[0][0] + ' rows) ===');
  let st = db.prepare('SELECT id, name, parent_id, level, full_path FROM categories ORDER BY level, sort_order, id');
  while (st.step()) console.log(JSON.stringify(st.getAsObject()));
  st.free();
  
  db.close();
})();
