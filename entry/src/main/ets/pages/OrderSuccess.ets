import { AppRouter, OrderSuccessParams, OrderDetailParams } from '../common/AppRouter'
import { RoutePath } from '../common/Constants'
import { AppColor, AppRadius } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'

@Entry
@Component
struct OrderSuccess {
  params: OrderSuccessParams = new OrderSuccessParams()
  @State orderNumber: string = ''

  aboutToAppear(): void {
    let routerP = AppRouter.getParams<OrderSuccessParams>()
    if (routerP) this.params = routerP
    let p = this.params
    if (p) {
      this.orderNumber = p.orderNumber
    }
  }

  build() {
    Column() {
      Blank().layoutWeight(1)

      Column({ space: 12 }) {
        Stack() {
          Circle().width(88).height(88).fill(AppColor.SUCCESS)
          Path()
            .commands('M28,46 L40,58 L62,32')
            .stroke(AppColor.cardBg()).strokeWidth(7)
            .strokeLineCap(LineCapStyle.Round).strokeLineJoin(LineJoinStyle.Round)
        }

        Text($r('app.string.order_success_title'))
          .fontSize(26).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary()).margin({ top: 8 })
        Text($r('app.string.order_success_desc'))
          .fontSize(15).fontColor(AppColor.textTertiary())

        Column({ space: 8 }) {
          Row() {
            Text($r('app.string.order_success_no')).fontSize(13).fontColor(AppColor.textTertiary())
            Text(this.orderNumber).fontSize(13).fontColor(AppColor.textPrimary()).fontWeight(FontWeight.Medium)
          }
          Row({ space: 6 }) {
            Circle().width(6).height(6).fill(AppColor.SUCCESS)
            Text($r('app.string.order_success_delivery_hint')).fontSize(13).fontColor(AppColor.textSecondary())
          }
        }
        .padding(16).backgroundColor(AppColor.bg()).borderRadius(AppRadius.MD).margin({ top: 8 })
      }
      .width('100%').alignItems(HorizontalAlign.Center)

      Blank().layoutWeight(1)

      Column({ space: 12 }) {
        AppButton({ text: '返回首页', type: AppButtonType.OUTLINE,
          buttonWidth: '85%', buttonHeight: 48, fontSize: 16,
          buttonOnClick: () => { AppRouter.goToHome() } })

        AppButton({ text: '查看订单', type: AppButtonType.PRIMARY,
          buttonWidth: '85%', buttonHeight: 48, fontSize: 16,
          buttonOnClick: () => {
            let p = new OrderDetailParams()
            p.orderNumber = this.orderNumber
            AppRouter.replace(RoutePath.ORDER_DETAIL, p)
          } })
      }
      .margin({ bottom: 48 })
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
    PageTransitionExit({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
  }
}
