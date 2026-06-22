const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

(async () => {
  const SQL = await initSqlJs();
  const buf = fs.readFileSync(path.join(__dirname, 'data.db'));
  const db = new SQL.Database(buf);

  console.log('=== Tables ===');
  let st = db.prepare("SELECT name FROM sqlite_master WHERE type='table'");
  while (st.step()) { console.log(' ', st.getAsObject().name); }
  st.free();

  console.log('\n=== User count ===');
  st = db.prepare('SELECT COUNT(*) as c FROM users');
  st.step();
  console.log(' ', st.getAsObject().c, 'users');
  st.free();

  if (st.getAsObject) {}

  console.log('\n=== Users ===');
  st = db.prepare('SELECT id, username, address FROM users');
  let count = 0;
  while (st.step()) { console.log(' ', JSON.stringify(st.getAsObject())); count++; }
  st.free();
  if (count === 0) console.log(' (no users registered)');

  console.log('\n=== Orders ===');
  st = db.prepare('SELECT order_number, username, total_price, status, create_time FROM orders ORDER BY create_time DESC');
  count = 0;
  while (st.step()) { console.log(' ', JSON.stringify(st.getAsObject())); count++; }
  st.free();
  if (count === 0) console.log(' (no orders)');

  console.log('\n=== Products count ===');
  st = db.prepare('SELECT COUNT(*) as c FROM products');
  st.step();
  console.log(' ', st.getAsObject().c, 'products');
  st.free();

  console.log('\nDone');
})();
