jest.setTimeout(30000);

const request = require('supertest');
const path = require('path');
const fs = require('fs');

const dbPath = path.join(__dirname, '..', 'test_data.db');
try { fs.unlinkSync(dbPath); } catch {}
try { fs.unlinkSync(dbPath + '-journal'); } catch {}

process.env.DB_PATH = dbPath;
process.env.JWT_SECRET = 'test_secret';
process.env.NODE_ENV = 'test';
process.env.PORT = '0';

let app;
const TEST_USER = 'tu_' + Date.now().toString().slice(-8);
const TEST_PASS = 'test123456';
let authToken = '';
let refreshToken = '';
let testProductId = 1;
let testOrderNumber = '';
let testAddressId = 0;

beforeAll(async () => {
  app = require('../src/index');
  // Wait for DB to initialize (lazy async init)
  await new Promise(resolve => setTimeout(resolve, 3000));
  const res = await request(app)
    .post('/api/auth/register')
    .send({ username: TEST_USER, password: TEST_PASS });
  if (res.status === 200) {
    authToken = res.body.token;
    refreshToken = res.body.refreshToken;
  } else {
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ username: TEST_USER, password: TEST_PASS });
    authToken = loginRes.body.token;
    refreshToken = loginRes.body.refreshToken;
  }
  expect(authToken).toBeTruthy();
  // Set payment password for payment-dependent tests
  await request(app)
    .post('/api/auth/payment-password')
    .set('Authorization', `Bearer ${authToken}`)
    .send({ password: '123456' });
}, 20000);

afterAll(async () => {
  try { fs.unlinkSync(dbPath); } catch {}
  try { fs.unlinkSync(dbPath + '-journal'); } catch {}
});

// ──────────── Health ────────────
describe('Health Check', () => {
  test('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

// ──────────── Auth API ────────────
describe('Auth API', () => {
  let tempToken = '';

  test('POST /api/auth/register validates fields', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ username: 'ab', password: 'short' });
    expect(res.status).toBe(400);
  });

  test('POST /api/auth/register duplicate username', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ username: TEST_USER, password: TEST_PASS });
    expect(res.status).toBe(409);
  });

  test('POST /api/auth/login returns token + refreshToken', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: TEST_USER, password: TEST_PASS });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
    expect(res.body.username).toBe(TEST_USER);
    tempToken = res.body.token;
  });

  test('POST /api/auth/login wrong password', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: TEST_USER, password: 'wrongpass1' });
    expect(res.status).toBe(401);
  });

  test('GET /api/auth/profile requires auth', async () => {
    const res = await request(app).get('/api/auth/profile');
    expect(res.status).toBe(401);
  });

  test('GET /api/auth/profile with token returns profile', async () => {
    const res = await request(app)
      .get('/api/auth/profile')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
    expect(res.body.username).toBe(TEST_USER);
  });

  test('PUT /api/auth/profile updates fields', async () => {
    const res = await request(app)
      .put('/api/auth/profile')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ nickname: '新昵称', gender: '男', age: 25 });
    expect(res.status).toBe(200);
  });

  test('POST /api/auth/refresh returns new tokens', async () => {
    expect(refreshToken).toBeTruthy();
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
    // Update tokens
    authToken = res.body.token;
    refreshToken = res.body.refreshToken;
  });

  test('POST /api/auth/refresh rejects invalid token', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: 'invalid_token_here' });
    expect(res.status).toBe(401);
  });

  test('POST /api/auth/refresh requires token', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({});
    expect(res.status).toBe(400);
  });
});

// ──────────── Products API ────────────
describe('Products API', () => {
  test('GET /api/products returns paginated products', async () => {
    const res = await request(app)
      .get('/api/products?page=1&pageSize=5');
    expect(res.status).toBe(200);
    expect(res.body.items).toBeDefined();
    expect(res.body.items.length).toBeLessThanOrEqual(5);
    expect(res.body.total).toBeGreaterThan(0);
    expect(res.body.page).toBe(1);
    expect(res.body.totalPages).toBeGreaterThan(0);
  });

  test('GET /api/products?keyword=手机 filters', async () => {
    const res = await request(app)
      .get('/api/products?keyword=手机');
    expect(res.status).toBe(200);
    expect(res.body.items.length).toBeGreaterThan(0);
  });

  test('GET /api/products/categories returns categories', async () => {
    const res = await request(app).get('/api/products/categories');
    expect(res.status).toBe(200);
    expect(res.body.categories).toBeDefined();
    expect(Array.isArray(res.body.categories)).toBe(true);
  });

  test('GET /api/products/hot-keywords returns keywords', async () => {
    const res = await request(app).get('/api/products/hot-keywords');
    expect(res.status).toBe(200);
    expect(res.body.keywords).toBeDefined();
  });

  test('GET /api/products/:id returns product detail', async () => {
    const res = await request(app).get('/api/products/1');
    expect(res.status).toBe(200);
    expect(res.body.name).toBeDefined();
    expect(res.body.id).toBe(1);
    testProductId = res.body.id;
  });

  test('GET /api/products/99999 returns 404', async () => {
    const res = await request(app).get('/api/products/99999');
    expect(res.status).toBe(404);
  });
});

// ──────────── Cart API ────────────
describe('Cart API', () => {
  test('GET /api/cart requires auth', async () => {
    const res = await request(app).get('/api/cart');
    expect(res.status).toBe(401);
  });

  test('POST /api/cart adds item', async () => {
    const res = await request(app)
      .post('/api/cart')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ productId: testProductId, quantity: 2 });
    expect(res.status).toBe(200);
  });

  test('GET /api/cart returns items', async () => {
    const res = await request(app)
      .get('/api/cart')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('PUT /api/cart/:productId updates quantity', async () => {
    const res = await request(app)
      .put(`/api/cart/${testProductId}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ quantity: 3 });
    expect(res.status).toBe(200);
  });

  test('DELETE /api/cart/:productId removes item', async () => {
    const res = await request(app)
      .delete(`/api/cart/${testProductId}`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });
});

// ──────────── Order API ────────────
describe('Order API', () => {
  beforeAll(async () => {
    // Add item to cart for order creation
    await request(app)
      .post('/api/cart')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ productId: testProductId, quantity: 1 });
  });

  test('POST /api/orders creates order', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ address: '测试地址 100号' });
    expect(res.status).toBe(200);
    expect(res.body.orderNumber).toBeDefined();
    testOrderNumber = res.body.orderNumber;
  });

  test('GET /api/orders returns orders', async () => {
    const res = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toBeDefined();
    expect(res.body.items.length).toBeGreaterThan(0);
  });

  test('GET /api/orders/:orderNumber returns detail', async () => {
    const res = await request(app)
      .get(`/api/orders/${testOrderNumber}`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
    expect(res.body.orderNumber).toBe(testOrderNumber);
  });

  test('PUT /api/orders/:orderNumber/cancel cancels pending order', async () => {
    const res = await request(app)
      .put(`/api/orders/${testOrderNumber}/cancel`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });

  test('PUT /api/orders/:orderNumber/cancel on cancelled returns error', async () => {
    const res = await request(app)
      .put(`/api/orders/${testOrderNumber}/cancel`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(400);
  });
});

// ──────────── Payment API ────────────
describe('Payment API', () => {
  let payOrderNo = '';

  beforeAll(async () => {
    // Create a fresh order for payment test
    await request(app)
      .post('/api/cart')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ productId: testProductId === 1 ? 2 : 1, quantity: 1 });
    const orderRes = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ address: '支付测试地址' });
    payOrderNo = orderRes.body.orderNumber;
  });

  test('POST /api/payment/direct/:orderNumber pays order', async () => {
    const res = await request(app)
      .post(`/api/payment/direct/${payOrderNo}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ payMethod: '支付宝', paymentPassword: '123456' });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('待发货');
  });

  test('POST /api/payment/direct duplicate payment returns error', async () => {
    const res = await request(app)
      .post(`/api/payment/direct/${payOrderNo}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ payMethod: '支付宝', paymentPassword: '123456' });
    expect(res.status).toBe(400);
  });

  test('POST /api/payment/page/DD000000000000 returns 404', async () => {
    const res = await request(app)
      .post('/api/payment/page/DD0000000000000000')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(404);
  });
});

// ──────────── Receive Order ────────────
describe('Receive Order', () => {
  let shipOrderNo = '';
  let adminToken = '';

  beforeAll(async () => {
    // Login as admin
    const adminRes = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'admin123' });
    adminToken = adminRes.body.token;

    await request(app)
      .post('/api/cart')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ productId: 3, quantity: 1 });
    const orderRes = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ address: '收货测试地址' });
    shipOrderNo = orderRes.body.orderNumber;
    // Pay it first
    await request(app)
      .post(`/api/payment/direct/${shipOrderNo}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ payMethod: '支付宝', paymentPassword: '123456' });
    // Admin ships it
    await request(app)
      .put(`/api/admin/orders/${shipOrderNo}/ship`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ express_company: '顺丰快递', tracking_number: 'SF1234567890' });
  });

  test('PUT /api/orders/:orderNumber/receive confirms receipt', async () => {
    const res = await request(app)
      .put(`/api/orders/${shipOrderNo}/receive`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });
});

// ──────────── Address API ────────────
describe('Address API', () => {
  test('GET /api/addresses requires auth', async () => {
    const res = await request(app).get('/api/addresses');
    expect(res.status).toBe(401);
  });

  test('POST /api/addresses creates address', async () => {
    const res = await request(app)
      .post('/api/addresses')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        label: '家',
        recipientName: '张三',
        phone: '13800138000',
        detail: '北京市朝阳区100号',
        isDefault: true,
      });
    expect(res.status).toBe(200);
    expect(res.body.id).toBeDefined();
    testAddressId = res.body.id;
  });

  test('GET /api/addresses returns list', async () => {
    const res = await request(app)
      .get('/api/addresses')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('PUT /api/addresses/:id updates address', async () => {
    const res = await request(app)
      .put(`/api/addresses/${testAddressId}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ recipientName: '李四', phone: '13900139000' });
    expect(res.status).toBe(200);
  });

  test('DELETE /api/addresses/:id deletes address', async () => {
    const res = await request(app)
      .delete(`/api/addresses/${testAddressId}`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });
});

// ──────────── Favorites API ────────────
describe('Favorites API', () => {
  test('POST /api/favorites/:productId toggles favorite', async () => {
    const res = await request(app)
      .post(`/api/favorites/${testProductId}`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });

  test('GET /api/favorites returns list', async () => {
    const res = await request(app)
      .get('/api/favorites')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('GET /api/favorites/check/:ids verifies favorites', async () => {
    const res = await request(app)
      .get(`/api/favorites/check/${testProductId}`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });
});

// ──────────── Reviews API ────────────
describe('Reviews API', () => {
  let reviewAdminToken = '';

  beforeAll(async () => {
    // Complete an order for testProductId so the user can review it
    const adminRes = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'admin123' });
    reviewAdminToken = adminRes.body.token;

    await request(app)
      .post('/api/cart')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ productId: testProductId, quantity: 1 });
    const orderRes = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ address: '评价测试地址' });
    const reviewOrderNo = orderRes.body.orderNumber;
    // Pay
    await request(app)
      .post(`/api/payment/direct/${reviewOrderNo}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ payMethod: '支付宝', paymentPassword: '123456' });
    // Admin ships
    await request(app)
      .put(`/api/admin/orders/${reviewOrderNo}/ship`)
      .set('Authorization', `Bearer ${reviewAdminToken}`)
      .send({ express_company: '中通快递', tracking_number: 'ZT0987654321' });
    // Receive
    await request(app)
      .put(`/api/orders/${reviewOrderNo}/receive`)
      .set('Authorization', `Bearer ${authToken}`);
  });

  test('GET /api/reviews/product/:id returns reviews', async () => {
    const res = await request(app).get(`/api/reviews/product/${testProductId}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toBeDefined();
  });

  test('POST /api/reviews/product/:id requires auth', async () => {
    const res = await request(app)
      .post(`/api/reviews/product/${testProductId}`)
      .send({ rating: 5, comment: '好评！' });
    expect(res.status).toBe(401);
  });

  test('POST /api/reviews/product/:id adds review', async () => {
    const res = await request(app)
      .post(`/api/reviews/product/${testProductId}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ rating: 5, comment: '非常满意！' });
    expect(res.status).toBe(200);
  });
});

// ──────────── After-Sales API ────────────
describe('After-Sales API', () => {
  let aftersaleOrderNo = '';

  beforeAll(async () => {
    await request(app)
      .post('/api/cart')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ productId: 4, quantity: 1 });
    const orderRes = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ address: '售后测试地址' });
    aftersaleOrderNo = orderRes.body.orderNumber;
  });

  test('POST /api/aftersales creates refund request', async () => {
    // Pay the order first so it's eligible for aftersales
    await request(app)
      .post(`/api/payment/direct/${aftersaleOrderNo}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ payMethod: '支付宝', paymentPassword: '123456' });
    const res = await request(app)
      .post('/api/aftersales')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ orderNumber: aftersaleOrderNo, type: 'refund', reason: '不想要了' });
    expect(res.status).toBe(200);
    expect(res.body.message).toBe('售后申请已提交');
  });

  test('GET /api/aftersales returns records', async () => {
    const res = await request(app)
      .get('/api/aftersales')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
  });
});

// ──────────── Tracking API ────────────
describe('Tracking API', () => {
  test('GET /api/tracking/:orderNumber requires auth', async () => {
    const res = await request(app).get('/api/tracking/DD0000000000000001');
    expect(res.status).toBe(401);
  });

  test('GET /api/tracking/:orderNumber returns tracking', async () => {
    // Use the paid+received order
    const res = await request(app)
      .get(`/api/tracking/${testOrderNumber}`)
      .set('Authorization', `Bearer ${authToken}`);
    // Cancelled order returns 404 (no tracking) or 200 with empty data
    expect([200, 404]).toContain(res.status);
  });
});

// ──────────── Messages API ────────────
describe('Messages API', () => {
  test('GET /api/messages requires auth', async () => {
    const res = await request(app).get('/api/messages');
    expect(res.status).toBe(401);
  });

  test('GET /api/messages returns messages', async () => {
    const res = await request(app)
      .get('/api/messages')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toBeDefined();
  });
});

// ──────────── Browse History API ────────────
describe('Browse History API', () => {
  test('POST /api/browsing-history requires auth', async () => {
    const res = await request(app)
      .post('/api/browsing-history')
      .send({ productId: 1 });
    expect(res.status).toBe(401);
  });

  test('POST /api/browsing-history adds record', async () => {
    const res = await request(app)
      .post('/api/browsing-history')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ productId: testProductId });
    expect(res.status).toBe(200);
  });

  test('GET /api/browsing-history returns records', async () => {
    const res = await request(app)
      .get('/api/browsing-history')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });

  test('DELETE /api/browsing-history clears records', async () => {
    const res = await request(app)
      .delete('/api/browsing-history')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });
});

// ──────────── Search History API ────────────
describe('Search History API', () => {
  test('POST /api/search-history adds keyword', async () => {
    const res = await request(app)
      .post('/api/search-history')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ keyword: '手机' });
    expect(res.status).toBe(200);
  });

  test('GET /api/search-history returns keywords', async () => {
    const res = await request(app)
      .get('/api/search-history')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });

  test('DELETE /api/search-history clears keywords', async () => {
    const res = await request(app)
      .delete('/api/search-history')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(200);
  });
});

// ──────────── Admin API ────────────
describe('Admin API', () => {
  let adminToken = '';

  beforeAll(async () => {
    // Login as admin
    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'admin123' });
    adminToken = res.body.token;
  });

  test('GET /api/admin/dashboard returns stats', async () => {
    const res = await request(app)
      .get('/api/admin/dashboard')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body).toBeDefined();
  });

  test('GET /api/admin/products returns paginated', async () => {
    const res = await request(app)
      .get('/api/admin/products?page=1&pageSize=5')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toBeDefined();
  });

  test('GET /api/admin/orders returns orders', async () => {
    const res = await request(app)
      .get('/api/admin/orders')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toBeDefined();
  });

  test('GET /api/admin/users returns paginated', async () => {
    const res = await request(app)
      .get('/api/admin/users')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toBeDefined();
    expect(res.body.total).toBeGreaterThan(0);
  });

  test('GET /api/admin/users?keyword=admin search', async () => {
    const res = await request(app)
      .get('/api/admin/users?keyword=admin')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items.length).toBeGreaterThan(0);
  });

  test('GET /api/admin/stats returns analytics', async () => {
    const res = await request(app)
      .get('/api/admin/stats')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
  });

  test('GET /api/admin/categories returns tree', async () => {
    const res = await request(app)
      .get('/api/admin/categories')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
  });

  test('GET /api/admin/dashboard with regular user returns 403', async () => {
    const res = await request(app)
      .get('/api/admin/dashboard')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.status).toBe(403);
  });
});

// ──────────── 404 Handling ────────────
describe('404 Handling', () => {
  test('GET /api/nonexistent returns 404', async () => {
    const res = await request(app).get('/api/nonexistent');
    expect(res.status).toBe(404);
    expect(res.body.code).toBe('NOT_FOUND');
  });
});
