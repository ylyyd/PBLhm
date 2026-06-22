const express = require('express');
const { getDb } = require('../db');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();
router.use(authMiddleware);

// Deterministic logistics tracking based on order status
function buildTracking(order) {
  const status = order.status;
  const expressCompany = order.express_company || '顺丰速运';
  const trackingNumber = order.tracking_number || '';
  const shipTime = order.ship_time || '';
  const now = new Date();

  const pad = (n) => String(n).padStart(2, '0');
  const fmtDateTime = (date) =>
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:00`;

  // No logistics info for unpaid/cancelled orders
  if (status === '待付款' || status === '已取消') {
    return { tracking: [], estimatdDelivery: '' };
  }

  const tracking = [];
  const shipDate = shipTime ? new Date(shipTime) : new Date(now.getTime() - 86400000); // default 1 day ago

  if (status === '待发货') {
    tracking.push({
      time: fmtDateTime(shipDate),
      desc: `您的包裹正在打包中，即将由${expressCompany}揽收`,
      location: '商家仓库',
    });
    return { tracking, estimatedDelivery: '' };
  }

  // For shipped / in-transit / delivered / refunded
  const isDelivered = (status === '已完成' || status === '已退款');
  const daysSinceShip = Math.floor((now.getTime() - shipDate.getTime()) / 3600000);

  // Step 1: Package picked up
  const t1 = new Date(shipDate.getTime() + 1 * 3600000);
  tracking.push({
    time: fmtDateTime(t1),
    desc: `您的包裹已出库，${expressCompany}已揽收`,
    location: '发货仓库',
  });

  // Step 2: Arrived at sorting center
  const t2 = new Date(t1.getTime() + (isDelivered ? 4 : Math.min(daysSinceShip, 4)) * 3600000);
  const code = trackingNumber ? trackingNumber.slice(-4) : '0000';
  tracking.push({
    time: fmtDateTime(t2),
    desc: `快件已到达【${expressCompany} ${code}号分拣中心】`,
    location: '分拣中心',
  });

  // Step 3: In transit — only if enough time has passed or delivered
  if (isDelivered || daysSinceShip >= 8) {
    const t3 = new Date(t2.getTime() + (isDelivered ? 8 : Math.min(daysSinceShip - 4, 8)) * 3600000);
    tracking.push({
      time: fmtDateTime(t3),
      desc: `快件已从【${expressCompany} 华东分拨中心】发出，运输途中`,
      location: '运输途中',
    });

    // Step 4: Arrived at destination — only if enough time has passed
    if (isDelivered || daysSinceShip >= 16) {
      const t4 = new Date(t3.getTime() + (isDelivered ? 8 : 8) * 3600000);
      tracking.push({
        time: fmtDateTime(t4),
        desc: `快件已到达【${expressCompany} ${code}号分拣中心】`,
        location: '分拣中心',
      });

      // Step 5: Out for delivery
      if (isDelivered || daysSinceShip >= 24) {
        const t5 = new Date(t4.getTime() + (isDelivered ? 4 : 4) * 3600000);
        tracking.push({
          time: fmtDateTime(t5),
          desc: `快件已分配至快递员，正在派送中`,
          location: '派送中',
        });

        if (isDelivered) {
          const t6 = new Date(t5.getTime() + 2 * 3600000);
          tracking.push({
            time: fmtDateTime(t6),
            desc: `快件已签收，感谢使用${expressCompany}，期待再次光临`,
            location: '已签收',
          });
        }
      }
    }
  }

  // Estimate delivery: +3 days from ship for in-transit, use order's estimated_delivery for delivered
  let estimatedDelivery = '';
  if (order.estimated_delivery) {
    estimatedDelivery = order.estimated_delivery;
  } else if (isDelivered) {
    estimatedDelivery = '';
  } else {
    const est = new Date(shipDate.getTime() + 3 * 86400000);
    estimatedDelivery = `${est.getFullYear()}-${pad(est.getMonth() + 1)}-${pad(est.getDate())}`;
  }

  return { tracking, estimatedDelivery };
}

router.get('/:orderNumber', async (req, res) => {
  try {
    const { get } = await getDb();
    const o = get('SELECT * FROM orders WHERE order_number = ? AND username = ?',
      [req.params.orderNumber, req.username]);
    if (!o) return fail(res, '订单不存在', 'NOT_FOUND', 404);

    const { tracking, estimatedDelivery } = buildTracking(o);

    success(res, {
      orderNumber: o.order_number,
      expressCompany: o.express_company || '',
      trackingNumber: o.tracking_number || '',
      estimatedDelivery: estimatedDelivery || o.estimated_delivery || '',
      shipTime: o.ship_time || '',
      status: o.status,
      tracking,
    });
  } catch (err) {
    logger.error('get tracking error: ' + err.message);
    fail(res, '获取物流信息失败');
  }
});

module.exports = router;
