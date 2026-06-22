export class RoutePath {
  static readonly INDEX: string = 'pages/Index'
  static readonly REGISTER: string = 'pages/Register'
  static readonly MAIN_TAB: string = 'pages/MainTab'
  static readonly CHECKOUT: string = 'pages/Checkout'
  static readonly ORDER_SUCCESS: string = 'pages/OrderSuccess'
  static readonly ORDER_HISTORY: string = 'pages/OrderHistory'
  static readonly EDIT_PROFILE: string = 'pages/EditProfile'
  static readonly PRODUCT_DETAIL: string = 'pages/ProductDetail'
  static readonly ADDRESS_MANAGEMENT: string = 'pages/AddressManagement'
  static readonly ORDER_DETAIL: string = 'pages/OrderDetail'
  static readonly FAVORITES: string = 'pages/Favorites'
  static readonly MY_REVIEWS: string = 'pages/MyReviews'
  static readonly SETTINGS: string = 'pages/Settings'
  static readonly PERSONAL_INFO: string = 'pages/PersonalInfo'
  static readonly SEARCH_PAGE: string = 'pages/SearchPage'
  static readonly WEBVIEW_PAGE: string = 'pages/WebViewPage'
  static readonly MESSAGE_CENTER: string = 'pages/MessageCenter'
  static readonly ADMIN_DASHBOARD: string = 'pages/AdminDashboard'
  static readonly ADMIN_PRODUCTS: string = 'pages/AdminProducts'
  static readonly ADMIN_ORDERS: string = 'pages/AdminOrders'
  static readonly ADMIN_CATEGORIES: string = 'pages/AdminCategories'
  static readonly BROWSE_HISTORY: string = 'pages/BrowseHistory'
  static readonly AFTER_SALES: string = 'pages/AfterSales'
  static readonly AFTER_SALES_LIST: string = 'pages/AfterSalesList'
}

export class DbConstants {
  static readonly DB_NAME: string = 'shop_app_db'
  static readonly KEY_USERS: string = 'users'
  static readonly KEY_CART: string = 'cart'
  static readonly KEY_ORDERS: string = 'orders'
  static readonly KEY_SESSION: string = 'logged_in_username'
}

export class AppConstants {
  static readonly APP_NAME: string = '开心购物'
  static readonly PASSWORD_MIN_LENGTH: number = 6
  static readonly ORDER_PREFIX: string = 'DD'
}

export class OrderStatusValue {
  static readonly PENDING_PAYMENT: string = '待付款'
  static readonly PENDING_SHIP: string = '待发货'
  static readonly PAID: string = '已付款'
  static readonly SHIPPING: string = '配送中'
  static readonly PENDING_RECEIVE: string = '待收货'
  static readonly COMPLETED: string = '已完成'
  static readonly CANCELLED: string = '已取消'
  static readonly REFUNDING: string = '退款中'
  static readonly REFUNDED: string = '已退款'
}
