import { browseHistoryRepository, BrowseHistoryItem } from '../data/repository/BrowseHistoryRepository'
import { AppRouter } from '../common/AppRouter'
import { AppColor, AppRadius } from '../common/StyleConstants'
import { EmptyView, LoadingView } from '../components/StatusViews'
import { ProductImage } from '../components/ProductImage'
import { HeaderComponent } from '../components/HeaderComponent'


@Entry
@Component
struct BrowseHistory {
  @State items: BrowseHistoryItem[] = []
  @State loading: boolean = true

  async aboutToAppear(): Promise<void> {
    await this.loadData()
  }

  async onPageShow(): Promise<void> {
    await this.loadData()
  }

  async loadData(): Promise<void> {
    await browseHistoryRepository.load()
    this.items = browseHistoryRepository.getAll()
    this.loading = false
  }

  build() {
    Column() {
      HeaderComponent({ title: '浏览记录', rightAction: this.items.length > 0 ? '清空' : '', onRightAction: async () => { await browseHistoryRepository.clear(); this.items = []; this.getUIContext().getPromptAction().showToast({ message: '浏览记录已清空' }) } })

      if (this.loading) {
        LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
      } else if (this.items.length === 0) {
        Blank().layoutWeight(1)
          Column() {
            EmptyView({ message: '暂无浏览记录', icon: $rawfile('ic_clock.svg') })
          }.alignItems(HorizontalAlign.Center)
        Blank().layoutWeight(1)
      } else {
        List({ space: 12 }) {
          ForEach(this.items, (item: BrowseHistoryItem) => {
            ListItem() {
              Row() {
                ProductImage({ src: item.image }).width(80).height(80).borderRadius(10)
                Column({ space: 4 }) {
                  Text(item.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary()).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text('¥' + item.price).fontSize(18).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                  Text('浏览于 ' + item.lastViewed.slice(0, 16)).fontSize(11).fontColor(AppColor.textTertiary())
                }
                .margin({ left: 12 }).layoutWeight(1).alignItems(HorizontalAlign.Start).height(80)
              }
              .width('100%').padding(12).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
              .transition(TransitionEffect.opacity(0).animation({ duration: 300, curve: Curve.EaseOut }))
              .onClick(() => { AppRouter.goToProductDetail(item.productId) })
              .hoverEffect(HoverEffect.Scale)
            }
          }, (item: BrowseHistoryItem) => item.productId.toString())
        }
        .width('92%').layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn }).opacity(0)
    PageTransitionExit({ duration: 250, curve: Curve.FastOutLinearIn }).opacity(0)
  }
}