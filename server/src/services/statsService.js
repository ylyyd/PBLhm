const { getDb } = require('../db');
const logger = require('../logger');

/**
 * Get dashboard statistics
 * @returns {Promise<object>} stats object
 */
async function getDashboardStats() {
  try {
    const { get, all } = await getDb();

    // Total users
    const { total_users } = get('SELECT COUNT(*) as total_users FROM users') || { total_users: 0 };

    // Total products (active)
    const { total_products } = get("SELECT COUNT(*) as total_products FROM products WHERE status = 'active' OR status IS NULL OR status = ''") || { total_products: 0 };

    // Today's new users
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    const { today_users } = get('SELECT COUNT(*) as today_users FROM users WHERE created_at >= ?', [todayStr]) || { today_users: 0 };

    // Total orders
    const { total_orders } = get('SELECT COUNT(*) as total_orders FROM orders') || { total_orders: 0 };

    // Total revenue (completed orders)
    const { total_revenue } = get("SELECT COALESCE(SUM(total_price), 0) as total_revenue FROM orders WHERE status = '已完成'") || { total_revenue: 0 };

    // Today's orders
    const { today_orders } = get('SELECT COUNT(*) as today_orders FROM orders WHERE create_time >= ?', [todayStr]) || { today_orders: 0 };

    // Today's revenue
    const { today_revenue } = get("SELECT COALESCE(SUM(total_price), 0) as today_revenue FROM orders WHERE status = '已完成' AND create_time >= ?", [todayStr]) || { today_revenue: 0 };

    // Total order count (all statuses)
    const { total_orders_all } = get('SELECT COUNT(*) as total_orders_all FROM orders') || { total_orders_all: 0 };

    // Today's sales for completed orders
    const { today_sales } = get("SELECT COALESCE(SUM(total_price), 0) as today_sales FROM orders WHERE status = '已完成' AND create_time >= ?", [todayStr]) || { today_sales: 0 };

    // Recent 5 orders
    const recentOrders = all("SELECT order_number, username, total_price, status, create_time FROM orders ORDER BY create_time DESC LIMIT 5");

    // Order status breakdown
    const statusBreakdown = all('SELECT status, COUNT(*) as count FROM orders GROUP BY status');

    // Order trend — last 7 days
    const orderTrend = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(today);
      d.setDate(d.getDate() - i);
      const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      const { count } = get("SELECT COUNT(*) as count FROM orders WHERE create_time LIKE ?", [`${dateStr}%`]) || { count: 0 };
      const { revenue } = get("SELECT COALESCE(SUM(total_price), 0) as revenue FROM orders WHERE status = '已完成' AND create_time LIKE ?", [`${dateStr}%`]) || { revenue: 0 };
      orderTrend.push({
        date: dateStr,
        orders: count,
        revenue,
      });
    }

    // DAU (daily active users — users with orders on that day)
    const dau = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(today);
      d.setDate(d.getDate() - i);
      const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      const { active_users } = get("SELECT COUNT(DISTINCT username) as active_users FROM orders WHERE create_time LIKE ?", [`${dateStr}%`]) || { active_users: 0 };
      dau.push({
        date: dateStr,
        activeUsers: active_users,
      });
    }

    return {
      totalUsers: total_users,
      totalProducts: total_products,
      todayNewUsers: today_users,
      totalOrders: total_orders,
      totalRevenue: total_revenue,
      todayOrders: today_orders,
      todayRevenue: today_revenue,
      orderCount: total_orders_all,
      todaySales: today_sales,
      recentOrders,
      orderStatusBreakdown: statusBreakdown,
      orderTrend,
      dailyActiveUsers: dau,
    };
  } catch (err) {
    logger.error('getDashboardStats error: ' + err.message);
    throw err;
  }
}

module.exports = { getDashboardStats };
