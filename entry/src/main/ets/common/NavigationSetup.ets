// ╔══════════════════════════════════════════════════════════════╗
// ║  NavigationSetup — 导航参数工具 (基于 router API)           ║
// ║  HarmonyOS 6.0.2 (API 22) 不支持 NavPathStack 导入          ║
// ║  故降级使用 router.pushUrl/replaceUrl/back                  ║
// ╚══════════════════════════════════════════════════════════════╝

import router from '@ohos.router'

/**
 * 获取当前页面的导航参数 (封装 router.getParams)
 */
export function getPageParams<T>(): T | null {
  try {
    return router.getParams() as T
  } catch {
    return null
  }
}
