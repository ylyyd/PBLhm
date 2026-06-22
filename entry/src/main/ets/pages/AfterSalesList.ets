import { afterSalesRepository, AfterSalesItem } from '../data/repository/AfterSalesRepository'
import { AppRouter } from '../common/AppRouter'
import { EmptyView, LoadingView } from '../components/StatusViews'
import { HeaderComponent } from '../components/HeaderComponent'
import { AppColor, AppRadius, AppCard, isDarkMode } from '../common/StyleConstants'

const AFTER_SALE_TYPE_LABELS: Record<string, string> = {
  'refund': '仅退款', 'return': '退货退款', 'exchange': '换货'
}

const AFTER_SALE_STATUS_LABELS: Record<string, string> = {
  'pending': '待处理', 'processing': '处理中', 'approved': '已通过',
  'rejected': '已拒绝', 'completed': '已完成', 'cancelled': '已取消'
}

// 合并显示：如果订单已退款，显示"已退款"；否则显示售后状态标签
function EffectiveStatus(item: AfterSalesItem): string {
  if (item.currentOrderStatus === '已退款') return '已退款'
  if (item.status === 'cancelled') return '已取消'
  return AFTER_SALE_STATUS_LABELS[item.status] || item.status
}

function EffectiveStatusColor(status: string): string {
  if (status === '已退款') return AppColor.statusPink()
  if (status === '已通过') return isDarkMode() ? AppColor.SUCCESS_DARK : AppColor.SUCCESS
  if (status === '已拒绝' || status === '已取消') return AppColor.CANCEL
  if (status === '已完成') return isDarkMode() ? AppColor.SUCCESS_DARK : AppColor.SUCCESS
  if (status === '待处理' || status === '处理中') return AppColor.PRIMARY
  return AppColor.textTertiary()
}

function EffectiveStatusBg(status: string): string {
  if (status === '已退款') return AppColor.primaryBg()
  if (status === '已通过' || status === '已完成') return AppColor.statusBgGreen()
  if (status === '已拒绝') return AppColor.statusBgRed()
  if (status === '已取消') return AppColor.divider()
  return AppColor.primaryBg()
}

@Entry
@Component
struct AfterSalesList {
  @StorageLink('themeMode') themeMode: number = 0
  @State items: AfterSalesItem[] = []
  @State isLoading: boolean = true
  @State isRefreshing: boolean = false

  async aboutToAppear(): Promise<void> {
    await this.loadData()
  }

  async onPageShow(): Promise<void> {
    await this.loadData()
  }

  async loadData(): Promise<void> {
    this.isLoading = true
    this.items = await afterSalesRepository.getAll()
    this.isLoading = false
  }

  async onRefresh(): Promise<void> {
    this.items = await afterSalesRepository.getAll()
    this.isRefreshing = false
  }

  build() {
    Column() {
      HeaderComponent({ title: '售后' })

      if (this.isLoading) {
        LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
      } else if (this.items.length === 0) {
        EmptyView({ message: '暂无售后记录', icon: $rawfile('ic_refund.svg') }).layoutWeight(1).width('100%')
      } else {
        Column({ space: 8 }) {
          Text('历史记录').fontSize(13).fontColor(AppColor.textTertiary()).width('92%')
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ space: 8 }) {
              ForEach(this.items, (item: AfterSalesItem) => {
                ListItem() {
                  Column() {
                    Row() {
                      Text(EffectiveStatus(item))
                        .fontSize(12).fontColor(EffectiveStatusColor(EffectiveStatus(item))).fontWeight(FontWeight.Medium)
                        .backgroundColor(EffectiveStatusBg(EffectiveStatus(item))).borderRadius(10)
                        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                      Blank()
                      Text(AFTER_SALE_TYPE_LABELS[item.type] || item.type)
                        .fontSize(13).fontColor(AppColor.textSecondary())
                      Text('¥' + item.refundAmount)
                        .fontSize(15).fontWeight(FontWeight.Bold).fontColor(AppColor.PRIMARY)
                        .margin({ left: 8 })
                    }
                    .width('100%')

                    Row() {
                      Text('#' + item.orderNumber.slice(-8))
                        .fontSize(12).fontColor(AppColor.textTertiary())
                      Text(item.applyTime.slice(0, 10))
                        .fontSize(12).fontColor(AppColor.textTertiary()).margin({ left: 12 })
                    }
                    .width('100%').margin({ top: 6 })
                  }
                  .width('100%').padding(AppCard.PADDING)
                  .backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
                  .shadow({ radius: 2, color: AppCard.shadowColor(), offsetX: 0, offsetY: 1 })
                  .onClick(() => { AppRouter.goToAfterSales(item.orderNumber) })
                  .hoverEffect(HoverEffect.Scale)
                }
              }, (item: AfterSalesItem) => item.id.toString())
            }
            .cachedCount(4)
            .scrollBar(BarState.Off)
            .width('92%').padding({ bottom: 24 })
          }
          .layoutWeight(1).width('100%')
          .onRefreshing(() => { this.onRefresh() })
        }
        .width('100%').alignItems(HorizontalAlign.Center).margin({ top: 8 })
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
