const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');
const logger = require('./logger');

const DB_PATH = path.join(__dirname, '..', 'data.db');
let db = null;
let SQL = null;
let saveTimeout = null;

function saveDb(sync = false) {
  if (!db) return;
  const doSave = () => {
    try {
      const data = db.export();
      fs.writeFileSync(DB_PATH, Buffer.from(data));
    } catch (err) {
      logger.error('Failed to save database: ' + err.message);
    }
  };
  if (sync) {
    if (saveTimeout) clearTimeout(saveTimeout);
    doSave();
    saveTimeout = null;
  } else {
    if (saveTimeout) clearTimeout(saveTimeout);
    saveTimeout = setTimeout(doSave, 200);
  }
}

let inBatch = false;

function run(sql, params = []) {
  db.run(sql, params);
  if (!inBatch) saveDb();
}

function get(sql, params = []) {
  const stmt = db.prepare(sql);
  stmt.bind(params);
  let row = null;
  if (stmt.step()) row = stmt.getAsObject();
  stmt.free();
  return row;
}

function all(sql, params = []) {
  const stmt = db.prepare(sql);
  stmt.bind(params);
  const rows = [];
  while (stmt.step()) rows.push(stmt.getAsObject());
  stmt.free();
  return rows;
}

function exec(sql) {
  db.exec(sql);
  saveDb();
}

function batch(operations) {
  inBatch = true;
  db.run('BEGIN');
  try {
    operations();
    db.run('COMMIT');
    saveDb();
  } catch (err) {
    db.run('ROLLBACK');
    throw err;
  } finally {
    inBatch = false;
  }
}

async function getDb() {
  if (db) return { db, run, get, all, exec, batch };

  SQL = await initSqlJs();

  if (fs.existsSync(DB_PATH)) {
    const buffer = fs.readFileSync(DB_PATH);
    db = new SQL.Database(buffer);
  } else {
    db = new SQL.Database();
  }

  runMigrations();
  seedData();
  saveDb(true); // sync initial save before server starts

  return { db, run, get, all, exec, batch };
}

const MIGRATIONS = [
  {
    version: 1,
    name: 'initial_schema',
    up: () => {
      exec(`
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          nickname TEXT DEFAULT '',
          avatar TEXT DEFAULT '',
          phone TEXT DEFAULT '',
          address TEXT DEFAULT '',
          points INTEGER DEFAULT 0,
          member_level INTEGER DEFAULT 0,
          created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS shops (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT DEFAULT '',
          logo TEXT DEFAULT '',
          owner_username TEXT NOT NULL UNIQUE,
          created_at TEXT DEFAULT '',
          status TEXT DEFAULT 'active',
          followers INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          image TEXT,
          images TEXT DEFAULT '[]',
          description TEXT,
          detail_html TEXT DEFAULT '',
          category TEXT,
          specs TEXT DEFAULT '[]',
          skus TEXT DEFAULT '[]',
          shop_id INTEGER DEFAULT 0,
          stock INTEGER DEFAULT 999,
          sales_count INTEGER DEFAULT 0,
          video_url TEXT DEFAULT '',
          status TEXT DEFAULT 'active',
          created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS cart_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          product_id INTEGER NOT NULL,
          quantity INTEGER DEFAULT 1,
          sku_id TEXT DEFAULT '',
          sku_desc TEXT DEFAULT '',
          selected INTEGER DEFAULT 1,
          UNIQUE(username, product_id, sku_id)
        );

        CREATE TABLE IF NOT EXISTS orders (
          order_number TEXT PRIMARY KEY,
          username TEXT NOT NULL,
          total_price REAL,
          create_time TEXT,
          status TEXT DEFAULT '待付款',
          address TEXT,
          cancel_reason TEXT DEFAULT '',
          pay_method TEXT DEFAULT '',
          pay_time TEXT DEFAULT '',
          tracking_number TEXT DEFAULT '',
          express_company TEXT DEFAULT '',
          estimated_delivery TEXT DEFAULT '',
          ship_time TEXT DEFAULT '',
          receive_time TEXT DEFAULT '',
          payment_deadline TEXT DEFAULT '',
          payment_token TEXT DEFAULT '',
          shipping_fee REAL DEFAULT 0,
          coupon_id INTEGER DEFAULT 0,
          discount_amount REAL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS order_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_number TEXT,
          product_id INTEGER,
          product_name TEXT,
          product_price REAL,
          product_image TEXT,
          quantity INTEGER,
          sku_id TEXT DEFAULT '',
          sku_desc TEXT DEFAULT ''
        );

        CREATE TABLE IF NOT EXISTS reviews (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER,
          username TEXT,
          rating INTEGER DEFAULT 5 CHECK(rating >= 1 AND rating <= 5),
          date TEXT,
          comment TEXT,
          images TEXT DEFAULT '[]',
          order_number TEXT DEFAULT '',
          is_deleted INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS favorites (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          product_id INTEGER NOT NULL,
          created_at TEXT DEFAULT (datetime('now')),
          UNIQUE(username, product_id)
        );

        CREATE TABLE IF NOT EXISTS addresses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          label TEXT NOT NULL,
          recipient_name TEXT NOT NULL DEFAULT '',
          phone TEXT NOT NULL DEFAULT '',
          detail TEXT NOT NULL,
          is_default INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS after_sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_number TEXT NOT NULL,
          username TEXT NOT NULL,
          product_id INTEGER DEFAULT 0,
          type TEXT NOT NULL DEFAULT 'refund',
          reason TEXT DEFAULT '',
          image_evidence TEXT DEFAULT '',
          status TEXT DEFAULT 'pending',
          apply_time TEXT DEFAULT '',
          process_time TEXT DEFAULT '',
          process_note TEXT DEFAULT '',
          return_tracking TEXT DEFAULT '',
          refund_amount REAL DEFAULT 0,
          order_status TEXT DEFAULT ''
        );

        CREATE TABLE IF NOT EXISTS messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          order_number TEXT DEFAULT '',
          type TEXT NOT NULL DEFAULT 'system',
          title TEXT NOT NULL,
          content TEXT DEFAULT '',
          is_read INTEGER DEFAULT 0,
          created_at TEXT DEFAULT ''
        );

        CREATE TABLE IF NOT EXISTS search_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          keyword TEXT NOT NULL,
          created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS browsing_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          product_id INTEGER NOT NULL,
          created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS product_questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          username TEXT NOT NULL,
          content TEXT NOT NULL,
          reply TEXT DEFAULT '',
          reply_time TEXT DEFAULT '',
          created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS coupons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'direct',
          value REAL NOT NULL,
          min_amount REAL DEFAULT 0,
          start_time TEXT DEFAULT '',
          end_time TEXT DEFAULT '',
          total_count INTEGER DEFAULT 100,
          used_count INTEGER DEFAULT 0,
          per_user_limit INTEGER DEFAULT 1,
          status TEXT DEFAULT 'active',
          created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS user_coupons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          coupon_id INTEGER NOT NULL,
          used INTEGER DEFAULT 0,
          used_time TEXT DEFAULT '',
          order_number TEXT DEFAULT '',
          created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS shop_follows (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          shop_id INTEGER NOT NULL,
          created_at TEXT DEFAULT (datetime('now')),
          UNIQUE(username, shop_id)
        );

        CREATE TABLE IF NOT EXISTS invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          order_number TEXT NOT NULL,
          type TEXT DEFAULT 'personal',
          title TEXT DEFAULT '',
          tax_id TEXT DEFAULT '',
          email TEXT DEFAULT '',
          amount REAL DEFAULT 0,
          status TEXT DEFAULT 'pending',
          created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS migrations (
          version INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          applied_at TEXT DEFAULT (datetime('now'))
        );
      `);
    }
  },
  {
    version: 2,
    name: 'add_user_fields',
    up: () => {
      const cols = all("PRAGMA table_info('users')").map(c => c.name);
      const addCol = (col, def) => { if (!cols.includes(col)) exec(`ALTER TABLE users ADD COLUMN ${col} ${def}`); };
      addCol('nickname', "TEXT DEFAULT ''");
      addCol('avatar', "TEXT DEFAULT ''");
      addCol('phone', "TEXT DEFAULT ''");
      addCol('points', 'INTEGER DEFAULT 0');
      addCol('member_level', 'INTEGER DEFAULT 0');
      addCol('created_at', "TEXT DEFAULT (datetime('now'))");
    }
  },
  {
    version: 3,
    name: 'add_product_fields',
    up: () => {
      const cols = all("PRAGMA table_info('products')").map(c => c.name);
      const addCol = (col, def) => { if (!cols.includes(col)) exec(`ALTER TABLE products ADD COLUMN ${col} ${def}`); };
      addCol('sales_count', 'INTEGER DEFAULT 0');
      addCol('video_url', "TEXT DEFAULT ''");
      addCol('status', "TEXT DEFAULT 'active'");
      addCol('created_at', "TEXT DEFAULT (datetime('now'))");
    }
  },
  {
    version: 4,
    name: 'add_order_fields',
    up: () => {
      const cols = all("PRAGMA table_info('orders')").map(c => c.name);
      const addCol = (col, def) => { if (!cols.includes(col)) exec(`ALTER TABLE orders ADD COLUMN ${col} ${def}`); };
      addCol('shipping_fee', 'REAL DEFAULT 0');
      addCol('coupon_id', 'INTEGER DEFAULT 0');
      addCol('discount_amount', 'REAL DEFAULT 0');
    }
  },
  {
    version: 5,
    name: 'add_cart_selected',
    up: () => {
      const cols = all("PRAGMA table_info('cart_items')").map(c => c.name);
      if (!cols.includes('selected')) exec('ALTER TABLE cart_items ADD COLUMN selected INTEGER DEFAULT 1');
    }
  },
  {
    version: 6,
    name: 'add_shop_followers',
    up: () => {
      const cols = all("PRAGMA table_info('shops')").map(c => c.name);
      if (!cols.includes('followers')) exec('ALTER TABLE shops ADD COLUMN followers INTEGER DEFAULT 0');
    }
  },
  {
    version: 7,
    name: 'add_review_images',
    up: () => {
      const cols = all("PRAGMA table_info('reviews')").map(c => c.name);
      if (!cols.includes('images')) exec("ALTER TABLE reviews ADD COLUMN images TEXT DEFAULT '[]'");
    }
  },
  {
    version: 8,
    name: 'add_favorites_created_at',
    up: () => {
      const cols = all("PRAGMA table_info('favorites')").map(c => c.name);
      if (!cols.includes('created_at')) exec("ALTER TABLE favorites ADD COLUMN created_at TEXT DEFAULT (datetime('now'))");
    }
  },
  {
    version: 9,
    name: 'add_users_address',
    up: () => {
      const cols = all("PRAGMA table_info('users')").map(c => c.name);
      if (!cols.includes('address')) exec("ALTER TABLE users ADD COLUMN address TEXT DEFAULT ''");
    }
  },
  {
    version: 10,
    name: 'add_user_fields_v2',
    up: () => {
      const cols = all("PRAGMA table_info('users')").map(c => c.name);
      const addCol = (col, def) => { if (!cols.includes(col)) exec(`ALTER TABLE users ADD COLUMN ${col} ${def}`); };
      addCol('gender', "TEXT DEFAULT '保密'");
      addCol('age', 'INTEGER DEFAULT 0');
      addCol('payment_password_hash', "TEXT DEFAULT ''");
    }
  },
  {
    version: 11,
    name: 'add_admin_role',
    up: () => {
      const cols = all("PRAGMA table_info('users')").map(c => c.name);
      if (!cols.includes('is_admin')) {
        exec("ALTER TABLE users ADD COLUMN is_admin INTEGER DEFAULT 0");
      }
    }
  },
  {
    version: 12,
    name: 'add_view_count_and_audit_log',
    up: () => {
      const productCols = all("PRAGMA table_info('products')").map(c => c.name);
      if (!productCols.includes('view_count')) {
        exec("ALTER TABLE products ADD COLUMN view_count INTEGER DEFAULT 0");
      }
      exec(`
        CREATE TABLE IF NOT EXISTS admin_audit_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          action TEXT NOT NULL,
          target_type TEXT NOT NULL,
          target_id TEXT DEFAULT '',
          detail TEXT DEFAULT '',
          ip TEXT DEFAULT '',
          created_at TEXT DEFAULT (datetime('now'))
        )
      `);
    }
  },
  {
    version: 13,
    name: 'create_categories_table',
    up: () => {
      exec(`
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          parent_id INTEGER DEFAULT 0,
          level INTEGER DEFAULT 1,
          full_path TEXT NOT NULL,
          sort_order INTEGER DEFAULT 0,
          icon TEXT DEFAULT '',
          created_at TEXT DEFAULT (datetime('now'))
        )
      `);
    }
  },
  {
    version: 14,
    name: 'seed_categories_from_products',
    up: () => {
      const rows = all("SELECT DISTINCT category FROM products WHERE category != '' ORDER BY category");
      const seen = {};
      const inserts = [];
      for (const r of rows) {
        const parts = r.category.split('>');
        let full = '';
        for (let i = 0; i < parts.length; i++) {
          const name = parts[i].trim();
          if (!name) continue;
          full = full ? full + '>' + name : name;
          if (!seen[full]) {
            seen[full] = true;
            inserts.push({ name, full, level: i + 1 });
          }
        }
      }
      const stmt = db.prepare('INSERT OR IGNORE INTO categories (name, full_path, level, sort_order) VALUES (?, ?, ?, ?)');
      let order = 0;
      for (const ins of inserts) {
        stmt.bind([ins.name, ins.full, ins.level, order++]);
        stmt.step();
        stmt.reset();
      }
      stmt.free();
      const allCats = all('SELECT id, full_path, level FROM categories');
      for (const cat of allCats) {
        if (cat.level > 1) {
          const idx = cat.full_path.lastIndexOf('>');
          const parentPath = cat.full_path.substring(0, idx);
          const parent = allCats.find(c => c.full_path === parentPath);
          if (parent) {
            run('UPDATE categories SET parent_id = ? WHERE id = ?', [parent.id, cat.id]);
          }
        }
      }
    }
  },
];

function runMigrations() {
  const versionRow = get('PRAGMA user_version');
  const version = versionRow ? versionRow.user_version : 0;
  const applied = version;

  for (const m of MIGRATIONS) {
    if (m.version > applied) {
      logger.info(`Running migration v${m.version}: ${m.name}`);
      try {
        m.up();
        exec(`PRAGMA user_version = ${m.version}`);
        logger.info(`Migration v${m.version} completed`);
      } catch (err) {
        logger.error(`Migration v${m.version} failed: ${err.message}`);
      }
    }
  }
}

function seedData() {
  const row = get('SELECT COUNT(*) as c FROM users');
  if (row.c > 0) return;

  const bcrypt = require('bcryptjs');
  const hash = bcrypt.hashSync('admin123', 10);
  run('INSERT INTO users (username, password_hash, nickname, is_admin) VALUES (?, ?, ?, ?)', ['admin', hash, '管理员', 1]);
  run('INSERT INTO users (username, password_hash, nickname, is_admin) VALUES (?, ?, ?, ?)', ['test', bcrypt.hashSync('123456', 10), '测试用户', 0]);

  const now = new Date().toISOString();
  run('INSERT INTO shops (id, name, description, logo, owner_username, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [1, '开心数码旗舰店', '官方自营数码旗舰店，正品保障，极速发货', '', 'admin', now]);
  run('INSERT INTO shops (id, name, description, logo, owner_username, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [2, '小米官方旗舰店', '小米集团官方旗舰店，专注智能硬件与电子产品', '', 'xiaomi_shop', now]);
  run('INSERT INTO shops (id, name, description, logo, owner_username, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [3, '品质家电专卖', '品牌家电直销，全国联保，售后无忧', '', 'appliance_shop', now]);

  const products = [
    { id: 1, name: '华为Mate60 Pro', price: 6999, image: 'mate60pro_1.png', images: JSON.stringify(['mate60pro_1.png','mate60pro_2.png','mate60pro_3.png','mate60pro_4.png']), category: '手机>华为', shop_id: 1, stock: 100, description: '华为旗舰手机，搭载自研麒麟9000S芯片，支持卫星通话，昆仑玻璃面板',
      specs: JSON.stringify([{name:'颜色',values:['雅丹黑','白沙银','雅川青']},{name:'存储',values:['256GB','512GB','1TB']}]),
      skus: JSON.stringify([{id:'mate60pro-black-256',specs:{'颜色':'雅丹黑','存储':'256GB'},price:6999,stock:50},{id:'mate60pro-black-512',specs:{'颜色':'雅丹黑','存储':'512GB'},price:7999,stock:30},{id:'mate60pro-white-256',specs:{'颜色':'白沙银','存储':'256GB'},price:6999,stock:40},{id:'mate60pro-green-512',specs:{'颜色':'雅川青','存储':'512GB'},price:7999,stock:20}]) },
    { id: 2, name: 'Apple iPhone 15', price: 7999, image: 'iphone15_1.png', images: JSON.stringify(['iphone15_1.png','iphone15_2.png','iphone15_3.png','iphone15_4.png']), category: '手机>iPhone', shop_id: 1, stock: 200, description: '苹果最新款智能手机，A16仿生芯片，4800万像素主摄，灵动岛交互',
      specs: JSON.stringify([{name:'颜色',values:['黑色','粉色','黄色','绿色','蓝色']},{name:'存储',values:['128GB','256GB','512GB']}]),
      skus: JSON.stringify([{id:'iphone15-black-128',specs:{'颜色':'黑色','存储':'128GB'},price:7999,stock:100},{id:'iphone15-black-256',specs:{'颜色':'黑色','存储':'256GB'},price:8999,stock:60},{id:'iphone15-pink-128',specs:{'颜色':'粉色','存储':'128GB'},price:7999,stock:80},{id:'iphone15-blue-512',specs:{'颜色':'蓝色','存储':'512GB'},price:10999,stock:20}]) },
    { id: 3, name: '小米14 Ultra', price: 5999, image: 'mi14ultra_1.png', images: JSON.stringify(['mi14ultra_1.png','mi14ultra_2.png','mi14ultra_3.png','mi14ultra_4.png']), category: '手机>小米', shop_id: 2, stock: 100, description: '骁龙8Gen3处理器，徕卡光学镜头，2K AMOLED屏幕',
      specs: JSON.stringify([{name:'颜色',values:['黑色','白色']},{name:'存储',values:['256GB','512GB']}]),
      skus: JSON.stringify([{id:'mi14u-black-256',specs:{'颜色':'黑色','存储':'256GB'},price:5999,stock:60},{id:'mi14u-black-512',specs:{'颜色':'黑色','存储':'512GB'},price:6499,stock:30},{id:'mi14u-white-256',specs:{'颜色':'白色','存储':'256GB'},price:5999,stock:50}]) },
    { id: 4, name: 'Redmi K70', price: 2499, image: 'redmik70_1.png', images: JSON.stringify(['redmik70_1.png','redmik70_2.png','redmik70_3.png']), category: '手机>小米', shop_id: 2, stock: 200, description: '骁龙8Gen2芯片，2K直屏，120W快充，性价比之王',
      specs: JSON.stringify([{name:'颜色',values:['晴雪','墨羽','浅茗']},{name:'存储',values:['12+256GB','16+512GB']}]),
      skus: JSON.stringify([{id:'k70-white-256',specs:{'颜色':'晴雪','存储':'12+256GB'},price:2499,stock:80},{id:'k70-black-256',specs:{'颜色':'墨羽','存储':'12+256GB'},price:2499,stock:70},{id:'k70-black-512',specs:{'颜色':'墨羽','存储':'16+512GB'},price:2999,stock:50}]) },
    { id: 5, name: '联想小新Pro 16', price: 5999, image: 'lenovo_xiaoxin_1.png', images: JSON.stringify(['lenovo_xiaoxin_1.png','lenovo_xiaoxin_2.png','lenovo_xiaoxin_3.png']), category: '电脑>联想', shop_id: 1, stock: 80, description: '高性能轻薄本，16英寸2.5K大屏，i7处理器',
      specs: JSON.stringify([{name:'配置',values:['i5+16GB','i7+16GB','i7+32GB']}]),
      skus: JSON.stringify([{id:'xiaoxin-i5-16',specs:{'配置':'i5+16GB'},price:5999,stock:30},{id:'xiaoxin-i7-16',specs:{'配置':'i7+16GB'},price:6999,stock:30},{id:'xiaoxin-i7-32',specs:{'配置':'i7+32GB'},price:7999,stock:20}]) },
    { id: 6, name: 'MacBook Air M3', price: 8999, image: 'macbookair_1.png', images: JSON.stringify(['macbookair_1.png','macbookair_2.png','macbookair_3.png','macbookair_4.png']), category: '电脑>苹果', shop_id: 1, stock: 60, description: 'M3芯片，13.6英寸Liquid Retina显示屏，18小时续航',
      specs: JSON.stringify([{name:'颜色',values:['午夜色','星光色','深空灰','银色']},{name:'内存',values:['8GB','16GB','24GB']}]),
      skus: JSON.stringify([{id:'m3-midnight-8',specs:{'颜色':'午夜色','内存':'8GB'},price:8999,stock:20},{id:'m3-starlight-16',specs:{'颜色':'星光色','内存':'16GB'},price:10999,stock:25},{id:'m3-silver-24',specs:{'颜色':'银色','内存':'24GB'},price:12999,stock:15}]) },
    { id: 7, name: '华为MateBook X Pro', price: 9999, image: 'matebookx_1.png', images: JSON.stringify(['matebookx_1.png','matebookx_2.png','matebookx_3.png','matebookx_4.png']), category: '电脑>华为', shop_id: 1, stock: 40, description: '3.1K OLED原色屏，超级终端，酷睿Ultra处理器',
      specs: JSON.stringify([{name:'颜色',values:['砚黑','皓月银','拂晓粉']},{name:'配置',values:['Ultra5+16GB','Ultra7+16GB','Ultra7+32GB']}]),
      skus: JSON.stringify([{id:'matebookx-black-u5',specs:{'颜色':'砚黑','配置':'Ultra5+16GB'},price:9999,stock:15},{id:'matebookx-silver-u7',specs:{'颜色':'皓月银','配置':'Ultra7+16GB'},price:11999,stock:15},{id:'matebookx-pink-u7-32',specs:{'颜色':'拂晓粉','配置':'Ultra7+32GB'},price:13999,stock:10}]) },
    { id: 8, name: 'AirPods Pro 2', price: 1899, image: 'airpodspro2_1.png', images: JSON.stringify(['airpodspro2_1.png','airpodspro2_2.png','airpodspro2_3.png','airpodspro2_4.png']), category: '配件>耳机', shop_id: 1, stock: 300, description: '苹果主动降噪无线耳机，自适应音频，通透模式升级',
      specs: JSON.stringify([{name:'接口',values:['USB-C','Lightning']}]),
      skus: JSON.stringify([{id:'airpodspro2-usbc',specs:{'接口':'USB-C'},price:1899,stock:200},{id:'airpodspro2-lightning',specs:{'接口':'Lightning'},price:1799,stock:100}]) },
    { id: 9, name: '小米电视S75', price: 3999, image: 'mitvs75_1.png', images: JSON.stringify(['mitvs75_1.png','mitvs75_2.png','mitvs75_3.png','mitvs75_4.png']), category: '家电>电视', shop_id: 3, stock: 50, description: '75英寸4K超清智能电视，120Hz高刷新率，杜比视界',
      specs: JSON.stringify([{name:'尺寸',values:['65英寸','75英寸','85英寸']}]),
      skus: JSON.stringify([{id:'mis75-65',specs:{'尺寸':'65英寸'},price:2999,stock:40},{id:'mis75-75',specs:{'尺寸':'75英寸'},price:3999,stock:25},{id:'mis75-85',specs:{'尺寸':'85英寸'},price:5999,stock:10}]) },
    { id: 10, name: '格力空调KFR-35GW', price: 3299, image: 'gree_ac_1.png', images: JSON.stringify(['gree_ac_1.png','gree_ac_2.png','gree_ac_3.png']), category: '家电>空调', shop_id: 3, stock: 60, description: '1.5匹新一级能效，变频冷暖壁挂式，自清洁系统',
      specs: JSON.stringify([{name:'匹数',values:['1.5匹','2匹','3匹']}]),
      skus: JSON.stringify([{id:'gree-15p',specs:{'匹数':'1.5匹'},price:3299,stock:30},{id:'gree-2p',specs:{'匹数':'2匹'},price:4299,stock:20},{id:'gree-3p',specs:{'匹数':'3匹'},price:5599,stock:10}]) },
    { id: 11, name: '海尔滚筒洗衣机', price: 2999, image: 'p_海尔滚筒洗衣机_1781524670404_1.png', images: JSON.stringify(['p_海尔滚筒洗衣机_1781524670404_1.png','p_海尔滚筒洗衣机_1781524670404_2.png']), category: '家电>洗衣机', shop_id: 3, stock: 40, description: '变频静音，一级能效',
      specs: JSON.stringify([{name:'容量',values:['8kg','10kg','12kg']}]),
      skus: JSON.stringify([{id:'haier-8kg',specs:{'容量':'8kg'},price:2499,stock:15},{id:'haier-10kg',specs:{'容量':'10kg'},price:2999,stock:15},{id:'haier-12kg',specs:{'容量':'12kg'},price:3499,stock:10}]) },
    { id: 12, name: '美的双开门冰箱', price: 3999, image: 'p_美的双开门冰箱_1781524670461_1.png', images: JSON.stringify(['p_美的双开门冰箱_1781524670461_1.png','p_美的双开门冰箱_1781524670461_2.png']), category: '家电>冰箱', shop_id: 3, stock: 30, description: '风冷无霜，节能静音',
      specs: JSON.stringify([{name:'容量',values:['470升','520升','610升']}]),
      skus: JSON.stringify([{id:'midea-470l',specs:{'容量':'470升'},price:3999,stock:12},{id:'midea-520l',specs:{'容量':'520升'},price:4599,stock:10},{id:'midea-610l',specs:{'容量':'610升'},price:5599,stock:8}]) },
    { id: 13, name: '科沃斯扫地机器人', price: 2499, image: 'p_科沃斯扫地机器人_1781524670484_1.png', images: JSON.stringify(['p_科沃斯扫地机器人_1781524670484_1.png','p_科沃斯扫地机器人_1781524670484_2.png']), category: '家电>扫地机器人', shop_id: 3, stock: 50, description: '智能导航扫拖一体，自动集尘',
      specs: JSON.stringify([{name:'型号',values:['T20','X1 Pro']}]),
      skus: JSON.stringify([{id:'ecovacs-t20',specs:{'型号':'T20'},price:2499,stock:30},{id:'ecovacs-x1pro',specs:{'型号':'X1 Pro'},price:3299,stock:20}]) },
    { id: 14, name: '倍思65W充电器', price: 129, image: 'p_倍思65W充电器_1781524670512_1.png', images: JSON.stringify(['p_倍思65W充电器_1781524670512_1.png','p_倍思65W充电器_1781524670512_2.png']), category: '配件>充电器', shop_id: 1, stock: 500, description: '氮化镓65W快充，三口输出，兼容多协议',
      specs: JSON.stringify([{name:'颜色',values:['黑色','白色']}]),
      skus: JSON.stringify([{id:'baseus65w-black',specs:{'颜色':'黑色'},price:129,stock:300},{id:'baseus65w-white',specs:{'颜色':'白色'},price:129,stock:200}]) },
    { id: 15, name: '绿联Type-C数据线', price: 29, image: 'p_绿联TypeC数据线_1781524670548_1.png', images: JSON.stringify(['p_绿联TypeC数据线_1781524670548_1.png','p_绿联TypeC数据线_1781524670548_2.png']), category: '配件>数据线', shop_id: 1, stock: 1000, description: '5A大电流快充数据线，耐用编织材质',
      specs: JSON.stringify([{name:'长度',values:['1m','2m','3m']}]),
      skus: JSON.stringify([{id:'ugreen-1m',specs:{'长度':'1m'},price:29,stock:500},{id:'ugreen-2m',specs:{'长度':'2m'},price:39,stock:300},{id:'ugreen-3m',specs:{'长度':'3m'},price:49,stock:200}]) },
    { id: 16, name: '小米移动电源3', price: 199, image: 'p_小米移动电源3_1781524670576_1.png', images: JSON.stringify(['p_小米移动电源3_1781524670576_1.png','p_小米移动电源3_1781524670576_2.png']), category: '配件>充电宝', shop_id: 2, stock: 200, description: '双向快充，可为笔记本充电',
      specs: JSON.stringify([{name:'容量',values:['10000mAh','20000mAh','30000mAh']}]),
      skus: JSON.stringify([{id:'mi-pb-10k',specs:{'容量':'10000mAh'},price:129,stock:100},{id:'mi-pb-20k',specs:{'容量':'20000mAh'},price:199,stock:80},{id:'mi-pb-30k',specs:{'容量':'30000mAh'},price:299,stock:20}]) },
    { id: 17, name: '小米智能音箱', price: 299, image: 'p_小米智能音箱_1781524670601_1.png', images: JSON.stringify(['p_小米智能音箱_1781524670601_1.png','p_小米智能音箱_1781524670601_2.png']), category: '生活>智能设备', shop_id: 2, stock: 300, description: '小爱同学语音助手，智能家居控制中心',
      specs: JSON.stringify([{name:'颜色',values:['白色','黑色']}]),
      skus: JSON.stringify([{id:'mi-speaker-white',specs:{'颜色':'白色'},price:299,stock:200},{id:'mi-speaker-black',specs:{'颜色':'黑色'},price:299,stock:100}]) },
    { id: 18, name: '飞利浦电动牙刷', price: 399, image: 'p_飞利浦电动牙刷_1781524670624_1.png', images: JSON.stringify(['p_飞利浦电动牙刷_1781524670624_1.png','p_飞利浦电动牙刷_1781524670624_2.png']), category: '生活>个护健康', shop_id: 1, stock: 150, description: '声波震动技术，智能压力感应，IPX7防水',
      specs: JSON.stringify([{name:'颜色',values:['黑色','白色','粉色']}]),
      skus: JSON.stringify([{id:'philips-black',specs:{'颜色':'黑色'},price:399,stock:60},{id:'philips-white',specs:{'颜色':'白色'},price:399,stock:60},{id:'philips-pink',specs:{'颜色':'粉色'},price:429,stock:30}]) },
    { id: 19, name: '无印良品纯棉T恤', price: 129, image: 'p_无印良品纯棉T恤_1781524670650_1.png', images: JSON.stringify(['p_无印良品纯棉T恤_1781524670650_1.png','p_无印良品纯棉T恤_1781524670650_2.png']), category: '服装>男装', shop_id: 1, stock: 200, description: '纯棉圆领短袖T恤，舒适透气，简约百搭',
      specs: JSON.stringify([{name:'颜色',values:['白色','黑色','灰色','藏青']},{name:'尺码',values:['M','L','XL','XXL']}]),
      skus: JSON.stringify([{id:'muji-white-m',specs:{'颜色':'白色','尺码':'M'},price:129,stock:30},{id:'muji-white-l',specs:{'颜色':'白色','尺码':'L'},price:129,stock:40},{id:'muji-black-l',specs:{'颜色':'黑色','尺码':'L'},price:129,stock:35},{id:'muji-gray-xl',specs:{'颜色':'灰色','尺码':'XL'},price:139,stock:25},{id:'muji-navy-xxl',specs:{'颜色':'藏青','尺码':'XXL'},price:139,stock:20}]) },
    { id: 20, name: '迪奥999口红', price: 350, image: 'p_迪奥999口红_1781524670669_1.png', images: JSON.stringify(['p_迪奥999口红_1781524670669_1.png','p_迪奥999口红_1781524670669_2.png']), category: '美妆>彩妆', shop_id: 1, stock: 100, description: '传奇红唇，丝绒哑光质感，经典正红色',
      specs: JSON.stringify([{name:'质地',values:['哑光','滋润','金属']}]),
      skus: JSON.stringify([{id:'dior999-matte',specs:{'质地':'哑光'},price:350,stock:50},{id:'dior999-sheer',specs:{'质地':'滋润'},price:350,stock:30},{id:'dior999-metal',specs:{'质地':'金属'},price:370,stock:20}]) },
    { id: 21, name: '良品铺子零食大礼包', price: 99, image: 'p_良品铺子零食大礼包_1781524670692_1.png', images: JSON.stringify(['p_良品铺子零食大礼包_1781524670692_1.png','p_良品铺子零食大礼包_1781524670692_2.png']), category: '食品>零食', shop_id: 1, stock: 500, description: '坚果果脯零食大礼包，内含20种美味',
      specs: JSON.stringify([{name:'规格',values:['标准装','豪华装']}]),
      skus: JSON.stringify([{id:'lppz-standard',specs:{'规格':'标准装'},price:99,stock:300},{id:'lppz-deluxe',specs:{'规格':'豪华装'},price:169,stock:200}]) },
    { id: 22, name: '西湖龙井明前茶', price: 298, image: 'p_西湖龙井明前茶_1781524670720_1.png', images: JSON.stringify(['p_西湖龙井明前茶_1781524670720_1.png','p_西湖龙井明前茶_1781524670720_2.png']), category: '食品>茶饮', shop_id: 1, stock: 200, description: '正宗西湖龙井，明前特级绿茶',
      specs: JSON.stringify([{name:'规格',values:['100g','250g','500g']}]),
      skus: JSON.stringify([{id:'longjing-100g',specs:{'规格':'100g'},price:298,stock:100},{id:'longjing-250g',specs:{'规格':'250g'},price:598,stock:60},{id:'longjing-500g',specs:{'规格':'500g'},price:998,stock:40}]) },
    { id: 23, name: '五常稻花香大米', price: 69, image: 'p_五常稻花香大米_1781524670745_1.png', images: JSON.stringify(['p_五常稻花香大米_1781524670745_1.png','p_五常稻花香大米_1781524670745_2.png']), category: '食品>粮油调味', shop_id: 1, stock: 300, description: '东北五常稻花香，优质一等大米',
      specs: JSON.stringify([{name:'规格',values:['5kg','10kg']}]),
      skus: JSON.stringify([{id:'wuchang-5kg',specs:{'规格':'5kg'},price:69,stock:200},{id:'wuchang-10kg',specs:{'规格':'10kg'},price:129,stock:100}]) },
    { id: 24, name: '三体全集', price: 128, image: 'p_三体全集_1781524670763_1.png', images: JSON.stringify(['p_三体全集_1781524670763_1.png','p_三体全集_1781524670763_2.png']), category: '图书>文学', shop_id: 1, stock: 400, description: '刘慈欣科幻巨著，雨果奖获奖作品', specs: '[]', skus: '[]' },
    { id: 25, name: 'Python编程 从入门到实践', price: 89, image: 'p_Python编程从入门到实践_1781524670782_1.png', images: JSON.stringify(['p_Python编程从入门到实践_1781524670782_1.png','p_Python编程从入门到实践_1781524670782_2.png']), category: '图书>科技', shop_id: 1, stock: 300, description: '零基础学Python，畅销编程入门书', specs: '[]', skus: '[]' },
    { id: 26, name: '小王子（精装插图版）', price: 39, image: 'p_小王子精装插图版_1781524670805_1.png', images: JSON.stringify(['p_小王子精装插图版_1781524670805_1.png','p_小王子精装插图版_1781524670805_2.png']), category: '图书>童书', shop_id: 1, stock: 500, description: '圣埃克苏佩里经典童话，全彩插图', specs: '[]', skus: '[]' },
    { id: 27, name: '李宁飞电4.0跑鞋', price: 699, image: 'p_李宁飞电40跑鞋_1781524670824_1.png', images: JSON.stringify(['p_李宁飞电40跑鞋_1781524670824_1.png','p_李宁飞电40跑鞋_1781524670824_2.png']), category: '运动>运动鞋服', shop_id: 2, stock: 200, description: '专业马拉松竞速跑鞋，䨻科技回弹',
      specs: JSON.stringify([{name:'颜色',values:['荧光绿','黑白','红色']},{name:'尺码',values:['39','40','41','42','43','44','45']}]),
      skus: JSON.stringify([{id:'lining-green-42',specs:{'颜色':'荧光绿','尺码':'42'},price:699,stock:30},{id:'lining-black-42',specs:{'颜色':'黑白','尺码':'42'},price:699,stock:40},{id:'lining-black-43',specs:{'颜色':'黑白','尺码':'43'},price:699,stock:35},{id:'lining-red-44',specs:{'颜色':'红色','尺码':'44'},price:729,stock:20}]) },
    { id: 28, name: 'Keep专业瑜伽垫', price: 129, image: 'p_Keep专业瑜伽垫_1781524670841_1.png', images: JSON.stringify(['p_Keep专业瑜伽垫_1781524670841_1.png','p_Keep专业瑜伽垫_1781524670841_2.png']), category: '运动>瑜伽', shop_id: 2, stock: 300, description: 'NBR材质环保无味，加厚防滑健身垫',
      specs: JSON.stringify([{name:'厚度',values:['6mm','8mm','10mm']},{name:'颜色',values:['紫色','蓝色','粉色']}]),
      skus: JSON.stringify([{id:'keep-6mm-purple',specs:{'厚度':'6mm','颜色':'紫色'},price:99,stock:80},{id:'keep-8mm-blue',specs:{'厚度':'8mm','颜色':'蓝色'},price:129,stock:100},{id:'keep-10mm-pink',specs:{'厚度':'10mm','颜色':'粉色'},price:159,stock:60}]) },
    { id: 29, name: '牧高笛户外帐篷', price: 599, image: 'p_牧高笛户外帐篷_1781524670865_1.png', images: JSON.stringify(['p_牧高笛户外帐篷_1781524670865_1.png','p_牧高笛户外帐篷_1781524670865_2.png']), category: '运动>户外装备', shop_id: 1, stock: 80, description: '双层防雨帐篷，全自动速开',
      specs: JSON.stringify([{name:'规格',values:['双人','三人','四人']}]),
      skus: JSON.stringify([{id:'mogodi-2p',specs:{'规格':'双人'},price:599,stock:30},{id:'mogodi-3p',specs:{'规格':'三人'},price:799,stock:30},{id:'mogodi-4p',specs:{'规格':'四人'},price:999,stock:20}]) },
    { id: 30, name: '美赞臣铂睿3段奶粉', price: 268, image: 'p_美赞臣铂睿3段奶粉_1781524670883_1.png', images: JSON.stringify(['p_美赞臣铂睿3段奶粉_1781524670883_1.png','p_美赞臣铂睿3段奶粉_1781524670883_2.png']), category: '母婴>奶粉', shop_id: 1, stock: 200, description: '荷兰进口，幼儿配方奶粉900g',
      specs: JSON.stringify([{name:'段数',values:['1段','2段','3段']}]),
      skus: JSON.stringify([{id:'mjz-1',specs:{'段数':'1段'},price:268,stock:80},{id:'mjz-2',specs:{'段数':'2段'},price:258,stock:70},{id:'mjz-3',specs:{'段数':'3段'},price:248,stock:50}]) },
    { id: 31, name: '帮宝适一级帮纸尿裤', price: 189, image: 'p_帮宝适一级帮纸尿裤_1781524670901_1.png', images: JSON.stringify(['p_帮宝适一级帮纸尿裤_1781524670901_1.png','p_帮宝适一级帮纸尿裤_1781524670901_2.png']), category: '母婴>纸尿裤', shop_id: 1, stock: 400, description: '日本进口，透气瞬吸',
      specs: JSON.stringify([{name:'尺码',values:['M','L','XL','XXL']}]),
      skus: JSON.stringify([{id:'pampers-m',specs:{'尺码':'M'},price:169,stock:100},{id:'pampers-l',specs:{'尺码':'L'},price:189,stock:150},{id:'pampers-xl',specs:{'尺码':'XL'},price:209,stock:100},{id:'pampers-xxl',specs:{'尺码':'XXL'},price:229,stock:50}]) },
    { id: 32, name: '乐高经典创意积木', price: 299, image: 'p_乐高经典创意积木_1781524670919_1.png', images: JSON.stringify(['p_乐高经典创意积木_1781524670919_1.png','p_乐高经典创意积木_1781524670919_2.png']), category: '母婴>玩具', shop_id: 1, stock: 150, description: '经典大盒装，1066颗粒，激发创造力', specs: '[]', skus: '[]' },
    { id: 33, name: '皇家狗粮小型成犬粮', price: 178, image: 'p_皇家狗粮小型成犬粮_1781524670941_1.png', images: JSON.stringify(['p_皇家狗粮小型成犬粮_1781524670941_1.png','p_皇家狗粮小型成犬粮_1781524670941_2.png']), category: '宠物>狗粮', shop_id: 1, stock: 200, description: '法国品牌，小型犬专用粮',
      specs: JSON.stringify([{name:'规格',values:['2kg','4kg','8kg']}]),
      skus: JSON.stringify([{id:'royal-2kg',specs:{'规格':'2kg'},price:99,stock:100},{id:'royal-4kg',specs:{'规格':'4kg'},price:178,stock:70},{id:'royal-8kg',specs:{'规格':'8kg'},price:298,stock:30}]) },
    { id: 34, name: '伟嘉猫粮海洋鱼味', price: 89, image: 'p_伟嘉猫粮海洋鱼味_1781524670959_1.png', images: JSON.stringify(['p_伟嘉猫粮海洋鱼味_1781524670959_1.png','p_伟嘉猫粮海洋鱼味_1781524670959_2.png']), category: '宠物>猫粮', shop_id: 1, stock: 300, description: '成猫主粮，海洋鱼味拼盘',
      specs: JSON.stringify([{name:'规格',values:['2.5kg','5kg','10kg']}]),
      skus: JSON.stringify([{id:'whiskas-25kg',specs:{'规格':'2.5kg'},price:89,stock:150},{id:'whiskas-5kg',specs:{'规格':'5kg'},price:159,stock:100},{id:'whiskas-10kg',specs:{'规格':'10kg'},price:269,stock:50}]) },
    { id: 35, name: '北欧LED台灯', price: 159, image: 'p_北欧LED台灯_1781524670980_1.png', images: JSON.stringify(['p_北欧LED台灯_1781524670980_1.png','p_北欧LED台灯_1781524670980_2.png']), category: '家装>灯具', shop_id: 1, stock: 300, description: '护眼台灯，三档色温可调，触摸开关',
      specs: JSON.stringify([{name:'颜色',values:['白色','黑色','金色']}]),
      skus: JSON.stringify([{id:'lamp-white',specs:{'颜色':'白色'},price:159,stock:150},{id:'lamp-black',specs:{'颜色':'黑色'},price:159,stock:100},{id:'lamp-gold',specs:{'颜色':'金色'},price:179,stock:50}]) },
    { id: 36, name: '60支纯棉四件套', price: 329, image: 'p_60支纯棉四件套_1781524671003_1.png', images: JSON.stringify(['p_60支纯棉四件套_1781524671003_1.png','p_60支纯棉四件套_1781524671003_2.png']), category: '家装>家纺', shop_id: 1, stock: 100, description: '高支高密纯棉，简约素色床品套件',
      specs: JSON.stringify([{name:'规格',values:['1.5m床','1.8m床','2.0m床']}]),
      skus: JSON.stringify([{id:'bedsheet-15m',specs:{'规格':'1.5m床'},price:329,stock:40},{id:'bedsheet-18m',specs:{'规格':'1.8m床'},price:359,stock:40},{id:'bedsheet-20m',specs:{'规格':'2.0m床'},price:399,stock:20}]) },
    { id: 37, name: '倍思车载充电器', price: 79, image: 'p_倍思车载充电器_1781524671024_1.png', images: JSON.stringify(['p_倍思车载充电器_1781524671024_1.png','p_倍思车载充电器_1781524671024_2.png']), category: '汽车>车载电器', shop_id: 2, stock: 500, description: 'QC4.0+PD快充，双口输出',
      specs: JSON.stringify([{name:'接口',values:['双QC','QC+PD']}]),
      skus: JSON.stringify([{id:'baseus-car-qcqc',specs:{'接口':'双QC'},price:69,stock:300},{id:'baseus-car-qcpd',specs:{'接口':'QC+PD'},price:79,stock:200}]) },
    { id: 38, name: '70迈智能行车记录仪', price: 349, image: 'p_70迈智能行车记录仪_1781524671049_1.png', images: JSON.stringify(['p_70迈智能行车记录仪_1781524671049_1.png','p_70迈智能行车记录仪_1781524671049_2.png']), category: '汽车>汽车用品', shop_id: 1, stock: 150, description: '2K超清画质，ADAS驾驶辅助',
      specs: JSON.stringify([{name:'配置',values:['标准版','尊享版']}]),
      skus: JSON.stringify([{id:'70mai-standard',specs:{'配置':'标准版'},price:349,stock:100},{id:'70mai-pro',specs:{'配置':'尊享版'},price:499,stock:50}]) },
    { id: 39, name: '云南白药创可贴', price: 19, image: 'p_云南白药创可贴_1781524671071_1.png', images: JSON.stringify(['p_云南白药创可贴_1781524671071_1.png','p_云南白药创可贴_1781524671071_2.png']), category: '医药>常备药', shop_id: 1, stock: 1000, description: '轻巧透气，止血护创',
      specs: JSON.stringify([{name:'规格',values:['50片','100片']}]),
      skus: JSON.stringify([{id:'ynby-50',specs:{'规格':'50片'},price:12,stock:600},{id:'ynby-100',specs:{'规格':'100片'},price:19,stock:400}]) },
    { id: 40, name: '汤臣倍健维生素C片', price: 68, image: 'p_汤臣倍健维生素C片_1781524671095_1.png', images: JSON.stringify(['p_汤臣倍健维生素C片_1781524671095_1.png','p_汤臣倍健维生素C片_1781524671095_2.png']), category: '医药>保健品', shop_id: 1, stock: 400, description: '针叶樱桃维C，增强抵抗力',
      specs: JSON.stringify([{name:'规格',values:['60片','120片']}]),
      skus: JSON.stringify([{id:'tcbj-60',specs:{'规格':'60片'},price:68,stock:250},{id:'tcbj-120',specs:{'规格':'120片'},price:118,stock:150}]) },

    // ── 新增商品：补全空分类 ──
    { id: 41, name: 'OPPO Find X7 Ultra', price: 5999, image: 'p_OPPOFindX7Ultra_1781524671121_1.png', images: JSON.stringify(['p_OPPOFindX7Ultra_1781524671121_1.png','p_OPPOFindX7Ultra_1781524671121_2.png']), category: '手机>OPPO', shop_id: 1, stock: 80, description: '哈苏影像旗舰，骁龙8Gen3，双潜望长焦',
      specs: JSON.stringify([{name:'颜色',values:['海阔天空','大漠银月','松涛']},{name:'存储',values:['256GB','512GB']}]),
      skus: JSON.stringify([{id:'oppofindx7u-blue-256',specs:{'颜色':'海阔天空','存储':'256GB'},price:5999,stock:30},{id:'oppofindx7u-silver-512',specs:{'颜色':'大漠银月','存储':'512GB'},price:6999,stock:25}]) },
    { id: 42, name: 'vivo X100 Pro', price: 4999, image: 'p_vivoX100Pro_1781524671168_1.png', images: JSON.stringify(['p_vivoX100Pro_1781524671168_1.png','p_vivoX100Pro_1781524671168_2.png']), category: '手机>vivo', shop_id: 1, stock: 80, description: '蔡司影像，天玑9300，蓝海电池',
      specs: JSON.stringify([{name:'颜色',values:['星迹蓝','白月光','辰夜黑']},{name:'存储',values:['256GB','512GB','1TB']}]),
      skus: JSON.stringify([{id:'vivo-x100p-blue-256',specs:{'颜色':'星迹蓝','存储':'256GB'},price:4999,stock:25},{id:'vivo-x100p-white-512',specs:{'颜色':'白月光','存储':'512GB'},price:5499,stock:30},{id:'vivo-x100p-black-1t',specs:{'颜色':'辰夜黑','存储':'1TB'},price:6499,stock:15}]) },
    { id: 43, name: '三星 Galaxy S24 Ultra', price: 9699, image: 'p_三星GalaxyS24Ultra_1781524671202_1.png', images: JSON.stringify(['p_三星GalaxyS24Ultra_1781524671202_1.png','p_三星GalaxyS24Ultra_1781524671202_2.png']), category: '手机>三星', shop_id: 1, stock: 50, description: '骁龙8Gen3，钛金属框架，Galaxy AI智能助手',
      specs: JSON.stringify([{name:'颜色',values:['钛灰','钛黑','钛紫','钛黄']},{name:'存储',values:['256GB','512GB','1TB']}]),
      skus: JSON.stringify([{id:'s24u-gray-256',specs:{'颜色':'钛灰','存储':'256GB'},price:9699,stock:15},{id:'s24u-black-512',specs:{'颜色':'钛黑','存储':'512GB'},price:10699,stock:20},{id:'s24u-purple-1t',specs:{'颜色':'钛紫','存储':'1TB'},price:12699,stock:10}]) },
    { id: 44, name: '荣耀 Magic6 Pro', price: 5699, image: 'p_荣耀Magic6Pro_1781524671231_1.png', images: JSON.stringify(['p_荣耀Magic6Pro_1781524671231_1.png','p_荣耀Magic6Pro_1781524671231_2.png']), category: '手机>荣耀', shop_id: 1, stock: 60, description: '骁龙8Gen3，鹰眼相机，青海湖电池，巨犀玻璃',
      specs: JSON.stringify([{name:'颜色',values:['海湖青','流云紫','麦浪绿','绒黑色']},{name:'存储',values:['256GB','512GB','1TB']}]),
      skus: JSON.stringify([{id:'magic6p-green-256',specs:{'颜色':'海湖青','存储':'256GB'},price:5699,stock:20},{id:'magic6p-purple-512',specs:{'颜色':'流云紫','存储':'512GB'},price:6199,stock:20},{id:'magic6p-black-1t',specs:{'颜色':'绒黑色','存储':'1TB'},price:6999,stock:10}]) },
    { id: 45, name: '华硕灵耀14', price: 4999, image: 'p_华硕灵耀14_1781524671252_1.png', images: JSON.stringify(['p_华硕灵耀14_1781524671252_1.png','p_华硕灵耀14_1781524671252_2.png']), category: '电脑>华硕', shop_id: 1, stock: 50, description: '14英寸2.8K OLED屏，酷睿Ultra，轻约1.3kg',
      specs: JSON.stringify([{name:'颜色',values:['深蓝','灰色']},{name:'配置',values:['Ultra5+16GB','Ultra7+16GB','Ultra7+32GB']}]),
      skus: JSON.stringify([{id:'asus-lingyao-u5',specs:{'颜色':'深蓝','配置':'Ultra5+16GB'},price:4999,stock:20},{id:'asus-lingyao-u7',specs:{'颜色':'灰色','配置':'Ultra7+16GB'},price:5999,stock:20},{id:'asus-lingyao-u7-32',specs:{'颜色':'灰色','配置':'Ultra7+32GB'},price:6999,stock:10}]) },
    { id: 46, name: '戴尔XPS 16', price: 12999, image: 'p_戴尔XPS16_1781524671272_1.png', images: JSON.stringify(['p_戴尔XPS16_1781524671272_1.png','p_戴尔XPS16_1781524671272_2.png']), category: '电脑>戴尔', shop_id: 1, stock: 30, description: 'Intel Core Ultra 9，4K OLED触控屏，顶级创作本',
      specs: JSON.stringify([{name:'颜色',values:['铂金银','石墨黑']},{name:'配置',values:['Ultra7+16GB','Ultra9+32GB']}]),
      skus: JSON.stringify([{id:'xps16-silver-u7',specs:{'颜色':'铂金银','配置':'Ultra7+16GB'},price:12999,stock:15},{id:'xps16-black-u9',specs:{'颜色':'石墨黑','配置':'Ultra9+32GB'},price:16999,stock:15}]) },
    { id: 47, name: '惠普战66', price: 4299, image: 'p_惠普战66_1781524671296_1.png', images: JSON.stringify(['p_惠普战66_1781524671296_1.png','p_惠普战66_1781524671296_2.png']), category: '电脑>惠普', shop_id: 1, stock: 60, description: '商务办公笔记本，15.6英寸大屏，长续航',
      specs: JSON.stringify([{name:'配置',values:['i5+16GB','i7+16GB','i7+32GB']}]),
      skus: JSON.stringify([{id:'hp-war66-i5',specs:{'配置':'i5+16GB'},price:4299,stock:25},{id:'hp-war66-i7',specs:{'配置':'i7+16GB'},price:5299,stock:25},{id:'hp-war66-i7-32',specs:{'配置':'i7+32GB'},price:5999,stock:10}]) },
    { id: 48, name: '透明防摔手机壳', price: 29, image: 'p_透明防摔手机壳_1781524671317_1.png', images: JSON.stringify(['p_透明防摔手机壳_1781524671317_1.png','p_透明防摔手机壳_1781524671317_2.png']), category: '配件>手机壳', shop_id: 1, stock: 600, description: 'TPU软边硬背，防摔防刮，精准孔位',
      specs: JSON.stringify([{name:'适用机型',values:['iPhone 15','华为Mate60','小米14','三星S24']}]),
      skus: JSON.stringify([{id:'case-iphone15',specs:{'适用机型':'iPhone 15'},price:29,stock:150},{id:'case-mate60',specs:{'适用机型':'华为Mate60'},price:29,stock:150},{id:'case-mi14',specs:{'适用机型':'小米14'},price:29,stock:150},{id:'case-s24',specs:{'适用机型':'三星S24'},price:29,stock:150}]) },
    { id: 49, name: '高清钢化膜', price: 19, image: 'p_高清钢化膜_1781524671339_1.png', images: JSON.stringify(['p_高清钢化膜_1781524671339_1.png','p_高清钢化膜_1781524671339_2.png']), category: '配件>贴膜', shop_id: 1, stock: 800, description: '高铝玻璃，9H硬度，防指纹涂层',
      specs: JSON.stringify([{name:'适用机型',values:['iPhone 15','华为Mate60','小米14','三星S24']}]),
      skus: JSON.stringify([{id:'tempered-iphone15',specs:{'适用机型':'iPhone 15'},price:19,stock:200},{id:'tempered-mate60',specs:{'适用机型':'华为Mate60'},price:19,stock:200},{id:'tempered-mi14',specs:{'适用机型':'小米14'},price:19,stock:200},{id:'tempered-s24',specs:{'适用机型':'三星S24'},price:19,stock:200}]) },
    { id: 50, name: '海尔热水器60L', price: 1599, image: 'p_海尔热水器60L_1781524671361_1.png', images: JSON.stringify(['p_海尔热水器60L_1781524671361_1.png','p_海尔热水器60L_1781524671361_2.png']), category: '家电>热水器', shop_id: 3, stock: 40, description: '60升储水式电热水器，一级能效，防电墙技术',
      specs: JSON.stringify([{name:'容量',values:['40L','60L','80L']}]),
      skus: JSON.stringify([{id:'haier-water-40l',specs:{'容量':'40L'},price:1199,stock:15},{id:'haier-water-60l',specs:{'容量':'60L'},price:1599,stock:15},{id:'haier-water-80l',specs:{'容量':'80L'},price:1999,stock:10}]) },
    { id: 51, name: '得力无线打印机', price: 899, image: 'p_得力无线打印机_1781524671392_1.png', images: JSON.stringify(['p_得力无线打印机_1781524671392_1.png','p_得力无线打印机_1781524671392_2.png']), category: '生活>办公设备', shop_id: 1, stock: 60, description: '彩色喷墨，无线连接，手机打印',
      specs: JSON.stringify([{name:'功能',values:['单打印','打印+扫描','打印+扫描+复印']}]),
      skus: JSON.stringify([{id:'deli-print',specs:{'功能':'单打印'},price:699,stock:25},{id:'deli-printscan',specs:{'功能':'打印+扫描'},price:899,stock:20},{id:'deli-allinone',specs:{'功能':'打印+扫描+复印'},price:1199,stock:15}]) },
    { id: 52, name: '智能窗帘电机', price: 399, image: 'p_智能窗帘电机_1781524671416_1.png', images: JSON.stringify(['p_智能窗帘电机_1781524671416_1.png','p_智能窗帘电机_1781524671416_2.png']), category: '生活>家居', shop_id: 2, stock: 100, description: '米家智能联动，支持小爱语音控制，静音电机',
      specs: JSON.stringify([{name:'规格',values:['1.5m轨道','2m轨道','3m轨道']}]),
      skus: JSON.stringify([{id:'curtain-15m',specs:{'规格':'1.5m轨道'},price:399,stock:40},{id:'curtain-2m',specs:{'规格':'2m轨道'},price:449,stock:35},{id:'curtain-3m',specs:{'规格':'3m轨道'},price:529,stock:25}]) },
    { id: 53, name: '九阳破壁机', price: 499, image: 'p_九阳破壁机_1781524671437_1.png', images: JSON.stringify(['p_九阳破壁机_1781524671437_1.png','p_九阳破壁机_1781524671437_2.png']), category: '生活>厨房用品', shop_id: 2, stock: 80, description: '一机多能，豆浆果汁浓汤，可拆洗',
      specs: JSON.stringify([{name:'容量',values:['1L','1.5L','2L']}]),
      skus: JSON.stringify([{id:'joyoung-1l',specs:{'容量':'1L'},price:399,stock:30},{id:'joyoung-15l',specs:{'容量':'1.5L'},price:499,stock:30},{id:'joyoung-2l',specs:{'容量':'2L'},price:599,stock:20}]) },
    { id: 54, name: '江南布衣连衣裙', price: 399, image: 'p_江南布衣连衣裙_1781524671465_1.png', images: JSON.stringify(['p_江南布衣连衣裙_1781524671465_1.png','p_江南布衣连衣裙_1781524671465_2.png']), category: '服装>女装', shop_id: 1, stock: 100, description: '优雅碎花连衣裙，夏日清爽',
      specs: JSON.stringify([{name:'颜色',values:['碎花蓝','碎花粉','纯白']},{name:'尺码',values:['S','M','L','XL']}]),
      skus: JSON.stringify([{id:'jnby-blue-m',specs:{'颜色':'碎花蓝','尺码':'M'},price:399,stock:20},{id:'jnby-pink-l',specs:{'颜色':'碎花粉','尺码':'L'},price:399,stock:25},{id:'jnby-white-s',specs:{'颜色':'纯白','尺码':'S'},price:429,stock:15}]) },
    { id: 55, name: '耐克Air Force 1', price: 799, image: 'p_耐克AirForce1_1781524671487_1.png', images: JSON.stringify(['p_耐克AirForce1_1781524671487_1.png','p_耐克AirForce1_1781524671487_2.png']), category: '服装>运动鞋', shop_id: 1, stock: 150, description: '经典空军一号，百搭小白鞋',
      specs: JSON.stringify([{name:'颜色',values:['白色','黑色','红白']},{name:'尺码',values:['38','39','40','41','42','43','44']}]),
      skus: JSON.stringify([{id:'af1-white-42',specs:{'颜色':'白色','尺码':'42'},price:799,stock:40},{id:'af1-white-43',specs:{'颜色':'白色','尺码':'43'},price:799,stock:30},{id:'af1-black-42',specs:{'颜色':'黑色','尺码':'42'},price:799,stock:25}]) },
    { id: 56, name: '百丽休闲皮鞋', price: 599, image: 'p_百丽休闲皮鞋_1781524671513_1.png', images: JSON.stringify(['p_百丽休闲皮鞋_1781524671513_1.png','p_百丽休闲皮鞋_1781524671513_2.png']), category: '服装>休闲鞋', shop_id: 1, stock: 80, description: '头层牛皮，舒适百搭商务休闲',
      specs: JSON.stringify([{name:'颜色',values:['黑色','棕色']},{name:'尺码',values:['38','39','40','41','42','43','44']}]),
      skus: JSON.stringify([{id:'belle-black-41',specs:{'颜色':'黑色','尺码':'41'},price:599,stock:20},{id:'belle-brown-42',specs:{'颜色':'棕色','尺码':'42'},price:599,stock:20},{id:'belle-black-43',specs:{'颜色':'黑色','尺码':'43'},price:599,stock:15}]) },
    { id: 57, name: 'COACH手提包', price: 2599, image: 'p_COACH手提包_1781524671536_1.png', images: JSON.stringify(['p_COACH手提包_1781524671536_1.png','p_COACH手提包_1781524671536_2.png']), category: '服装>包包', shop_id: 1, stock: 40, description: '经典老花图案，轻奢时尚，通勤必备',
      specs: JSON.stringify([{name:'颜色',values:['经典老花','黑色','白色']},{name:'尺寸',values:['小号','中号','大号']}]),
      skus: JSON.stringify([{id:'coach-classic-m',specs:{'颜色':'经典老花','尺寸':'中号'},price:2599,stock:15},{id:'coach-black-s',specs:{'颜色':'黑色','尺寸':'小号'},price:2199,stock:15},{id:'coach-white-l',specs:{'颜色':'白色','尺寸':'大号'},price:2999,stock:10}]) },
    { id: 58, name: '兰蔻小黑瓶精华', price: 1080, image: 'p_兰蔻小黑瓶精华_1781524671561_1.png', images: JSON.stringify(['p_兰蔻小黑瓶精华_1781524671561_1.png','p_兰蔻小黑瓶精华_1781524671561_2.png']), category: '美妆>护肤', shop_id: 1, stock: 80, description: '第二代小黑瓶肌底精华液，修护肌肤屏障',
      specs: JSON.stringify([{name:'规格',values:['30ml','50ml','75ml']}]),
      skus: JSON.stringify([{id:'lancome-30ml',specs:{'规格':'30ml'},price:760,stock:30},{id:'lancome-50ml',specs:{'规格':'50ml'},price:1080,stock:30},{id:'lancome-75ml',specs:{'规格':'75ml'},price:1380,stock:20}]) },
    { id: 59, name: '爱马仕大地香水', price: 1280, image: 'p_爱马仕大地香水_1781524671581_1.png', images: JSON.stringify(['p_爱马仕大地香水_1781524671581_1.png','p_爱马仕大地香水_1781524671581_2.png']), category: '美妆>香水', shop_id: 1, stock: 40, description: '木质调男士淡香水，经典沉稳',
      specs: JSON.stringify([{name:'规格',values:['50ml','100ml','150ml']}]),
      skus: JSON.stringify([{id:'hermes-50ml',specs:{'规格':'50ml'},price:880,stock:15},{id:'hermes-100ml',specs:{'规格':'100ml'},price:1280,stock:15},{id:'hermes-150ml',specs:{'规格':'150ml'},price:1680,stock:10}]) },
    { id: 60, name: '卡诗洗发水', price: 298, image: 'p_卡诗洗发水_1781524671599_1.png', images: JSON.stringify(['p_卡诗洗发水_1781524671599_1.png','p_卡诗洗发水_1781524671599_2.png']), category: '美妆>洗护', shop_id: 1, stock: 150, description: '奢华修护洗发水，专为受损发质',
      specs: JSON.stringify([{name:'功效',values:['修护','控油','丰盈']},{name:'规格',values:['250ml','500ml']}]),
      skus: JSON.stringify([{id:'kerastase-repair-250',specs:{'功效':'修护','规格':'250ml'},price:298,stock:40},{id:'kerastase-oilcontrol-250',specs:{'功效':'控油','规格':'250ml'},price:278,stock:35},{id:'kerastase-repair-500',specs:{'功效':'修护','规格':'500ml'},price:498,stock:25}]) },
    { id: 61, name: '澳洲进口牛排套餐', price: 199, image: 'p_澳洲进口牛排套餐_1781524671617_1.png', images: JSON.stringify(['p_澳洲进口牛排套餐_1781524671617_1.png','p_澳洲进口牛排套餐_1781524671617_2.png']), category: '食品>生鲜', shop_id: 1, stock: 200, description: '澳洲谷饲安格斯西冷牛排，原切进口',
      specs: JSON.stringify([{name:'规格',values:['500g(3片装)','1kg(6片装)','2kg(12片装)']}]),
      skus: JSON.stringify([{id:'steak-500g',specs:{'规格':'500g(3片装)'},price:199,stock:100},{id:'steak-1kg',specs:{'规格':'1kg(6片装)'},price:359,stock:60},{id:'steak-2kg',specs:{'规格':'2kg(12片装)'},price:649,stock:40}]) },
    { id: 62, name: '茅台飞天53度', price: 1499, image: 'p_茅台飞天53度_1781524671634_1.png', images: JSON.stringify(['p_茅台飞天53度_1781524671634_1.png','p_茅台飞天53度_1781524671634_2.png']), category: '食品>酒水', shop_id: 1, stock: 20, description: '贵州茅台飞天53度酱香型白酒，年份陈酿', specs: '[]', skus: '[]' },
    { id: 63, name: '新概念英语全套', price: 299, image: 'p_新概念英语全套_1781524671652_1.png', images: JSON.stringify(['p_新概念英语全套_1781524671652_1.png','p_新概念英语全套_1781524671652_2.png']), category: '图书>教育', shop_id: 1, stock: 200, description: '经典英语教材，1-4册全套，含练习册', specs: '[]', skus: '[]' },
    { id: 64, name: '断舍离', price: 45, image: 'p_断舍离_1781524671670_1.png', images: JSON.stringify(['p_断舍离_1781524671670_1.png','p_断舍离_1781524671670_2.png']), category: '图书>生活', shop_id: 1, stock: 300, description: '山下英子经典生活哲学，改变千万人的整理术', specs: '[]', skus: '[]' },
    { id: 65, name: '哑铃套装20kg', price: 299, image: 'p_哑铃套装20kg_1781524671687_1.png', images: JSON.stringify(['p_哑铃套装20kg_1781524671687_1.png','p_哑铃套装20kg_1781524671687_2.png']), category: '运动>健身器材', shop_id: 2, stock: 80, description: '可调节哑铃套装，包胶静音，家用健身',
      specs: JSON.stringify([{name:'重量',values:['10kg','20kg','30kg']}]),
      skus: JSON.stringify([{id:'dumbbell-10kg',specs:{'重量':'10kg'},price:179,stock:30},{id:'dumbbell-20kg',specs:{'重量':'20kg'},price:299,stock:30},{id:'dumbbell-30kg',specs:{'重量':'30kg'},price:449,stock:20}]) },
    { id: 66, name: '自行车头盔', price: 199, image: 'p_自行车头盔_1781524671706_1.png', images: JSON.stringify(['p_自行车头盔_1781524671706_1.png','p_自行车头盔_1781524671706_2.png']), category: '运动>骑行', shop_id: 2, stock: 100, description: '一体成型，通风透气，可调节头围',
      specs: JSON.stringify([{name:'颜色',values:['黑色','白色','红色']}]),
      skus: JSON.stringify([{id:'helmet-black',specs:{'颜色':'黑色'},price:199,stock:40},{id:'helmet-white',specs:{'颜色':'白色'},price:199,stock:35},{id:'helmet-red',specs:{'颜色':'红色'},price:199,stock:25}]) },
    { id: 67, name: '婴儿连体衣', price: 129, image: 'p_婴儿连体衣_1781524671724_1.png', images: JSON.stringify(['p_婴儿连体衣_1781524671724_1.png','p_婴儿连体衣_1781524671724_2.png']), category: '母婴>童装', shop_id: 1, stock: 150, description: '纯棉A类面料，按扣设计，方便穿脱',
      specs: JSON.stringify([{name:'颜色',values:['白色','蓝色','粉色']},{name:'尺码',values:['66cm(3-6月)','73cm(6-12月)','80cm(12-18月)']}]),
      skus: JSON.stringify([{id:'baby-body-white-66',specs:{'颜色':'白色','尺码':'66cm(3-6月)'},price:129,stock:30},{id:'baby-body-blue-73',specs:{'颜色':'蓝色','尺码':'73cm(6-12月)'},price:129,stock:40},{id:'baby-body-pink-80',specs:{'颜色':'粉色','尺码':'80cm(12-18月)'},price:139,stock:25}]) },
    { id: 68, name: '婴儿轻便推车', price: 899, image: 'p_婴儿轻便推车_1781524671742_1.png', images: JSON.stringify(['p_婴儿轻便推车_1781524671742_1.png','p_婴儿轻便推车_1781524671742_2.png']), category: '母婴>推车', shop_id: 1, stock: 30, description: '轻便可折叠，单手收车，可坐可躺',
      specs: JSON.stringify([{name:'颜色',values:['黑色','灰色','蓝色']}]),
      skus: JSON.stringify([{id:'stroller-black',specs:{'颜色':'黑色'},price:899,stock:12},{id:'stroller-gray',specs:{'颜色':'灰色'},price:899,stock:10},{id:'stroller-blue',specs:{'颜色':'蓝色'},price:949,stock:8}]) },
    { id: 69, name: '宠物航空箱', price: 169, image: 'p_宠物航空箱_1781524671760_1.png', images: JSON.stringify(['p_宠物航空箱_1781524671760_1.png','p_宠物航空箱_1781524671760_2.png']), category: '宠物>宠物用品', shop_id: 1, stock: 80, description: '耐冲击PP材质，透气通风，航空托运标准',
      specs: JSON.stringify([{name:'规格',values:['S号(5kg内)','M号(10kg内)','L号(20kg内)']}]),
      skus: JSON.stringify([{id:'petbox-s',specs:{'规格':'S号(5kg内)'},price:119,stock:30},{id:'petbox-m',specs:{'规格':'M号(10kg内)'},price:169,stock:30},{id:'petbox-l',specs:{'规格':'L号(20kg内)'},price:249,stock:20}]) },
    { id: 70, name: '猫爬架大型', price: 399, image: 'p_猫爬架大型_1781524671777_1.png', images: JSON.stringify(['p_猫爬架大型_1781524671777_1.png','p_猫爬架大型_1781524671777_2.png']), category: '宠物>宠物玩具', shop_id: 1, stock: 40, description: '多层跳台猫树，剑麻柱磨爪，吊床设计',
      specs: JSON.stringify([{name:'层数',values:['小号(3层)','中号(5层)','大号(7层)']}]),
      skus: JSON.stringify([{id:'cat-tree-s',specs:{'层数':'小号(3层)'},price:199,stock:15},{id:'cat-tree-m',specs:{'层数':'中号(5层)'},price:399,stock:15},{id:'cat-tree-l',specs:{'层数':'大号(7层)'},price:599,stock:10}]) },
    { id: 71, name: '宠物体内外驱虫药', price: 89, image: 'p_宠物体内外驱虫药_1781524671793_1.png', images: JSON.stringify(['p_宠物体内外驱虫药_1781524671793_1.png','p_宠物体内外驱虫药_1781524671793_2.png']), category: '宠物>宠物医疗', shop_id: 1, stock: 300, description: '猫狗通用体内外驱虫，滴剂设计，方便使用',
      specs: JSON.stringify([{name:'适用',values:['猫用','狗用(小型)','狗用(中型)','狗用(大型)']}]),
      skus: JSON.stringify([{id:'deworm-cat',specs:{'适用':'猫用'},price:89,stock:100},{id:'deworm-dog-s',specs:{'适用':'狗用(小型)'},price:79,stock:80},{id:'deworm-dog-m',specs:{'适用':'狗用(中型)'},price:89,stock:80},{id:'deworm-dog-l',specs:{'适用':'狗用(大型)'},price:99,stock:40}]) },
    { id: 72, name: '北欧简约书桌', price: 699, image: 'p_北欧简约书桌_1781524671809_1.png', images: JSON.stringify(['p_北欧简约书桌_1781524671809_1.png','p_北欧简约书桌_1781524671809_2.png']), category: '家装>家具', shop_id: 1, stock: 40, description: '实木书桌，简约设计，居家办公学习',
      specs: JSON.stringify([{name:'颜色',values:['原木色','胡桃色','白色']},{name:'尺寸',values:['100cm','120cm','140cm']}]),
      skus: JSON.stringify([{id:'desk-wood-100',specs:{'颜色':'原木色','尺寸':'100cm'},price:699,stock:15},{id:'desk-walnut-120',specs:{'颜色':'胡桃色','尺寸':'120cm'},price:899,stock:15},{id:'desk-white-140',specs:{'颜色':'白色','尺寸':'140cm'},price:1099,stock:10}]) },
    { id: 73, name: '苏泊尔铸铁炒锅', price: 199, image: 'p_苏泊尔铸铁炒锅_1781524671827_1.png', images: JSON.stringify(['p_苏泊尔铸铁炒锅_1781524671827_1.png','p_苏泊尔铸铁炒锅_1781524671827_2.png']), category: '家装>厨具', shop_id: 1, stock: 200, description: '无涂层铸铁炒锅，物理不粘，导热均匀',
      specs: JSON.stringify([{name:'规格',values:['32cm','34cm','36cm']}]),
      skus: JSON.stringify([{id:'supor-32cm',specs:{'规格':'32cm'},price:199,stock:80},{id:'supor-34cm',specs:{'规格':'34cm'},price:229,stock:70},{id:'supor-36cm',specs:{'规格':'36cm'},price:259,stock:50}]) },
    { id: 74, name: '北欧装饰画', price: 99, image: 'p_北欧装饰画_1781524671844_1.png', images: JSON.stringify(['p_北欧装饰画_1781524671844_1.png','p_北欧装饰画_1781524671844_2.png']), category: '家装>装饰', shop_id: 1, stock: 200, description: '抽象艺术画芯，简约画框，客厅卧室装饰',
      specs: JSON.stringify([{name:'尺寸',values:['30×40cm','40×50cm','50×70cm']},{name:'风格',values:['抽象','风景','植物','文字']}]),
      skus: JSON.stringify([{id:'art-abstract-40x50',specs:{'尺寸':'40×50cm','风格':'抽象'},price:99,stock:30},{id:'art-landscape-50x70',specs:{'尺寸':'50×70cm','风格':'风景'},price:149,stock:25},{id:'art-plant-30x40',specs:{'尺寸':'30×40cm','风格':'植物'},price:79,stock:35}]) },
    { id: 75, name: '嘉实多机油保养套餐', price: 399, image: 'p_嘉实多机油保养套餐_1781524671861_1.png', images: JSON.stringify(['p_嘉实多机油保养套餐_1781524671861_1.png','p_嘉实多机油保养套餐_1781524671861_2.png']), category: '汽车>维修保养', shop_id: 2, stock: 100, description: '全合成机油5W-30，含机滤工时',
      specs: JSON.stringify([{name:'规格',values:['4L装','5L装','6L装']}]),
      skus: JSON.stringify([{id:'castrol-4l',specs:{'规格':'4L装'},price:399,stock:40},{id:'castrol-5l',specs:{'规格':'5L装'},price:479,stock:35},{id:'castrol-6l',specs:{'规格':'6L装'},price:559,stock:25}]) },
    { id: 76, name: '汽车四季坐垫', price: 299, image: 'p_汽车四季坐垫_1781524671882_1.png', images: JSON.stringify(['p_汽车四季坐垫_1781524671882_1.png','p_汽车四季坐垫_1781524671882_2.png']), category: '汽车>车饰', shop_id: 1, stock: 80, description: '四季通用，透气网眼，防滑底垫',
      specs: JSON.stringify([{name:'颜色',values:['黑色','米色','棕色']}]),
      skus: JSON.stringify([{id:'seat-black',specs:{'颜色':'黑色'},price:299,stock:30},{id:'seat-beige',specs:{'颜色':'米色'},price:299,stock:30},{id:'seat-brown',specs:{'颜色':'棕色'},price:319,stock:20}]) },
    { id: 77, name: '汽车全包围脚垫', price: 199, image: 'p_汽车全包围脚垫_1781524671899_1.png', images: JSON.stringify(['p_汽车全包围脚垫_1781524671899_1.png','p_汽车全包围脚垫_1781524671899_2.png']), category: '汽车>脚垫', shop_id: 1, stock: 100, description: 'TPE环保材质，全包围防水，易清洁',
      specs: JSON.stringify([{name:'颜色',values:['黑色','灰色','棕色']}]),
      skus: JSON.stringify([{id:'mat-black',specs:{'颜色':'黑色'},price:199,stock:40},{id:'mat-gray',specs:{'颜色':'灰色'},price:199,stock:35},{id:'mat-brown',specs:{'颜色':'棕色'},price:219,stock:25}]) },
    { id: 78, name: '鱼跃血压计', price: 269, image: 'p_鱼跃血压计_1781524671916_1.png', images: JSON.stringify(['p_鱼跃血压计_1781524671916_1.png','p_鱼跃血压计_1781524671916_2.png']), category: '医药>医疗器械', shop_id: 1, stock: 100, description: '上臂式电子血压计，大屏显示，智能语音播报',
      specs: JSON.stringify([{name:'型号',values:['标准款','语音款','蓝牙款']}]),
      skus: JSON.stringify([{id:'yuwell-standard',specs:{'型号':'标准款'},price:219,stock:40},{id:'yuwell-voice',specs:{'型号':'语音款'},price:269,stock:35},{id:'yuwell-bluetooth',specs:{'型号':'蓝牙款'},price:329,stock:25}]) },
    { id: 79, name: '冈本超薄避孕套', price: 79, image: 'p_冈本超薄避孕套_1781524671932_1.png', images: JSON.stringify(['p_冈本超薄避孕套_1781524671932_1.png','p_冈本超薄避孕套_1781524671932_2.png']), category: '医药>计生用品', shop_id: 1, stock: 500, description: '0.01mm超薄，日本进口，安全无忧',
      specs: JSON.stringify([{name:'规格',values:['10只装','20只装','30只装']}]),
      skus: JSON.stringify([{id:'okamoto-10',specs:{'规格':'10只装'},price:39,stock:250},{id:'okamoto-20',specs:{'规格':'20只装'},price:79,stock:150},{id:'okamoto-30',specs:{'规格':'30只装'},price:109,stock:100}]) },
    { id: 80, name: '防蓝光眼镜', price: 199, image: 'p_防蓝光眼镜_1781524671950_1.png', images: JSON.stringify(['p_防蓝光眼镜_1781524671950_1.png','p_防蓝光眼镜_1781524671950_2.png']), category: '医药>眼镜', shop_id: 1, stock: 200, description: 'TR90超轻镜架，防蓝光防辐射，办公护眼',
      specs: JSON.stringify([{name:'颜色',values:['黑色','玳瑁色','透明']},{name:'款式',values:['方框','圆框','猫眼']}]),
      skus: JSON.stringify([{id:'glass-black-square',specs:{'颜色':'黑色','款式':'方框'},price:199,stock:50},{id:'glass-tortoise-round',specs:{'颜色':'玳瑁色','款式':'圆框'},price:219,stock:40},{id:'glass-clear-cat',specs:{'颜色':'透明','款式':'猫眼'},price:219,stock:30}]) },
  ];

  const stmt = db.prepare('INSERT INTO products (id, name, price, image, images, category, description, specs, skus, shop_id, stock) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  for (const p of products) {
    stmt.bind([p.id, p.name, p.price, p.image, p.images, p.category, p.description, p.specs, p.skus, p.shop_id, p.stock]);
    stmt.step();
    stmt.reset();
  }
  stmt.free();

  const reviews = [
    // ── 手机 (1-4) ──
    { productId: 1, username: '数码达人', rating: 5, date: '2026-05-20', comment: '麒麟芯片回归，性能非常强悍！' },
    { productId: 1, username: '科技爱好者', rating: 5, date: '2026-05-18', comment: '外观质感很好，系统流畅，续航给力。' },
    { productId: 1, username: '商务精英', rating: 4, date: '2026-05-15', comment: '卫星通话功能很实用，信号比iPhone强太多。' },
    { productId: 2, username: '果粉一号', rating: 5, date: '2026-05-21', comment: '一如既往的好用，iOS生态无敌。' },
    { productId: 2, username: '摄影爱好者', rating: 4, date: '2026-05-19', comment: '拍照升级明显，但充电速度还是太慢了。' },
    { productId: 3, username: '程序员老王', rating: 5, date: '2026-05-22', comment: '屏幕素质很好，性能强劲。' },
    { productId: 3, username: '大学生小李', rating: 4, date: '2026-05-20', comment: '学习办公足够用，2.5K屏幕看视频很爽。' },
    { productId: 4, username: '性价比党', rating: 5, date: '2026-05-25', comment: '这个价位无敌手，性能完全够用。' },
    { productId: 4, username: '学生党小明', rating: 4, date: '2026-05-23', comment: '120W快充太爽了，电池耐用。' },
    // ── 电脑 (5-7) ──
    { productId: 5, username: '打工人小张', rating: 4, date: '2026-05-24', comment: '办公性能足够，屏幕素质不错。' },
    { productId: 5, username: '设计师Anna', rating: 3, date: '2026-05-22', comment: '色准还可以，但散热噪音偏大。' },
    { productId: 6, username: '移动办公族', rating: 5, date: '2026-05-26', comment: '续航太强了，一天不用充电。' },
    { productId: 6, username: '程序员阿强', rating: 5, date: '2026-05-24', comment: 'M3芯片编译速度飞快，风扇都不转。' },
    { productId: 7, username: '商务精英', rating: 5, date: '2026-05-23', comment: '3.1K OLED屏幕惊艳，触控方便。' },
    { productId: 7, username: '华为全家桶', rating: 4, date: '2026-05-21', comment: '超级终端太好用了，和手机无缝协同。' },
    // ── 配件 (8-16) ──
    { productId: 8, username: '音乐发烧友', rating: 5, date: '2026-05-23', comment: '降噪效果顶级，值得升级。' },
    { productId: 8, username: '通勤族', rating: 5, date: '2026-05-21', comment: '坐地铁必备，降噪一开世界安静了。' },
    { productId: 10, username: '装修达人', rating: 4, date: '2026-05-25', comment: '1.5匹制冷够用，一级能效省电。' },
    { productId: 10, username: '家电小白', rating: 4, date: '2026-05-23', comment: '安装师傅很专业，冷暖效果都不错。' },
    { productId: 11, username: '实用主义者', rating: 4, date: '2026-05-22', comment: '10kg容量够大，洗得干净噪音小。' },
    { productId: 11, username: '居家达人', rating: 3, date: '2026-05-20', comment: '性价比还行，但脱水声音有点大。' },
    { productId: 12, username: '家庭主妇', rating: 5, date: '2026-05-24', comment: '470升很大，分区合理不串味。' },
    { productId: 12, username: '囤货族', rating: 4, date: '2026-05-22', comment: '风冷无霜不用除冰，噪音也很小。' },
    { productId: 14, username: '数码控', rating: 5, date: '2026-05-26', comment: '氮化镓技术就是好，发热小效率高。' },
    { productId: 14, username: '上班族小王', rating: 4, date: '2026-05-24', comment: '三口输出很方便，同时充三个设备。' },
    { productId: 15, username: '学生党', rating: 4, date: '2026-05-23', comment: '便宜好用，两根换着用够一年了。' },
    { productId: 15, username: '简约生活', rating: 3, date: '2026-05-21', comment: '偶尔会有接触不良的情况。' },
    { productId: 16, username: '游戏玩家', rating: 4, date: '2026-05-25', comment: '小米生态链产品，性价比不错。' },
    { productId: 16, username: '户外达人', rating: 3, date: '2026-05-23', comment: '用了半年感觉容量有所下降。' },
    // ── 家电 (9, 13, 17-18) ──
    { productId: 9, username: '家庭用户', rating: 5, date: '2026-05-22', comment: '75寸很震撼，4K画质清晰。' },
    { productId: 9, username: '游戏玩家', rating: 4, date: '2026-05-19', comment: '120Hz打游戏很流畅。' },
    { productId: 13, username: '懒人一族', rating: 5, date: '2026-05-26', comment: '扫地干净，自动集尘太省心了。' },
    { productId: 13, username: '宝妈小刘', rating: 4, date: '2026-05-24', comment: '导航精准不撞墙，每天扫一遍家里干净多了。' },
    { productId: 17, username: '智能家居控', rating: 4, date: '2026-05-25', comment: '小爱同学反应灵敏，控制家电很方便。' },
    { productId: 17, username: '科技老爷爷', rating: 5, date: '2026-05-23', comment: '声音清晰，放音乐效果也不错。' },
    { productId: 18, username: '口腔护理控', rating: 5, date: '2026-05-24', comment: '比手动牙刷刷得干净多了，牙齿明显变白。' },
    { productId: 18, username: '牙医推荐', rating: 4, date: '2026-05-22', comment: '震动频率合适，压力感应很实用。' },
    // ── 服装美妆 (19-20) ──
    { productId: 19, username: '简约风女孩', rating: 4, date: '2026-05-23', comment: '纯棉面料很舒服，版型也不错。' },
    { productId: 19, username: '品质生活家', rating: 3, date: '2026-05-21', comment: '洗了几次领口有点变形。' },
    { productId: 20, username: '美妆达人', rating: 5, date: '2026-05-25', comment: '迪奥999经典色号，黄皮显白神器。' },
    { productId: 20, username: '化妆师Lily', rating: 4, date: '2026-05-23', comment: '质地丝滑不拔干，颜色很正。' },
    // ── 食品 (21-23) ──
    { productId: 21, username: '吃货一号', rating: 4, date: '2026-05-24', comment: '种类丰富，坚果新鲜，追剧必备。' },
    { productId: 21, username: '办公室零食', rating: 5, date: '2026-05-22', comment: '同事们都抢着吃，已经回购三次了。' },
    { productId: 22, username: '茶艺爱好者', rating: 5, date: '2026-05-25', comment: '明前龙井香气清新，口感回甘。' },
    { productId: 22, username: '送礼达人', rating: 4, date: '2026-05-23', comment: '包装精美送人很有面子，茶叶品质好。' },
    { productId: 23, username: '煮饭婆', rating: 4, date: '2026-05-22', comment: '米粒饱满口感好，比超市便宜。' },
    { productId: 23, username: '东北老乡', rating: 5, date: '2026-05-20', comment: '正宗五常大米，开袋就能闻到米香。' },
    // ── 图书 (24-26) ──
    { productId: 24, username: '科幻迷', rating: 5, date: '2026-05-26', comment: '中国科幻的巅峰之作，震撼心灵。' },
    { productId: 24, username: '读书人老李', rating: 5, date: '2026-05-24', comment: '每看一次都有新的感悟，经典中的经典。' },
    { productId: 25, username: '编程初学者', rating: 5, date: '2026-05-23', comment: '通俗易懂，跟着练习Python入门很快。' },
    { productId: 25, username: '转行IT大叔', rating: 4, date: '2026-05-21', comment: '内容全面，适合零基础系统学习。' },
    { productId: 26, username: '亲子阅读', rating: 5, date: '2026-05-22', comment: '插图精美，孩子每晚都要读一遍。' },
    { productId: 26, username: '文艺青年', rating: 4, date: '2026-05-20', comment: '装帧精致，经典童话永不过时。' },
    // ── 运动 (27-29) ──
    { productId: 27, username: '跑者无疆', rating: 5, date: '2026-05-25', comment: '䨻科技回弹明显，半马PB了。' },
    { productId: 27, username: '马拉松菜鸟', rating: 4, date: '2026-05-23', comment: '缓震很好颜值也高，国货之光。' },
    { productId: 28, username: '瑜伽爱好者', rating: 4, date: '2026-05-22', comment: '防滑效果不错，厚度适中。' },
    { productId: 28, username: '健身小白', rating: 3, date: '2026-05-20', comment: '便宜够用，但用久了有点压痕。' },
    { productId: 29, username: '户外露营', rating: 4, date: '2026-05-24', comment: '自动速开很方便，防雨效果OK。' },
    { productId: 29, username: '亲子户外', rating: 5, date: '2026-05-22', comment: '空间够大一家三口用，收纳也方便。' },
    // ── 母婴 (30-32) ──
    { productId: 30, username: '新手妈妈', rating: 4, date: '2026-05-23', comment: '宝宝爱喝，不上火消化好。' },
    { productId: 30, username: '育儿达人', rating: 5, date: '2026-05-21', comment: '荷兰进口品质放心，营养全面。' },
    { productId: 31, username: '宝妈小周', rating: 4, date: '2026-05-24', comment: '透气不红PP，吸量大一夜一片。' },
    { productId: 31, username: '二胎妈妈', rating: 5, date: '2026-05-22', comment: '用了很多品牌还是帮宝适最好用。' },
    { productId: 32, username: '乐高粉丝', rating: 5, date: '2026-05-25', comment: '颗粒多玩法多样，孩子能玩一下午。' },
    { productId: 32, username: '幼教老师', rating: 5, date: '2026-05-23', comment: '培养创造力和耐心，寓教于乐。' },
    // ── 宠物 (33-34) ──
    { productId: 33, username: '铲屎官老王', rating: 4, date: '2026-05-22', comment: '狗狗爱吃，毛色变亮了不少。' },
    { productId: 33, username: '爱宠人士', rating: 3, date: '2026-05-20', comment: '性价比一般，但品质有保障。' },
    { productId: 34, username: '猫奴日常', rating: 4, date: '2026-05-23', comment: '猫咪很喜欢，每次都吃光光。' },
    { productId: 34, username: '养猫老手', rating: 3, date: '2026-05-21', comment: '价格实惠但猫粮颗粒有点大。' },
    // ── 家装 (35-36) ──
    { productId: 35, username: '装修达人', rating: 5, date: '2026-05-24', comment: '台灯颜值高，三档色温调节很实用。' },
    { productId: 35, username: '熬夜程序员', rating: 4, date: '2026-05-22', comment: '护眼效果不错，长时间用眼不累。' },
    { productId: 36, username: '家居博主', rating: 4, date: '2026-05-23', comment: '60支面料很细腻，颜色也很正。' },
    { productId: 36, username: '家庭主妇', rating: 5, date: '2026-05-21', comment: '柔软舒适不起球，洗了也不褪色。' },
    // ── 汽车 (37-38) ──
    { productId: 37, username: '老司机', rating: 4, date: '2026-05-22', comment: '快充效果好，做工扎实。' },
    { productId: 37, username: '自驾游达人', rating: 3, date: '2026-05-20', comment: '用了三个月有点接触不良。' },
    { productId: 38, username: '安全驾驶', rating: 5, date: '2026-05-25', comment: '2K画质清晰，ADAS提醒很准。' },
    { productId: 38, username: '滴滴司机', rating: 4, date: '2026-05-23', comment: '夜视效果不错，停车监控也安心。' },
    // ── 医药 (39-40) ──
    { productId: 39, username: '居家必备', rating: 4, date: '2026-05-22', comment: '家庭常备，透气性好止血快。' },
    { productId: 39, username: '宝妈', rating: 5, date: '2026-05-20', comment: '孩子调皮必备品，100片够用很久。' },
    { productId: 40, username: '养生达人', rating: 4, date: '2026-05-23', comment: '维生素C含量足，坚持吃感冒少了。' },
    { productId: 40, username: '健身教练', rating: 3, date: '2026-05-21', comment: '效果还行，但性价比不如药店品牌。' },
    // ── OPPO Find X7 Ultra (41) ──
    { productId: 41, username: '摄影发烧友', rating: 5, date: '2026-06-01', comment: '哈苏色彩太棒了，双潜望长焦无敌。' },
    { productId: 41, username: '手机控', rating: 4, date: '2026-06-01', comment: '拍照确实强，但系统还有优化空间。' },
    // ── vivo X100 Pro (42) ──
    { productId: 42, username: '蔡司粉丝', rating: 5, date: '2026-06-01', comment: '蔡司镜头拍人像绝了，续航也很给力。' },
    { productId: 42, username: '数码博主', rating: 4, date: '2026-06-01', comment: '天玑9300性能释放很猛，日常使用流畅。' },
    // ── 三星S24 Ultra (43) ──
    { productId: 43, username: '商务人士', rating: 4, date: '2026-06-02', comment: '钛金属质感很好，S Pen写笔记方便。' },
    { productId: 43, username: '安卓老用户', rating: 5, date: '2026-06-02', comment: 'Galaxy AI翻译功能太实用了。' },
    // ── 荣耀Magic6 Pro (44) ──
    { productId: 44, username: '摄影爱好者', rating: 5, date: '2026-06-02', comment: '鹰眼相机抓拍一绝，青海湖电池耐用。' },
    { productId: 44, username: '荣耀铁粉', rating: 4, date: '2026-06-02', comment: '巨犀玻璃摔了好几次都没事。' },
    // ── 华硕灵耀14 (45) ──
    { productId: 45, username: '商务白领', rating: 5, date: '2026-06-03', comment: '轻薄便携，OLED屏幕太惊艳了。' },
    { productId: 45, username: '出差党', rating: 4, date: '2026-06-03', comment: '续航优秀，出差一整天不用充电。' },
    // ── 戴尔XPS 16 (46) ──
    { productId: 46, username: '设计师小王', rating: 5, date: '2026-06-03', comment: '4K OLED屏幕色彩精准，剪视频利器。' },
    { productId: 46, username: '程序猿', rating: 4, date: '2026-06-03', comment: '性能强劲，就是价格有点小贵。' },
    // ── 惠普战66 (47) ──
    { productId: 47, username: '财务姐姐', rating: 4, date: '2026-06-04', comment: '办公够用，性价比高，接口齐全。' },
    { productId: 47, username: '学生党', rating: 5, date: '2026-06-04', comment: '做作业编程够用，屏幕大看文档舒服。' },
    // ── 手机壳 (48) ──
    { productId: 48, username: '裸机党', rating: 4, date: '2026-06-04', comment: '透明壳手感好，不发黄。' },
    { productId: 48, username: '实用主义者', rating: 5, date: '2026-06-04', comment: '便宜好用，摔了好几次手机没事。' },
    // ── 钢化膜 (49) ──
    { productId: 49, username: '手滑党', rating: 4, date: '2026-06-05', comment: '贴上去很顺滑，指纹解锁灵敏。' },
    { productId: 49, username: '完美主义者', rating: 3, date: '2026-06-05', comment: '边缘有一点点白边，总体可以接受。' },
    // ── 海尔热水器 (50) ──
    { productId: 50, username: '装修达人', rating: 5, date: '2026-06-05', comment: '60L够一家三口用了，加热快。' },
    { productId: 50, username: '家庭主妇', rating: 4, date: '2026-06-05', comment: '防电墙技术用着安心。' },
    // ── 得力打印机 (51) ──
    { productId: 51, username: '居家办公', rating: 4, date: '2026-06-06', comment: '手机打印很方便，孩子作业随打。' },
    // ── 智能窗帘 (52) ──
    { productId: 52, username: '智能家居控', rating: 5, date: '2026-06-06', comment: '小爱语音控制太方便了，早上自动拉开。' },
    // ── 破壁机 (53) ──
    { productId: 53, username: '养生达人', rating: 4, date: '2026-06-06', comment: '打豆浆很细腻，清洗也方便。' },
    // ── 连衣裙 (54) ──
    { productId: 54, username: '时尚小姐姐', rating: 5, date: '2026-06-07', comment: '碎花很清新，夏天穿很舒服。' },
    // ── AF1 (55) ──
    { productId: 55, username: '鞋狗', rating: 5, date: '2026-06-07', comment: '经典中的经典，百搭小白鞋必备。' },
    // ── 百丽皮鞋 (56) ──
    { productId: 56, username: '上班族', rating: 4, date: '2026-06-07', comment: '皮子很软不磨脚，商务休闲两穿。' },
    // ── COACH包 (57) ──
    { productId: 57, username: '轻奢girl', rating: 5, date: '2026-06-08', comment: '经典老花太好看了，通勤背很合适。' },
    // ── 兰蔻精华 (58) ──
    { productId: 58, username: '护肤达人', rating: 5, date: '2026-06-08', comment: '小黑瓶维稳效果绝了，皮肤变细腻了。' },
    // ── 爱马仕香水 (59) ──
    { productId: 59, username: '香水控', rating: 5, date: '2026-06-08', comment: '木质调太上头了，留香时间很长。' },
    // ── 卡诗 (60) ──
    { productId: 60, username: '烫染受损发质', rating: 4, date: '2026-06-09', comment: '修护效果明显，洗完头发很顺滑。' },
    // ── 牛排 (61) ──
    { productId: 61, username: '吃货老王', rating: 5, date: '2026-06-09', comment: '肉质鲜嫩多汁，比超市划算多了。' },
    // ── 茅台 (62) ──
    { productId: 62, username: '酒友', rating: 5, date: '2026-06-09', comment: '正品飞天，酱香浓郁，送礼有面子。' },
    // ── 新概念 (63) ──
    { productId: 63, username: '英语老师', rating: 5, date: '2026-06-10', comment: '经典教材，配套练习很全面。' },
    // ── 断舍离 (64) ──
    { productId: 64, username: '极简主义者', rating: 4, date: '2026-06-10', comment: '看完把家里收拾了一遍，很治愈的书。' },
    // ── 哑铃 (65) ──
    { productId: 65, username: '健身小白', rating: 4, date: '2026-06-10', comment: '20kg家用够用了，包胶不伤地板。' },
    // ── 头盔 (66) ──
    { productId: 66, username: '骑行爱好者', rating: 5, date: '2026-06-11', comment: '通风很好不闷热，重量轻。' },
    // ── 连体衣 (67) ──
    { productId: 67, username: '新手妈妈', rating: 5, date: '2026-06-11', comment: '纯棉面料很软，按扣换尿布方便。' },
    // ── 推车 (68) ──
    { productId: 68, username: '宝妈小周', rating: 4, date: '2026-06-11', comment: '单手收车很方便，轻便好推。' },
    // ── 航空箱 (69) ──
    { productId: 69, username: '养猫人', rating: 4, date: '2026-06-12', comment: '带猫去宠物医院很方便，透气好。' },
    // ── 猫爬架 (70) ──
    { productId: 70, username: '猫奴日常', rating: 5, date: '2026-06-12', comment: '猫咪特别喜欢，天天在上面睡觉。' },
    // ── 驱虫药 (71) ──
    { productId: 71, username: '铲屎官', rating: 4, date: '2026-06-12', comment: '滴剂很方便，定期驱虫放心。' },
    // ── 书桌 (72) ──
    { productId: 72, username: '居家办公族', rating: 5, date: '2026-06-13', comment: '实木质感很好，120cm宽敞够用。' },
    // ── 炒锅 (73) ──
    { productId: 73, username: '家庭煮夫', rating: 4, date: '2026-06-13', comment: '铁锅炒菜有锅气，无涂层用着放心。' },
    // ── 装饰画 (74) ──
    { productId: 74, username: '家居博主', rating: 5, date: '2026-06-13', comment: '挂上后客厅格调立马不一样了。' },
    // ── 机油 (75) ──
    { productId: 75, username: '老司机', rating: 4, date: '2026-06-14', comment: '全合成机油品质好，换完发动机声音小了。' },
    // ── 坐垫 (76) ──
    { productId: 76, username: '车主', rating: 4, date: '2026-06-14', comment: '透气不闷热，四季通用。' },
    // ── 脚垫 (77) ──
    { productId: 77, username: '爱车人士', rating: 5, date: '2026-06-14', comment: 'TPE没异味，防水好清理。' },
    // ── 血压计 (78) ──
    { productId: 78, username: '退休老人', rating: 5, date: '2026-06-15', comment: '语音播报方便老人使用，测量准确。' },
    // ── 冈本 (79) ──
    { productId: 79, username: '匿名用户', rating: 5, date: '2026-06-15', comment: '超薄体验很好，和没戴一样。' },
    // ── 防蓝光眼镜 (80) ──
    { productId: 80, username: '程序员老张', rating: 4, date: '2026-06-15', comment: '戴了一天眼睛不累了，镜架也很轻。' },
  ];
  const rStmt = db.prepare('INSERT INTO reviews (product_id, username, rating, date, comment) VALUES (?, ?, ?, ?, ?)');
  for (const r of reviews) {
    rStmt.bind([r.productId, r.username, r.rating, r.date, r.comment]);
    rStmt.step();
    rStmt.reset();
  }
  rStmt.free();

  const coupons = [
    { name: '新人专享券', type: 'direct', value: 10, min_amount: 50, total_count: 1000 },
    { name: '满500减50', type: 'direct', value: 50, min_amount: 500, total_count: 500 },
    { name: '满1000减120', type: 'direct', value: 120, min_amount: 1000, total_count: 200 },
  ];
  const cStmt = db.prepare('INSERT INTO coupons (name, type, value, min_amount, total_count, status) VALUES (?, ?, ?, ?, ?, ?)');
  for (const c of coupons) {
    const now = new Date();
    const end = new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000);
    cStmt.bind([c.name, c.type, c.value, c.min_amount, c.total_count, 'active']);
    cStmt.step();
    cStmt.reset();
  }
  cStmt.free();

  // Seed categories from products
  const catRows = all("SELECT DISTINCT category FROM products WHERE category != '' ORDER BY category");
  const seen = {};
  const catInserts = [];
  for (const r of catRows) {
    const parts = r.category.split('>');
    let full = '';
    for (let i = 0; i < parts.length; i++) {
      const name = parts[i].trim();
      if (!name) continue;
      full = full ? full + '>' + name : name;
      if (!seen[full]) {
        seen[full] = true;
        catInserts.push({ name, full, level: i + 1 });
      }
    }
  }
  const catStmt = db.prepare('INSERT OR IGNORE INTO categories (name, full_path, level, sort_order) VALUES (?, ?, ?, ?)');
  let catOrder = 0;
  for (const ins of catInserts) {
    catStmt.bind([ins.name, ins.full, ins.level, catOrder++]);
    catStmt.step();
    catStmt.reset();
  }
  catStmt.free();
  // Set parent_id for subcategories
  const allCats = all('SELECT id, full_path, level FROM categories');
  for (const cat of allCats) {
    if (cat.level > 1) {
      const idx = cat.full_path.lastIndexOf('>');
      const parentPath = cat.full_path.substring(0, idx);
      const parent = allCats.find(c => c.full_path === parentPath);
      if (parent) {
        run('UPDATE categories SET parent_id = ? WHERE id = ?', [parent.id, cat.id]);
      }
    }
  }
}

function healthCheck() {
  if (!db) return { status: 'disconnected', dbSize: 0, tableCount: 0 };
  try {
    const tables = all("SELECT name FROM sqlite_master WHERE type='table'");
    let dbSize = 0;
    try {
      dbSize = fs.statSync(DB_PATH).size;
    } catch {}
    return {
      status: 'connected',
      dbSize,
      tableCount: tables.length,
    };
  } catch (err) {
    return { status: 'error', dbSize: 0, tableCount: 0, error: err.message };
  }
}

let bgInterval = null;

const AUTO_RECEIPT_DAYS = 7;

function startBackgroundTasks() {
  if (bgInterval) return;
  bgInterval = setInterval(() => {
    try {
      if (!db) return;
      const now = new Date();
      const nowISO = now.toISOString();

      // 1. Auto-cancel unpaid orders that have passed payment deadline
      const expired = all("SELECT * FROM orders WHERE status = ? AND payment_deadline != '' AND payment_deadline < ?",
        ['待付款', nowISO]);
      for (const o of expired) {
        run("UPDATE orders SET status = ?, cancel_reason = ? WHERE order_number = ?",
          ['已取消', '超时未付款已自动取消', o.order_number]);
        const items = all('SELECT product_id, quantity FROM order_items WHERE order_number = ?', [o.order_number]);
        for (const item of items) {
          run('UPDATE products SET stock = stock + ? WHERE id = ?', [item.quantity, item.product_id]);
        }
        run("INSERT INTO messages (username, order_number, type, title, content, is_read, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)",
          [o.username, o.order_number, 'order', '订单已取消', '您的订单因超时未付款已自动取消', nowISO]);
      }
      if (expired.length > 0) {
        logger.info(`Auto-cancelled ${expired.length} expired orders`);
      }

      // 2. Auto-confirm receipt for orders shipped over AUTO_RECEIPT_DAYS days ago
      const cutoff = new Date(now.getTime() - AUTO_RECEIPT_DAYS * 24 * 60 * 60 * 1000).toISOString();
      const pending = all("SELECT * FROM orders WHERE status = ? AND ship_time != '' AND ship_time < ?",
        ['配送中', cutoff]);
      for (const o of pending) {
        run("UPDATE orders SET status = ?, receive_time = ? WHERE order_number = ?",
          ['已完成', nowISO, o.order_number]);
        run("INSERT INTO messages (username, order_number, type, title, content, is_read, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)",
          [o.username, o.order_number, 'order', '订单已自动确认收货',
           '您的订单已超过' + AUTO_RECEIPT_DAYS + '天未确认，系统已自动确认收货。感谢您的购买！', nowISO]);
      }
      if (pending.length > 0) {
        logger.info(`Auto-confirmed ${pending.length} orders`);
      }

      // 3. Auto-expire coupons past end_time
      const expiredCount = all("SELECT COUNT(*) as count FROM coupons WHERE status = 'active' AND end_time != '' AND end_time < ?", [nowISO]);
      if (expiredCount[0].count > 0) {
        run("UPDATE coupons SET status = 'inactive' WHERE status = 'active' AND end_time != '' AND end_time < ?", [nowISO]);
        logger.info(`Auto-expired ${expiredCount[0].count} expired coupons`);
      }
    } catch (err) {
      logger.error('Background task error: ' + err.message);
    }
  }, 60000);
  logger.info('Background tasks started');
}

module.exports = { getDb, batch, startBackgroundTasks, healthCheck };
