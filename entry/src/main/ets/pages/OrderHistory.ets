import { Order, CartItem } from '../data/model/ProductModel'
import { orderViewModel } from '../viewmodel/OrderViewModel'
import { orderRepository } from '../data/repository/OrderRepository'
import { OrderStatusValue, RoutePath } from '../common/Constants'
import { HttpClient } from '../data/HttpClient'
import { AppRouter } from '../common/AppRouter'
import { EmptyView, LoadingView } from '../components/StatusViews'
import { OrderHistoryParams } from '../common/AppRouter'
import { ProductImage } from '../components/ProductImage'
import { ConfirmDialog } from '../components/DialogComponent'
import { AppButton, AppButtonType } from '../components/AppButton'
import { HeaderComponent } from '../components/HeaderComponent'
import { AppColor, AppRadius, AppCard, AppContainer, isDarkMode } from '../common/StyleConstants'

const STATUS_TABS: string[] = ['全部', '待付款', '待发货', '待收货', '已完成', '退款/售后']

const TAB_SERVER_STATUS: Record<string, string> = {
  '待付款': '待付款',
  '待发货': '待发货',
  '待收货': '配送中',
  '已完成': '已完成',
  '退款/售后': ''
}

function isWithinDays(dateStr: string, days: number): boolean {
  if (!dateStr) return true
  const date = new Date(dateStr)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  return diffMs < days * 24 * 60 * 60 * 1000
}

function isInTab(order: Order, tab: string): boolean {
  if (tab === '全部') return true
  if (tab === '待付款') return order.status === OrderStatusValue.PENDING_PAYMENT
  if (tab === '待发货') return order.status === OrderStatusValue.PENDING_SHIP
  if (tab === '待收货') return order.status === OrderStatusValue.SHIPPING || order.status === OrderStatusValue.PENDING_RECEIVE
  if (tab === '已完成') return order.status === OrderStatusValue.COMPLETED
  if (tab === '退款/售后') return order.status === OrderStatusValue.REFUNDING || order.status === OrderStatusValue.REFUNDED
  return false
}

class OrdersDataSource implements IDataSource {
  private data: Order[] = []
  private listeners: DataChangeListener[] = []

  update(orders: Order[]): void {
    this.data = orders
    for (let l of this.listeners) {
      l.onDataReloaded()
    }
  }

  totalCount(): number {
    return this.data.length
  }

  getData(index: number): Order {
    return this.data[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    let idx = this.listeners.indexOf(listener)
    if (idx >= 0) {
      this.listeners.splice(idx, 1)
    }
  }
}

@Entry
@Component
struct OrderHistory {
  params: OrderHistoryParams = new OrderHistoryParams()
  @StorageLink('themeMode') themeMode: number = 0
  @State orders: Order[] = []
  @State selectedStatus: string = '全部'

  @State showReceive: boolean = false
  @State receiveOrder: Order | null = null

  @State showRefund: boolean = false
  @State refundOrder: Order | null = null
  @State refundReason: string = '质量问题'
  @State refundStage: number = 0
  @State isLoading: boolean = true
  @State isRefreshing: boolean = false
  private tabScroller: Scroller = new Scroller()
  private orderDataSource: OrdersDataSource = new OrdersDataSource()

  setOrders(orders: Order[]): void {
    this.orders = orders
    this.syncOrders()
  }

  syncOrders(): void {
    this.orderDataSource.update(this.getFilteredOrders())
  }

  async aboutToAppear(): Promise<void> {
    this.isLoading = true
    let routerP = AppRouter.getParams<OrderHistoryParams>()
    if (routerP) this.params = routerP
    let p = this.params
    if (p && p.tab && STATUS_TABS.indexOf(p.tab) >= 0) {
      this.selectedStatus = p.tab
    }
    await orderRepository.load()
    this.setOrders([...orderViewModel.orders])
    this.isLoading = false
  }

  async onPageShow(): Promise<void> {
    this.isLoading = true
    await orderRepository.load()
    this.setOrders([...orderViewModel.orders])
    this.isLoading = false
  }

  async onRefresh(): Promise<void> {
    try {
      await orderRepository.load()
      this.setOrders([...orderViewModel.orders])
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({ message: '刷新失败，请重试' })
    }
    this.isRefreshing = false
  }

  async selectTab(st: string, index: number): Promise<void> {
    this.selectedStatus = st
    if (index === 0) {
      this.tabScroller.scrollTo({ xOffset: 0, yOffset: 0 })
    } else {
      let offset = index * 68 - 100
      if (offset < 0) offset = 0
      this.tabScroller.scrollTo({ xOffset: offset, yOffset: 0 })
    }
    await orderRepository.load()
    this.setOrders([...orderViewModel.orders])
  }

  getFilteredOrders(): Order[] {
    return (this.orders ?? []).filter(o => isInTab(o, this.selectedStatus))
  }

  async deleteOrder(order: Order): Promise<void> {
    let dialog = new CustomDialogController({
      builder: ConfirmDialog({
        title: '删除订单',
        message: '确定要删除该订单吗？',
        confirmText: '确定删除',
        onConfirm: () => {
          orderViewModel.deleteOrder(order.orderNumber).then(() => {
            this.setOrders([...orderViewModel.orders])
          })
        }
      }),
      autoCancel: true,
      customStyle: false
    })
    dialog.open()
  }

  async doPay(order: Order): Promise<void> {
    try {
      let data: Object = await HttpClient.post('/payment/page/' + order.orderNumber, {})
      let resp = data as Record<string, Object>
      let payUrl = resp.payUrl as string
      if (payUrl) {
        AppRouter.goToWebView(payUrl, '支付', order.orderNumber)
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '获取支付链接失败，请重试' })
      }
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({ message: '支付失败，请重试' })
    }
  }

  openReceive(order: Order): void {
    this.receiveOrder = order
    this.showReceive = true
  }

  async doReceive(): Promise<void> {
    if (this.receiveOrder) {
      await orderViewModel.confirmReceive(this.receiveOrder.orderNumber)
      this.setOrders([...orderViewModel.orders])
    }
    this.showReceive = false
    this.getUIContext().getPromptAction().showToast({ message: '已确认收货' })
  }

  openRefund(order: Order): void {
    this.refundOrder = order
    this.refundReason = '质量问题'
    this.refundStage = 0
    this.showRefund = true
  }

  async doRefund(): Promise<void> {
    this.refundStage = 1
    setTimeout(async () => {
      try {
        if (this.refundOrder) {
          await orderViewModel.requestRefund(this.refundOrder.orderNumber, this.refundReason)
          this.setOrders([...orderViewModel.orders])
        }
        this.showRefund = false
        this.getUIContext().getPromptAction().showToast({ message: '退款申请已提交' })
      } catch (err) {
        this.getUIContext().getPromptAction().showToast({ message: '退款失败，请重试' })
        this.refundStage = 0
      }
    }, 1000)
  }

  cancelOrderWithReason(order: Order): void {
    let dialog = new CustomDialogController({
      builder: ConfirmDialog({
        title: '取消订单',
        message: '确定要取消该订单吗？',
        cancelText: '再想想',
        confirmText: '取消订单',
        onConfirm: () => {
          orderViewModel.cancelOrder(order.orderNumber, '主动取消').then(() => {
            this.setOrders([...orderViewModel.orders])
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

  @Builder OrderCard(order: Order, onTap: () => void, onPay: () => void, onReceive: () => void, onRefund: () => void, onCancel: () => void, onDelete: () => void) {
    Column() {
      Row() {
        Text('#' + order.orderNumber.slice(-8))
          .fontSize(13).fontWeight(FontWeight.Regular).fontColor(AppColor.textTertiary()).layoutWeight(1)
        Text(order.status)
          .fontSize(12).fontColor(this.orderStatusColor(order.status)).fontWeight(FontWeight.Medium)
          .backgroundColor(this.orderStatusBg(order.status)).borderRadius(10)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      }
      .width('100%').margin({ bottom: 10 })

      if ((order.status === OrderStatusValue.CANCELLED) && order.cancelReason) {
        Text('取消原因：' + order.cancelReason)
          .fontSize(12).fontColor(AppColor.textTertiary()).width('100%').margin({ bottom: 6 })
      }

      ForEach(order.items, (item: CartItem) => {
        Row() {
          ProductImage({ src: item.productImage }).width(64).height(64).borderRadius(10)
          Column({ space: 4 }) {
            Text(item.productName).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(item.productName.length > 0 ? 'x' + item.quantity : '').fontSize(12).fontColor(AppColor.textTertiary())
          }.margin({ left: 10 }).layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('¥' + item.subtotal).fontSize(15).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
        }
        .width('100%').margin({ top: 4, bottom: 4 })
      }, (item: CartItem) => item.productId.toString())

      Line().width('100%').height(0.5).backgroundColor(AppColor.divider()).margin({ top: 8, bottom: 8 })

      Row() {
        Text(order.createTime).fontSize(11).fontColor(AppColor.textDisabledLight())
        Blank()
        Text('合计：¥' + order.totalPrice).fontSize(16).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
      }.width('100%').margin({ bottom: 10 })

      Row() {
        if (order.status === OrderStatusValue.PENDING_PAYMENT) {
          AppButton({ text: '取消订单', type: AppButtonType.SECONDARY,
            buttonWidth: 0, buttonHeight: 32, fontSize: 12, buttonRadius: 16,
            buttonOnClick: () => { onCancel() } })
            .constraintSize({ minWidth: 80 })
          Blank().layoutWeight(1)
          AppButton({ text: '去付款', type: AppButtonType.PRIMARY,
            buttonWidth: 0, buttonHeight: 32, fontSize: 12, buttonRadius: 16,
            buttonOnClick: () => { onPay() } })
            .constraintSize({ minWidth: 80 })
        } else if (order.status === OrderStatusValue.PENDING_SHIP) {
          AppButton({ text: '取消订单', type: AppButtonType.SECONDARY,
            buttonWidth: 0, buttonHeight: 32, fontSize: 12, buttonRadius: 16,
            buttonOnClick: () => { onCancel() } })
            .constraintSize({ minWidth: 80 })
          Blank().layoutWeight(1)
          Text('等待商家发货...').fontSize(12).fontColor(AppColor.PRIMARY)
        } else if (order.status === OrderStatusValue.SHIPPING || order.status === OrderStatusValue.PENDING_RECEIVE) {
          Blank().layoutWeight(1)
          AppButton({ text: '确认收货', type: AppButtonType.PRIMARY,
            buttonWidth: 0, buttonHeight: 32, fontSize: 12, buttonRadius: 16,
            buttonOnClick: () => { onReceive() } })
            .constraintSize({ minWidth: 80 })
        } else if (order.status === OrderStatusValue.COMPLETED) {
          Blank().layoutWeight(1)
          Button() {
            Text('去评价').fontSize(12).fontColor(Color.White)
          }
            .width(80).height(32).borderRadius(16)
            .backgroundColor(AppColor.PRIMARY)
            .onClick(() => { AppRouter.push(RoutePath.MY_REVIEWS) })
            .margin({ right: 8 })
          Button() {
            Text('申请售后').fontSize(12).fontColor(Color.White)
          }
            .width(80).height(32).borderRadius(16)
            .backgroundColor(AppColor.PRIMARY)
            .onClick(() => { AppRouter.goToAfterSales(order.orderNumber) })
            .margin({ right: 8 })
          if (!isWithinDays(order.receiveTime, 7)) {
            AppButton({ text: '删除订单', type: AppButtonType.TEXT,
              fontColor: AppColor.textTertiary(), buttonWidth: 0, buttonHeight: 32, fontSize: 12, buttonRadius: 16,
              buttonOnClick: () => { onDelete() } })
              .constraintSize({ minWidth: 80 })
          }
        } else if (order.status === OrderStatusValue.CANCELLED) {
          Blank().layoutWeight(1)
          AppButton({ text: '删除订单', type: AppButtonType.TEXT,
            fontColor: AppColor.textTertiary(), buttonWidth: 0, buttonHeight: 32, fontSize: 12, buttonRadius: 16,
            buttonOnClick: () => { onDelete() } })
            .constraintSize({ minWidth: 80 })
        } else if (order.status === OrderStatusValue.REFUNDING || order.status === OrderStatusValue.REFUNDED) {
          Blank().layoutWeight(1)
          Text(order.status === OrderStatusValue.REFUNDING ? '等待商家处理...' : '已退款完成').fontSize(12).fontColor(AppColor.PRIMARY)
        }
      }.width('100%')
    }
    .width('100%').backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG).padding(AppCard.PADDING)
    .shadow({ radius: AppCard.ELEVATION, color: AppCard.shadowColor(), offsetX: 0, offsetY: 2 })
    .onClick(() => { onTap() })
    .hoverEffect(HoverEffect.Scale)
  }

  build() {
    Stack() {
      Column() {
        Column() {
          HeaderComponent({ title: '我的订单' })

          Row() {
            Scroll(this.tabScroller) {
              Row({ space: 4 }) {
                ForEach(STATUS_TABS, (st: string, idx: number) => {
                  Text(st)
                    .fontSize(12).fontWeight(this.selectedStatus === st ? FontWeight.Medium : FontWeight.Regular)
                    .fontColor(this.selectedStatus === st ? AppColor.WHITE : AppColor.textSecondary())
                    .backgroundColor(this.selectedStatus === st ? AppColor.PRIMARY : AppColor.inputBg())
                    .borderRadius(14)
                    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                    .onClick(() => { this.selectTab(st, idx) })
                }, (st: string) => st)
              }.padding({ left: '4%', right: '4%', bottom: 4 })
            }
            .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          }
          .width('100%').padding({ top: 4, bottom: 8 })
        }
        .backgroundColor(AppColor.cardBg())

        // ── 导航栏底部渐变淡化过渡 ──
        Row()
          .width('100%').height(12)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [[AppColor.cardBg(), 0], [AppColor.bg(), 1]]
          })

        if (this.isLoading) {
          LoadingView({ message: '加载订单中...' }).layoutWeight(1).width('100%')
        } else if ((this.orders ?? []).length === 0) {
          EmptyView({ message: '暂无订单记录', icon: $rawfile('empty_order.svg') })
        } else if (this.getFilteredOrders().length === 0) {
          EmptyView({ message: '暂无该状态订单', icon: $rawfile('empty_order.svg') })
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ space: 12 }) {
              LazyForEach(this.orderDataSource, (order: Order) => {
                ListItem() {
                  this.OrderCard(order,
                    () => { AppRouter.goToOrderDetail(order.orderNumber) },
                    () => { this.doPay(order) },
                    () => { this.openReceive(order) },
                    () => { this.openRefund(order) },
                    () => { this.cancelOrderWithReason(order) },
                    () => { this.deleteOrder(order) }
                  )
                }
              }, (order: Order) => order.orderNumber)
            }
            .cachedCount(5)
            .scrollBar(BarState.Off)
          }
          .onRefreshing(() => { this.onRefresh() })
          .layoutWeight(1)
          .width(AppContainer.WIDTH).padding({ bottom: 24 }).margin({ top: 4 })
        }
      }
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
