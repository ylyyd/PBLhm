import { BusinessError } from '@kit.BasicServicesKit';
import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { webSocket } from '@kit.NetworkKit';
import router from '@ohos.router';
import { DatabaseHelper } from '../data/DatabaseHelper';
import { HttpClient, setRedirectToLoginHandler } from '../data/HttpClient';
import { AppConfig } from '../common/Config';
import { sessionViewModel } from '../viewmodel/SessionViewModel';
import { productRepository } from '../data/repository/ProductRepository';
import { cartRepository } from '../data/repository/CartRepository';
import { orderRepository } from '../data/repository/OrderRepository';
import { favoriteRepository } from '../data/repository/FavoriteRepository';
import { messageRepository } from '../data/repository/MessageRepository';
import { browseHistoryRepository } from '../data/repository/BrowseHistoryRepository';
import { setSystemIsDark } from '../common/StyleConstants';
import { Logger } from '../common/Logger';

interface WebSocketCloseResult {
  code: number
  reason: string
}

export default class EntryAbility extends UIAbility {
  private ws: webSocket.WebSocket | null = null
  private wsReconnectTimer: number = -1
  private wsReconnectAttempts: number = 0
  private readonly WS_URL: string = 'ws://10.0.2.2:3000/ws'
  private readonly WS_MAX_RECONNECT_DELAY: number = 60000
  private readonly WS_MAX_RECONNECT_ATTEMPTS: number = 10

  private getWsUrl(): string {
    return `ws://${AppConfig.HOST_IP}:3000/ws`
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      Logger.error('Failed to set colorMode: {0}', err instanceof Error ? err.message : '')
    }
    Logger.info('Ability onCreate');
  }

  onDestroy(): void {
    this.disconnectWebSocket()
    Logger.info('Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    // 必须在任何可能触发 API 请求的代码之前设置 401 handler
    // 这样 restoreSession / onForeground 中的 silent 401 不会触发弹窗，
    // 但页面级别的非 silent 请求可以正常触发
    setRedirectToLoginHandler(() => {
      try {
        // 先清除会话数据，这样即便用户暂时未点确认，后续操作也不会误用旧数据
        sessionViewModel.logout()
        AlertDialog.show({
          title: '登录已失效',
          message: '您的登录已过期，请重新登录',
          autoCancel: false,
          confirm: {
            value: '确定',
            action: () => {
              router.replaceUrl({ url: 'pages/Index' })
            }
          }
        })
        Logger.info('Session expired, session cleared, AlertDialog shown')
      } catch (e) {
        Logger.error('Session expired handler failed: {0}', e instanceof Error ? e.message : '')
      }
    })

    await DatabaseHelper.init(this.context)

    // Detect the host machine IP for API and WebSocket connections
    await AppConfig.init()
    HttpClient.BASE_URL = AppConfig.API_BASE_URL
    Logger.info('EntryAbility: API base URL = {0}', HttpClient.BASE_URL)

    // Initialize WebSocket connection after session restored
    this.connectWebSocket()

    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        Logger.error('Failed to load content: {0}', err.code ? err.code.toString() : '')
        return;
      }
      Logger.info('Succeeded in loading content');
    });
  }

  private connectWebSocket(): void {
    const token: string = HttpClient.getToken()
    if (!token) {
      Logger.info('WebSocket: no token, connection deferred until login')
      return
    }

    // Reset reconnect counter on manual connection attempt
    this.wsReconnectAttempts = 0

    // Clean up existing connection if any
    this.disconnectWebSocket()

    this.ws = webSocket.createWebSocket()

    this.ws.on('open', () => {
      Logger.info('WebSocket connected')
      this.wsReconnectAttempts = 0
    })

    this.ws.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
      if (err) {
        Logger.error('WebSocket message error: {0}', JSON.stringify(err))
        return
      }
      try {
        const msg = typeof data === 'string' ? JSON.parse(data) as Record<string, Object> : data
        Logger.info('WebSocket message received: {0}', JSON.stringify(msg))
      } catch (e) {
        Logger.info('WebSocket message received (raw)')
      }
    })

    this.ws.on('close', (err: BusinessError, result: WebSocketCloseResult) => {
      Logger.info('WebSocket closed: ' + JSON.stringify({ code: result.code, reason: result.reason }))
      this.ws = null
      // Exponential backoff reconnect: 5s → 15s → 30s → 60s (max)
      this.wsReconnectAttempts++
      if (this.wsReconnectAttempts > this.WS_MAX_RECONNECT_ATTEMPTS) {
        Logger.info('WebSocket: max reconnect attempts reached, stopping')
        return
      }
      let delay = Math.min(5000 * Math.pow(2, this.wsReconnectAttempts - 1), this.WS_MAX_RECONNECT_DELAY)
      this.wsReconnectTimer = setTimeout(() => {
        this.connectWebSocket()
      }, delay)
    })

    this.ws.on('error', (err: BusinessError) => {
      Logger.error('WebSocket error: {0}', JSON.stringify(err))
    })

    this.ws.connect(this.getWsUrl() + '?token=' + token)
    Logger.info('WebSocket connecting to: {0}', this.getWsUrl())
  }

  private disconnectWebSocket(): void {
    if (this.wsReconnectTimer !== -1) {
      clearTimeout(this.wsReconnectTimer)
      this.wsReconnectTimer = -1
    }
    if (this.ws) {
      this.ws.close()
      this.ws = null
      Logger.info('WebSocket disconnected')
    }
  }

  onWindowStageDestroy(): void {
    Logger.info('Ability onWindowStageDestroy');
  }

  onForeground(): void {
    Logger.info('Ability onForeground');
    // Background refresh all repositories (TTL-protected, silent on 401)
    productRepository.load().catch(() => {})
    cartRepository.load().catch(() => {})
    orderRepository.load().catch(() => {})
    favoriteRepository.load().catch(() => {})
    messageRepository.load().catch(() => {})
    browseHistoryRepository.load().catch(() => {})
  }

  onBackground(): void {
    Logger.info('Ability onBackground');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    try {
      let isDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      setSystemIsDark(isDark)
    } catch (err) {
      Logger.error('onConfigurationUpdate failed: {0}', err instanceof Error ? err.message : '')
    }
  }
}
