import { adminRepository, AdminOrderItem, AdminOrder } from '../data/repository/AdminRepository'
import { AppColor, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppInput } from '../components/AppInput'

import { HeaderComponent } from '../components/HeaderComponent'
import { LoadingView, EmptyView } from '../components/StatusViews'
import { ProductImage } from '../components/ProductImage'

class AdminOrderDataSource implements IDataSource {
  private dataArray: AdminOrder[] = []

  pushData(data: AdminOrder[]): void {
    this.dataArray = data
  }

  totalCount(): number {
    return this.dataArray.length
  }

  getData(index: number): AdminOrder {
    return this.dataArray[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {}

  unregisterDataChangeListener(listener: DataChangeListener): void {}
}

@Entry
@Component
struct AdminOrders {
  @State orders: AdminOrder[] = []
  @State ordersDataSource: AdminOrderDataSource = new AdminOrderDataSource()
  @State isLoading: boolean = true
  @State showShipDialog: boolean = false
  @State shippingOrder: AdminOrder | null = null
  @State shipTracking: string = ''
  @State shipCompany: string = ''

  async aboutToAppear(): Promise<void> {
    await this.loadOrders()
  }

  async onPageShow(): Promise<void> {
    await this.loadOrders()
  }

  async loadOrders(): Promise<void> {
    this.isLoading = true
    let data: Object[] = await adminRepository.getOrders()
    this.orders = data as AdminOrder[]
    this.ordersDataSource.pushData(this.orders)
    this.isLoading = false
  }

  openShip(order: AdminOrder): void {
    this.shippingOrder = order
    this.shipTracking = ''
    this.shipCompany = ''
    this.showShipDialog = true
  }

  async doShip(): Promise<void> {
    if (!this.shippingOrder) {
      this.getUIContext().getPromptAction().showToast({ message: '请选择订单' })
      return
    }
    if (!this.shipTracking.trim()) {
      this.getUIContext().getPromptAction().showToast({ message: '请输入快递单号' })
      return
    }
    let ok = await adminRepository.shipOrder(
      this.shippingOrder.order_number,
      this.shipTracking.trim(),
      this.shipCompany.trim() || '默认快递'
    )
    if (ok) {
      this.getUIContext().getPromptAction().showToast({ message: '发货成功' })
      this.showShipDialog = false
      await this.loadOrders()
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '发货失败' })
    }
  }

  getStatusColor(status: string): string {
    if (status === '待付款') return AppColor.PRIMARY
    if (status === '待发货') return AppColor.statusBlue()
    if (status.indexOf('售后') !== -1) return AppColor.statusPink()
    if (status.indexOf('退款') !== -1) return AppColor.statusPink()
    return AppColor.textDisabledLight()
  }

  build() {
    Stack() {
      Column() {
        HeaderComponent({ title: '订单管理' })

        if (this.isLoading) {
          LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
        } else if (this.orders.length === 0) {
          EmptyView({ message: '暂无订单', icon: $rawfile('empty_order.svg') }).layoutWeight(1).width('100%')
        } else {
          List({ space: 10 }) {
            LazyForEach(this.ordersDataSource, (order: AdminOrder) => {
              ListItem() {
                Column() {
                  Row() {
                    Text('#' + order.order_number.slice(-10)).fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
                    Blank()
                    Text(order.status).fontSize(12).fontColor(this.getStatusColor(order.status)).fontWeight(FontWeight.Medium)
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .backgroundColor(this.getStatusColor(order.status) + '1A')
                      .borderRadius(AppRadius.SM)
                  }.width('100%')

                  Text(order.username).fontSize(12).fontColor(AppColor.textTertiary()).width('100%').margin({ top: 4 })

                  ForEach(order.items || [], (item: AdminOrderItem) => {
                    Row() {
                      ProductImage({ src: item.product_image })
                        .width(44).height(44).borderRadius(AppRadius.SM)
                      Column({ space: 2 }) {
                        Text(item.product_name).fontSize(13).fontColor(AppColor.textPrimary()).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text('x' + item.quantity).fontSize(11).fontColor(AppColor.textTertiary())
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 8 })
                      Text('¥' + (item.product_price * item.quantity).toFixed(0)).fontSize(13).fontColor(AppColor.PRIMARY)
                    }.width('100%').margin({ top: 4 })
                  }, (item: AdminOrderItem) => item.product_id.toString())

                  Row() {
                    Text('合计: ¥' + order.total_price.toFixed(0)).fontSize(14).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                    Blank()
                    Text(order.create_time).fontSize(11).fontColor(AppColor.textTertiary())
                  }.width('100%').margin({ top: 6 })

                  if (order.status === '待发货') {
                    AppButton({ text: '立即发货', type: AppButtonType.PRIMARY,
                      buttonHeight: 34, fontSize: 13, buttonRadius: AppRadius.PILL,
                      buttonOnClick: () => { this.openShip(order) } })
                      .width('100%').margin({ top: 8 })
                  }

                  if (order.tracking_number) {
                    Text('快递: ' + (order.express_company || '') + ' - ' + order.tracking_number)
                      .fontSize(11).fontColor(AppColor.textTertiary()).width('100%').margin({ top: 4 })
                  }
                }.width('92%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
                .shadow(AppShadow.mid())
              }
            }, (order: AdminOrder) => order.order_number)
          }
          .cachedCount(5)
          .width('100%').padding({ bottom: 24 })
          .layoutWeight(1)
        }
      }
      .width('100%').height('100%').backgroundColor(AppColor.bg())

      if (this.showShipDialog) {
        Column() {
          Column({ space: 14 }) {
            Text('发货').fontSize(18).fontWeight(FontWeight.Bold).width('100%')

            if (this.shippingOrder) {
              Text('订单: #' + this.shippingOrder.order_number.slice(-10)).fontSize(13).fontColor(AppColor.textTertiary()).width('100%')
            }

            AppInput({ placeholder: '快递公司 (如 顺丰)', value: this.shipCompany, onChange: (v: string) => { this.shipCompany = v } })
            AppInput({ placeholder: '快递单号 *', value: this.shipTracking, onChange: (v: string) => { this.shipTracking = v } })

            Row({ space: 12 }) {
              AppButton({ text: '取消', type: AppButtonType.SECONDARY,
                buttonHeight: 44, buttonOnClick: () => { this.showShipDialog = false } })
                .layoutWeight(1)
              AppButton({ text: '确认发货', type: AppButtonType.PRIMARY,
                buttonHeight: 44, fontWeight: FontWeight.Bold,
                buttonOnClick: () => { this.doShip() } })
                .layoutWeight(2)
            }.width('100%')
          }.width('88%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn }).opacity(0)
    PageTransitionExit({ duration: 250, curve: Curve.FastOutLinearIn }).opacity(0)
  }
}