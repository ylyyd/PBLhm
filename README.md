# 开心购物（HappyShop）

基于 **HarmonyOS 6.0.2（API 22）** 的全栈电商应用实践：端侧使用 ArkTS / ArkUI 声明式开发，
服务端基于 Node.js + Express + SQLite（sql.js）提供 RESTful 接口与 WebSocket 实时通知。

端侧 25 个页面、19 个可复用组件、14 个数据仓库、4 个全局视图模型；服务端 21 个路由模块、
99 个接口端点、22 张数据表，覆盖从注册登录到下单支付、售后评价、后台管理的完整交易闭环。

## 功能

**用户端**

- 注册 / 登录 / 自动登录（JWT 双 Token：access 24h + refresh 7d，bcrypt 加密存储）
- 首页轮播、分类入口、商品瀑布流；关键字搜索、分类 / 价格 / 评分筛选、销量与价格排序
- 商品详情、多规格 SKU 选择（**无库存组合自动禁灰**）、商品评价与问答
- 购物车（按 SKU 分行、单选 / 全选 / 批量删除、金额实时汇总）
- 下单与支付（支付宝沙箱 / Mock 降级）、30 分钟支付倒计时、订单状态流转
- 确认收货、申请售后（退款 / 退货退款 / 换货）、发表评价
- 地址管理、收藏、浏览记录、搜索历史、消息中心（WebSocket 实时推送）
- 深色 / 浅色 / 跟随系统三态主题

**管理端**

- 运营仪表盘（商品数、订单数、用户数、总收入）
- 商品管理（增删改查、上下架）、订单管理与发货、分类树维护
- 管理员操作审计日志

## 技术栈

| 层次 | 技术 |
| --- | --- |
| 端侧 | HarmonyOS 6.0.2 (API 22)、ArkTS、ArkUI、@ohos.data.preferences、LazyForEach |
| 服务端 | Node.js ≥ 18、Express 4、ws（WebSocket） |
| 数据 | SQLite（sql.js WebAssembly 引擎，写后 200 ms 防抖落盘）、版本化迁移脚本 |
| 安全 | JWT、bcryptjs、helmet、express-rate-limit、参数化查询、sanitize-html |
| 其他 | 支付宝沙箱 SDK、winston 日志、Jest + supertest 测试 |

## 目录结构

```
PBLhm/
├── AppScope/                    # 应用级配置、图标与启动图
├── entry/                       # 端侧主模块
│   └── src/main/
│       ├── ets/
│       │   ├── pages/           # 页面（首页、详情、购物车、订单、后台等）
│       │   ├── components/      # 可复用组件（商品卡片、SKU 选择器、骨架屏等）
│       │   ├── viewmodel/       # 全局视图模型（会话、购物车、订单、消息）
│       │   ├── repository/      # 数据仓库，统一封装接口调用与缓存
│       │   ├── data/            # HttpClient、DatabaseHelper 与数据模型
│       │   ├── common/          # 路由、常量、日志、样式
│       │   └── entryability/    # 应用入口 Ability
│       └── resources/           # 图片、字符串、颜色等资源
├── server/                      # 服务端
│   ├── src/
│   │   ├── routes/              # 21 个路由模块，99 个端点
│   │   ├── middleware/          # 认证、鉴权、参数校验、限流
│   │   ├── services/            # 通知服务、统计服务
│   │   ├── db.js                # 数据库初始化、迁移与持久化
│   │   ├── logger.js            # 日志
│   │   └── index.js             # 服务入口（REST + WebSocket）
│   ├── public/                  # 管理后台与支付沙箱页面
│   ├── __tests__/               # 接口测试
│   └── data.db                  # SQLite 数据文件（运行时生成 / 可备份）
├── scripts/                     # 辅助脚本
└── hvigor/                      # 构建配置
```

## 快速开始

### 1. 启动服务端

```bash
cd server
npm install
npm start          # 等同于 node src/index.js
# 开发调试可用：npm run dev（--watch 自动重启）
```

启动后：

| 地址 | 用途 |
| --- | --- |
| `http://localhost:3000/health` | 健康检查（返回数据库状态、表数量、运行时长） |
| `http://localhost:3000/admin` | 管理后台 |
| `http://localhost:3000/payment/sandbox.html?amount=199&orderNumber=xxx` | 支付沙箱页 |
| `ws://localhost:3000/ws` | WebSocket 通知通道 |

端口由 `.env` 中的 `PORT` 指定，默认 3000；若被占用会依次尝试 3001–3009。

`.env` 主要配置项：

```ini
PORT=3000
NODE_ENV=development
JWT_SECRET=请替换为你自己的密钥
# 支付宝沙箱（可选，缺失时自动降级为 Mock 支付）
ALIPAY_APP_ID=
ALIPAY_PRIVATE_KEY=
ALIPAY_PUBLIC_KEY=
```

### 2. 运行端侧

1. 用 DevEco Studio 打开项目根目录，SDK 选择 **HarmonyOS 6.0.2 (API 22)**；
2. 创建或启动模拟器（也可连接真机并开启开发者模式）；
3. 直接点击 Run，IDE 会完成编译、打包与安装。

端侧启动时会向候选地址依次发起健康检查，自动选中可用的后端地址（模拟器为 `10.0.2.2`，
真机为局域网 IP），无需手动改配置。

### 3. 运行测试

```bash
cd server
npm test
```

## 接口概览

服务端按资源划分为 21 个路由模块，共 99 个端点，统一以 `/api` 为前缀：

| 模块 | 端点数 | 代表性接口 |
| --- | --- | --- |
| auth | 8 | `POST /register`、`POST /login`、`GET /profile` |
| products | 5 | `GET /`、`GET /categories`、`GET /hot-keywords` |
| cart | 8 | `GET /`、`POST /`、`PUT /:productId` |
| orders | 7 | `POST /`、`GET /`、`GET /:orderNumber` |
| payment | 4 | `POST /page/:orderNumber`、`POST /callback/:orderNumber` |
| reviews / favorites / messages / aftersales | 各 5–6 | 商品评价、收藏、消息、售后申请 |
| admin | 16 | `GET /dashboard`、`GET /products`、`POST /products` |
| 其余 | — | 地址、店铺、优惠券、发票、分类、上传等 |

完整定义见 `server/src/routes/`。

## 数据库

- 共 22 张表，覆盖用户与权限、商品与 SKU、购物车、订单与明细、评价、收藏、地址、售后、
  消息、优惠券、分类树、审计日志与迁移记录；
- 服务启动时自动建表并导入种子数据，表结构变更通过版本化迁移脚本执行；
- 运行期写操作在 200 ms 防抖窗口结束后整体导出写入 `data.db`，该文件可直接拷贝备份或迁移。

## 说明

- 本项目为课程实践与学习用途，仓库中的示例账号、商品与订单数据均为演示数据；
- `.env` 含密钥，请勿提交到版本库；
- `data.db`、`server/logs/`、`server/uploads/` 建议加入 `.gitignore`，避免把运行时数据带进仓库。
