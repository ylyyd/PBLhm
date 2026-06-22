import { Order, CartItem } from '../data/model/ProductModel'
import { orderViewModel } from '../viewmodel/OrderViewModel'
import { trackingRepository, TrackingInfo, TrackingPoint } from '../data/repository/TrackingRepository'
import { AppRouter, OrderDetailParams } from '../common/AppRouter'
import router from '@ohos.router'

import { OrderStatusValue } from '../common/Constants'
import { AppColor, AppRadius, AppCard, AppContainer, AppShadow, isDarkMode } from '../common/StyleConstants'
import { ProductImage } from '../components/ProductImage'
import { LoadingView, EmptyView } from '../components/StatusViews'
import { HeaderComponent } from '../components/HeaderComponent'
import { ConfirmDialog } from '../components/DialogComponent'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppInput } from '../components/AppInput'

function isWithinDays(dateStr: string, days: number): boolean {
  if (!dateStr) return true
  const date = new Date(dateStr)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  return diffMs < days * 24 * 60 * 60 * 1000
}

@Entry
@Component
struct OrderDetail {
  params: OrderDetailParams = new OrderDetailParams()
  @State order: Order | null = null
  @State trackingInfo: TrackingInfo | null = null
  @State isLoading: boolean = true

  async aboutToAppear(): Promise<void> {
    this.isLoading = true
    let routerP = AppRouter.getParams<OrderDetailParams>()
    if (routerP) this.params = routerP
    await this.loadOrder()
    await this.loadTracking()
    this.isLoading = false
  }

  async onPageShow(): Promise<void> {
    this.isLoading = true
    await this.loadOrder()
    await this.loadTracking()
    this.isLoading = false
  }

  async loadOrder(): Promise<void> {
    let p = this.params
    if (p) {
      // Always fetch from server first for latest status (e.g., after WebView payment)
      let serverOrder = await orderViewModel.fetchOrder(p.orderNumber)
      if (serverOrder) {
        this.order = serverOrder
      } else {
        // Fallback to cached order if server unreachable
        this.order = orderViewModel.getByNumber(p.orderNumber) || null
      }
    }
  }

  async loadTracking(): Promise<void> {
    let p = this.params
    if (p) {
      this.trackingInfo = await trackingRepository.getTracking(p.orderNumber)
    }
  }

  get canAfterSales(): boolean {
    if (!this.order) return false
    let s = this.order.status
    return s === OrderStatusValue.REFUNDING || s === OrderStatusValue.REFUNDED ||
      s === OrderStatusValue.SHIPPING || s === OrderStatusValue.PENDING_RECEIVE ||
      s === OrderStatusValue.COMPLETED
  }

  onBackPress(): boolean {
    router.back()
    return true
  }

  async cancelWithReason(reason: string): Promise<void> {
    if (!this.order) return
    await orderViewModel.cancelOrder(this.order.orderNumber, reason)
    let updated = orderViewModel.getByNumber(this.order.orderNumber)
    this.order = updated ? updated : null
    this.getUIContext().getPromptAction().showToast({ message: '订单已取消' })
  }

  async doPay(): Promise<void> {
    if (!this.order) return
    let dialog = new CustomDialogController({
      builder: PaymentPwdDialog({
        onConfirm: async (pwd: string) => {
          try {
            await orderViewModel.payOrder(this.order!.orderNumber, '余额支付', pwd)
            let updated = orderViewModel.getByNumber(this.order!.orderNumber)
            this.order = updated ? updated : null
            this.getUIContext().getPromptAction().showToast({ message: '支付成功！' })
          } catch (_e) {
            this.getUIContext().getPromptAction().showToast({ message: '支付失败，请检查支付密码' })
          }
        }
      }),
      autoCancel: true
    })
    dialog.open()
  }

  async doReceive(): Promise<void> {
    if (!this.order) return
    await orderViewModel.confirmReceive(this.order.orderNumber)
    let updated = orderViewModel.getByNumber(this.order.orderNumber)
    this.order = updated ? updated : null
    this.getUIContext().getPromptAction().showToast({ message: '已确认收货' })
  }

  async deleteOrder(): Promise<void> {
    let dialog = new CustomDialogController({
      builder: ConfirmDialog({
        title: '删除订单',
        message: '确定要删除该订单吗？删除后不可恢复。',
        confirmText: '确定删除',
        onConfirm: () => {
          orderViewModel.deleteOrder(this.order!.orderNumber).then(() => {
            this.getUIContext().getPromptAction().showToast({ message: '订单已删除' })
            AppRouter.back()
          })
        }
      }),
      autoCancel: true,
      customStyle: false
    })
    dialog.open()
  }

  orderStatusColor(s: string): string {
    if (s === OrderStatusValue.CANCELLED || s === OrderStatusValue.REFUNDED) return AppColor.textTertiary()
    if (s === OrderStatusValue.REFUNDING) return AppColor.PRIMARY
    if (s === OrderStatusValue.COMPLETED) return isDarkMode() ? AppColor.SUCCESS_DARK : AppColor.SUCCESS
    return AppColor.PRIMARY
  }

  orderStatusBg(s: string): string {
    if (s === OrderStatusValue.CANCELLED || s === OrderStatusValue.REFUNDED) return AppColor.divider()
    if (s === OrderStatusValue.REFUNDING) return AppColor.primaryBg()
    if (s === OrderStatusValue.COMPLETED) return AppColor.statusBgGreen()
    return AppColor.primaryBg()
  }



  build() {
    Column() {
      HeaderComponent({ title: '订单详情' })

      // ── 导航栏底部渐变淡化过渡 ──
      Row()
        .width('100%').height(12)
        .linearGradient({
          direction: GradientDirection.Bottom,
            colors: [[AppColor.cardBg(), 0], [AppColor.bg(), 1]]
        })

      if (this.isLoading) {
        LoadingView({ message: '加载订单中...' }).layoutWeight(1).width('100%')
      } else if (!this.order) {
        EmptyView({ message: '订单不存在', icon: $rawfile('empty_order.svg') }).layoutWeight(1).width('100%')
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column() {
              Row() {
                Text('#' + this.order.orderNumber.slice(-8))
                  .fontSize(14).fontColor(AppColor.textPrimary()).fontWeight(FontWeight.Medium).layoutWeight(1)
                Text(this.order.status)
                  .fontSize(13)
                  .fontColor(this.orderStatusColor(this.order.status))
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor(this.orderStatusBg(this.order.status))
                  .borderRadius(10).padding({ left: 12, right: 12, top: 4, bottom: 4 })
              }.width('100%')
              if (this.order.status === OrderStatusValue.CANCELLED && this.order.cancelReason) {
                Text('取消原因：' + this.order.cancelReason)
                  .fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary()).width('100%').margin({ top: 8 })
              }
            }
            .width(AppContainer.WIDTH).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG).padding(AppCard.PADDING)
            .shadow(AppShadow.high())

            if (this.order.address) {
              Column() {
                Row() {
                  Text('收货地址').fontSize(15).fontWeight(FontWeight.Medium)
                }.width('100%')
                Text(this.order.address)
                  .fontSize(14).fontColor(AppColor.textSecondary()).width('100%').margin({ top: 6 }).lineHeight(22)
              }
              .width(AppContainer.WIDTH).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG).padding(AppCard.PADDING)
              .shadow(AppShadow.high())
            }

            if (this.trackingInfo && this.trackingInfo.tracking.length > 0) {
              Column() {
                Row() {
                  Text('物流追踪').fontSize(15).fontWeight(FontWeight.Medium)
                  Blank()
                  Text(this.trackingInfo.expressCompany + ' ' + this.trackingInfo.trackingNumber)
                    .fontSize(12).fontColor(AppColor.textTertiary())
                }.width('100%').margin({ bottom: 12 })

                Column({ space: 0 }) {
                  ForEach(this.trackingInfo!.tracking, (point: TrackingPoint, index: number) => {
                    Row() {
                      Column({ space: 0 }) {
                        if (index < this.trackingInfo!.tracking.length - 1) {
                          Line().width(2).height(16).backgroundColor(AppColor.border()).margin({ left: 6 })
                        }
                        Circle().width(14).height(14)
                          .fill(index === 0 ? AppColor.PRIMARY : AppColor.border())
                        if (index > 0) {
                          Line().width(2).height(16).backgroundColor(AppColor.border()).margin({ left: 6 })
                        }
                      }.alignItems(HorizontalAlign.Center).width(24)
                      Column({ space: 2 }) {
                        Text(point.desc).fontSize(14)
                          .fontColor(index === 0 ? AppColor.PRIMARY : AppColor.textSecondary())
                          .fontWeight(index === 0 ? FontWeight.Medium : FontWeight.Regular)
                          .lineHeight(20).width('100%')
                        Text(point.time).fontSize(11).fontColor(AppColor.textTertiary()).width('100%')
                      }.layoutWeight(1).margin({ left: 8 })
                    }
                    .width('100%').alignItems(VerticalAlign.Top)
                    .padding({ top: index === 0 ? 0 : 4, bottom: index === this.trackingInfo!.tracking.length - 1 ? 0 : 4 })
                  }, (point: TrackingPoint) => point.time)
                }.width('100%')
              }
              .width(AppContainer.WIDTH).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG).padding(AppCard.PADDING)
              .shadow(AppShadow.high())
            }

            Column() {
              Text('商品信息').fontSize(15).fontWeight(FontWeight.Medium).width('100%').margin({ bottom: 8 })
              ForEach(this.order.items, (item: CartItem) => {
                Row() {
                  ProductImage({ src: item.productImage }).width(64).height(64).borderRadius(10)
                  Column({ space: 4 }) {
                    Text(item.productName).fontSize(14).fontWeight(FontWeight.Medium)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (item.skuInfo.skuDesc) {
                      Text(item.skuInfo.skuDesc).fontSize(11).fontColor(AppColor.textTertiary())
                    }
                    Text('x' + item.quantity).fontSize(12).fontColor(AppColor.textTertiary())
                  }.margin({ left: 10 }).layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Text('¥' + item.subtotal).fontSize(15).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                }.width('100%').margin({ top: 4, bottom: 4 })
              }, (item: CartItem) => item.productId.toString() + '_' + item.skuInfo.skuId + '_' + this.order!.orderNumber)
            }
            .width(AppContainer.WIDTH).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG).padding(AppCard.PADDING)
            .shadow(AppShadow.high())

            Column({ space: 8 }) {
              Row() {
                Text('订单编号').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                Text(this.order.orderNumber).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
              }.width('100%')
              Row() {
                Text('下单时间').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                Text(this.order.createTime).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
              }.width('100%')
              if (this.order.payTime) {
                Row() {
                  Text('付款时间').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                  Text(this.order.payTime).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
                }.width('100%')
              }
              if (this.order.expressCompany && this.order.trackingNumber) {
                Row() {
                  Text('快递公司').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                  Text(this.order.expressCompany).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
                }.width('100%')
                Row() {
                  Text('快递单号').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                  Text(this.order.trackingNumber).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
                }.width('100%')
              }
              if (this.order.estimatedDelivery) {
                Row() {
                  Text('预计送达').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                  Text(this.order.estimatedDelivery).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
                }.width('100%')
              }
              if (this.order.shipTime) {
                Row() {
                  Text('发货时间').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                  Text(this.order.shipTime).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
                }.width('100%')
              }
              if (this.order.receiveTime) {
                Row() {
                  Text('收货时间').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                  Text(this.order.receiveTime).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
                }.width('100%')
              }
              Row() {
                Text('配送方式').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                Text(this.order.expressCompany || '标准快递').fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
              }.width('100%')
              if (this.order.payMethod) {
                Row() {
                  Text('支付方式').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                  Text(this.order.payMethod).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
                }.width('100%')
              }
              Line().width('100%').height(0.5).backgroundColor(AppColor.divider())
              Row() {
                Text('商品合计').fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary())
                Text('¥' + this.order.totalPrice).fontSize(18).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                  .layoutWeight(1).textAlign(TextAlign.End)
              }.width('100%')
            }
            .width(AppContainer.WIDTH).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG).padding(AppCard.PADDING)
            .shadow(AppShadow.high())

            if (this.order.status === OrderStatusValue.PENDING_SHIP) {
              Row() {
                AppButton({ text: '取消订单', type: AppButtonType.OUTLINE,
                  fontColor: AppColor.CANCEL, buttonHeight: 48, fontSize: 15, fontWeight: FontWeight.Medium,
                  buttonOnClick: () => {
                    let dialog = new CustomDialogController({
                      builder: ConfirmDialog({
                        title: '取消订单',
                        message: '确定要取消此订单吗？',
                        cancelText: '再想想',
                        confirmText: '确认取消',
                        onConfirm: () => { this.cancelWithReason('用户主动取消') }
                      }),
                      autoCancel: true,
                      customStyle: false
                    })
                    dialog.open()
                  } })
                  .layoutWeight(1)
                Blank()
                Text('等待商家发货...').fontSize(14).fontColor(AppColor.PRIMARY)
              }.width(AppContainer.WIDTH)
            }
            if (this.order.status === OrderStatusValue.SHIPPING || this.order.status === OrderStatusValue.PENDING_RECEIVE) {
              AppButton({ text: '确认收货', type: AppButtonType.PRIMARY,
                buttonWidth: AppContainer.WIDTH, buttonHeight: 48,
                fontSize: 15, fontWeight: FontWeight.Bold,
                buttonOnClick: () => { this.doReceive() } })
            }
            if (this.order.status === OrderStatusValue.CANCELLED) {
              AppButton({ text: '删除订单', type: AppButtonType.SECONDARY,
                buttonWidth: AppContainer.WIDTH, buttonHeight: 48, fontSize: 15,
                buttonOnClick: () => { this.deleteOrder() } })
            }

            Blank().height(24)
          }
          .width('100%').alignItems(HorizontalAlign.Center).padding({ top: 4, bottom: 8 })
        }
        .layoutWeight(1).width('100%').backgroundColor(AppColor.bg()).scrollBar(BarState.Off)
      }

      // ── 底部固定「申请售后」按钮（始终可见）──
      if (this.canAfterSales) {
        Column() {
          AppButton({ text: '申请售后', type: AppButtonType.PRIMARY,
            buttonWidth: '100%', buttonHeight: 48, fontSize: 16, fontWeight: FontWeight.Bold,
            buttonOnClick: () => { AppRouter.goToAfterSales(this.order!.orderNumber) } })
        }
        .width('100%').backgroundColor(AppColor.cardBg())
        .shadow({ radius: 4, color: AppColor.shadowLight(), offsetX: 0, offsetY: -2 })
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
      }
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
      .opacity(0)
    PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
      .opacity(0)
  }
}

@CustomDialog
struct PaymentPwdDialog {
  controller?: CustomDialogController
  onConfirm: (pwd: string) => void = () => {}
  onCancel: () => void = () => {}

  @State pwdInput: string = ''

  build() {
    Column({ space: 16 }) {
      Text('请输入支付密码').fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary()).textAlign(TextAlign.Center).width('100%')
      Row() {
        TextInput({ placeholder: '请输入6位数字支付密码', text: this.pwdInput })
          .type(InputType.Password)
          .maxLength(6)
          .fontSize(16)
          .fontColor(AppColor.textPrimary())
          .placeholderColor(AppColor.textTertiary())
          .height(48)
          .backgroundColor(AppColor.inputBg())
          .borderRadius(AppRadius.SM)
          .padding({ left: 12, right: 12 })
          .onChange((v: string) => {
            this.pwdInput = v.replace(/\D/g, '').slice(0, 6)
          })
          .layoutWeight(1)
      }.width('100%')
      Row({ space: 12 }) {
        AppButton({
          text: '取消',
          type: AppButtonType.SECONDARY,
          buttonOnClick: () => { this.controller?.close(); this.onCancel() }
        }).layoutWeight(1)
        AppButton({
          text: '确认支付',
          type: AppButtonType.PRIMARY,
          buttonOnClick: () => {
            if (this.pwdInput.length < 6) {
              this.getUIContext().getPromptAction().showToast({ message: '请输入完整的6位数字支付密码' })
              return
            }
            this.onConfirm(this.pwdInput)
            this.controller?.close()
          }
        }).layoutWeight(1)
      }.width('100%')
      .padding({ top: 4 })
    }
    .padding(24)
    .backgroundColor(AppColor.cardBg())
    .borderRadius(AppRadius.LG)
    .width(AppContainer.DIALOG_WIDTH)
    .shadow({ radius: 16, color: AppColor.shadowLight(), offsetX: 0, offsetY: 4 })
  }
}
