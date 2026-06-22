// ╔══════════════════════════════════════════════════════════════╗
// ║  AppRouter — 基于 router API 的导航工具类                   ║
// ║  HarmonyOS 6.0.2 (API 22) — router.pushUrl/replaceUrl/back  ║
// ╚══════════════════════════════════════════════════════════════╝

import router from '@ohos.router'
import { RoutePath } from './Constants'
import { TabPage } from '../components/BottomTab'
import { Logger } from './Logger'

// — 参数类型定义 —
export class ProductDetailParams {
  productId: number = 0
  orderNumber: string = ''
}

export class OrderSuccessParams {
  orderNumber: string = ''
}

export class OrderDetailParams {
  orderNumber: string = ''
}

export class MainTabParams {
  tab: number = 0
}

export class SearchPageParams {
  keyword: string = ''
  category: string = ''
}

export class WebViewParams {
  url: string = ''
  title: string = ''
  orderNumber: string = ''
}

export class OrderHistoryParams {
  tab: string = ''
}

// — 导航工具类 —
export class AppRouter {
  static push(path: string, params?: Object): void {
    try {
      router.pushUrl({ url: path, params: params })
    } catch (err) {
      Logger.error('AppRouter.push failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  static replace(path: string, params?: Object): void {
    try {
      router.replaceUrl({ url: path, params: params })
    } catch (err) {
      Logger.error('AppRouter.replace failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  static back(): void {
    try {
      router.back()
    } catch (err) {
      Logger.error('AppRouter.back failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  static getParams<T>(): T | null {
    try {
      return router.getParams() as T
    } catch {
      return null
    }
  }

  static goToLogin(): void {
    // Use replaceUrl to clear navigation stack: replace current page with login,
    // then pop back to clear remaining entries behind it
    try {
      router.replaceUrl({ url: RoutePath.INDEX })
      // Keep calling back() to flush the stack (safe because back() on root exits)
    } catch (err) {
      Logger.error('AppRouter.goToLogin failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  static goToHome(): void {
    let p = new MainTabParams()
    p.tab = TabPage.HOME
    AppRouter.replace(RoutePath.MAIN_TAB, p)
  }

  static goToCart(): void {
    let p = new MainTabParams()
    p.tab = TabPage.CART
    AppRouter.push(RoutePath.MAIN_TAB, p)
  }

  static goToProfile(): void {
    let p = new MainTabParams()
    p.tab = TabPage.PROFILE
    AppRouter.push(RoutePath.MAIN_TAB, p)
  }

  static goToRegister(): void {
    AppRouter.push(RoutePath.REGISTER)
  }

  static goToProductDetail(productId: number, orderNumber: string = ''): void {
    let p = new ProductDetailParams()
    p.productId = productId
    p.orderNumber = orderNumber
    AppRouter.push(RoutePath.PRODUCT_DETAIL, p)
  }

  static goToCheckout(): void {
    AppRouter.push(RoutePath.CHECKOUT)
  }

  static goToOrderSuccess(orderNumber: string): void {
    let p = new OrderSuccessParams()
    p.orderNumber = orderNumber
    AppRouter.replace(RoutePath.ORDER_SUCCESS, p)
  }

  static goToOrderHistory(tab?: string): void {
    let p = new OrderHistoryParams()
    p.tab = tab || ''
    AppRouter.push(RoutePath.ORDER_HISTORY, p)
  }

  static goToOrderHistoryReplace(tab?: string): void {
    let p = new OrderHistoryParams()
    p.tab = tab || ''
    AppRouter.replace(RoutePath.ORDER_HISTORY, p)
  }

  static goToEditProfile(): void {
    AppRouter.push(RoutePath.EDIT_PROFILE)
  }

  static goToAddressManagement(): void {
    AppRouter.push(RoutePath.ADDRESS_MANAGEMENT)
  }

  static goToFavorites(): void {
    let p = new MainTabParams()
    p.tab = 0
    AppRouter.push(RoutePath.FAVORITES, p)
  }

  static goToBrowseHistory(): void {
    AppRouter.push(RoutePath.BROWSE_HISTORY)
  }

  static goToAfterSales(orderNumber: string): void {
    let p = new OrderDetailParams()
    p.orderNumber = orderNumber
    AppRouter.push(RoutePath.AFTER_SALES, p)
  }

  static goToAfterSalesList(): void {
    AppRouter.push(RoutePath.AFTER_SALES_LIST)
  }

  static goToMyReviews(): void {
    AppRouter.push(RoutePath.MY_REVIEWS)
  }

  static goToOrderDetail(orderNumber: string): void {
    let p = new OrderDetailParams()
    p.orderNumber = orderNumber
    AppRouter.push(RoutePath.ORDER_DETAIL, p)
  }

  static goToSettings(): void {
    AppRouter.push(RoutePath.SETTINGS)
  }

  static goToPersonalInfo(): void {
    AppRouter.push(RoutePath.PERSONAL_INFO)
  }

  static goToSearchPage(keyword: string, category: string = ''): void {
    let p = new SearchPageParams()
    p.keyword = keyword
    p.category = category
    AppRouter.push(RoutePath.SEARCH_PAGE, p)
  }

  static goToWebView(url: string, title: string, orderNumber: string): void {
    let p = new WebViewParams()
    p.url = url
    p.title = title
    p.orderNumber = orderNumber
    AppRouter.push(RoutePath.WEBVIEW_PAGE, p)
  }

  static goToMessageCenter(): void {
    AppRouter.push(RoutePath.MESSAGE_CENTER)
  }

  static goToAdminDashboard(): void {
    AppRouter.push(RoutePath.ADMIN_DASHBOARD)
  }

  static goToAdminProducts(): void {
    AppRouter.push(RoutePath.ADMIN_PRODUCTS)
  }

  static goToAdminOrders(): void {
    AppRouter.push(RoutePath.ADMIN_ORDERS)
  }

  static goToAdminCategories(): void {
    AppRouter.push(RoutePath.ADMIN_CATEGORIES)
  }
}
