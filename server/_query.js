const init = require('sql.js');
const fs = require('fs');
(async () => {
  const SQL = await init();
  const buf = fs.readFileSync('data.db');
  const db = new SQL.Database(buf);
  const r = db.exec("SELECT DISTINCT username FROM orders");
  console.log('Users:', JSON.stringify(r, null, 2));
  const r2 = db.exec("SELECT order_number, username, status, receive_time, create_time FROM orders ORDER BY create_time DESC LIMIT 20");
  console.log('Orders:', JSON.stringify(r2, null, 2));
  db.close();
})();
