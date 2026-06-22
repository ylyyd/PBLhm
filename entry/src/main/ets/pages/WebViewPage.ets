import { AppRouter, WebViewParams } from '../common/AppRouter'
import { AppColor } from '../common/StyleConstants'
import webview from '@ohos.web.webview'
import { HttpClient } from '../data/HttpClient'
import { OrderStatusValue } from '../common/Constants'
import { HeaderComponent } from '../components/HeaderComponent'
import { Logger } from '../common/Logger'

@Entry
@Component
struct WebViewPage {
  params: WebViewParams = new WebViewParams()
  @State url: string = ''
  @State title: string = ''
  @State orderNumber: string = ''
  @State isLoading: boolean = true
  @State paymentDone: boolean = false
  @State pollCount: number = 0
  @State timedOut: boolean = false
  private pollingTimer: number = 0
  private controller: webview.WebviewController = new webview.WebviewController()

  aboutToAppear(): void {
    let routerP = AppRouter.getParams<WebViewParams>()
    if (routerP) this.params = routerP
    let p = this.params
    if (p) {
      this.url = p.url
      this.title = p.title || '支付'
      this.orderNumber = p.orderNumber
    }
    this.startPolling()
  }

  aboutToDisappear(): void {
    clearInterval(this.pollingTimer)
  }

  onPaymentSuccess(): void {
    if (this.paymentDone) return
    this.paymentDone = true
    clearInterval(this.pollingTimer)
    setTimeout(() => {
      AppRouter.goToOrderSuccess(this.orderNumber)
    }, 500)
  }

  startPolling(): void {
    this.pollingTimer = setInterval(async () => {
      if (this.paymentDone) {
        clearInterval(this.pollingTimer)
        return
      }
      if (this.timedOut) return
      this.pollCount++
      try {
        let res: Object = await HttpClient.get('/payment/status/' + this.orderNumber)
        let data = res as Record<string, Object>
        if (data.status === OrderStatusValue.PENDING_SHIP) {
          this.onPaymentSuccess()
        }
      } catch (err) { Logger.error('支付轮询失败: {0}', (err as Error).message) }
      if (this.pollCount >= 60) {
        clearInterval(this.pollingTimer)
        this.timedOut = true
      }
    }, 2000)
  }

  build() {
    Column() {
      HeaderComponent({
        title: this.title,
        onBack: () => {
          clearInterval(this.pollingTimer)
          AppRouter.back()
        }
      })

      if (this.isLoading) {
        LoadingProgress().width(40).height(40).color(AppColor.PRIMARY).layoutWeight(1)
      }

      Web({ src: this.url, controller: this.controller })
        .width('100%').layoutWeight(1)
        .onPageBegin(() => {
          this.isLoading = false
        })
        .onErrorReceive(() => { this.isLoading = false })
        .onLoadIntercept((event): boolean => {
          if (event) {
            let url: string = event.data.getRequestUrl()
            if (url.startsWith('happybuy://payment/success')) {
              this.onPaymentSuccess()
              return true
            }
          }
          return false
        })

      if (this.timedOut) {
        Row() {
          Text('支付超时，请返回重试').fontSize(14).fontColor(AppColor.PRIMARY)
          Blank()
          Text('重试 >').fontSize(14).fontColor(AppColor.PRIMARY)
            .onClick(() => {
              clearInterval(this.pollingTimer)
              AppRouter.back()
            })
        }
        .width('92%').padding({ top: 8, bottom: 16 })
      } else if (!this.paymentDone) {
        Row() {
          Text('支付处理中...').fontSize(13).fontColor(AppColor.textTertiary())
          Blank()
          LoadingProgress().width(16).height(16).color(AppColor.PRIMARY)
        }
        .width('92%').padding({ top: 8, bottom: 16 })
      }
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn }).opacity(0)
    PageTransitionExit({ duration: 350, curve: Curve.FastOutSlowIn }).opacity(0)
  }
}
