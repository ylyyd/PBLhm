import { Product } from '../data/model/ProductModel'
import { productRepository } from '../data/repository/ProductRepository'
import { favoriteRepository } from '../data/repository/FavoriteRepository'
import { cartViewModel } from '../viewmodel/CartViewModel'
import { browseHistoryRepository } from '../data/repository/BrowseHistoryRepository'
import { AppRouter } from '../common/AppRouter'

import { AppColor, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppContainer } from '../components/AppContainer'
import { LoadingView, EmptyView } from '../components/StatusViews'
import { ProductImage } from '../components/ProductImage'
import { HeartIcon } from '../components/HeartIcon'
import { HeaderComponent } from '../components/HeaderComponent'

@Entry
@Component
struct Favorites {
  params: Record<string, Object> = {}
  @State products: Product[] = []
  @State loadError: string = ''
  @State currentTab: number = 0
  @State historyProducts: Product[] = []
  @State isRefreshing: boolean = false
  @State showClearConfirm: boolean = false
  @State isLoading: boolean = true
  @State favoritedIds: number[] = []

  async aboutToAppear(): Promise<void> {
    let routerP = AppRouter.getParams<Record<string, Object>>()
    if (routerP) this.params = routerP
    let p = this.params
    this.currentTab = (p?.tab as number) || 0
    await this.loadData()
  }

  async onPageShow(): Promise<void> {
    await this.loadData()
  }

  async loadData(): Promise<void> {
    this.isLoading = true
    this.loadError = ''
    try {
      await favoriteRepository.load()
      this.loadFavorites()
      this.loadHistory()
    } catch (err) {
      this.loadError = '加载收藏失败'
    }
    this.isLoading = false
    this.isRefreshing = false
  }

  loadFavorites(): void {
    let ids = favoriteRepository.getAll()
    this.favoritedIds = ids
    let list: Product[] = []
    for (let i = 0; i < ids.length; i++) {
      let p = productRepository.getById(ids[i])
      if (p) { list.push(p) }
    }
    this.products = list
  }

  async loadHistory(): Promise<void> {
    await browseHistoryRepository.load()
    let items = browseHistoryRepository.getAll()
    let list: Product[] = []
    for (let i = 0; i < items.length; i++) {
      let p = productRepository.getById(items[i].productId)
      if (p) { list.push(p) }
    }
    this.historyProducts = list
  }

  async toggleFavorite(productId: number): Promise<void> {
    let nowFav = await favoriteRepository.toggle(productId)
    this.favoritedIds = favoriteRepository.getAll()
    this.loadFavorites()
    this.getUIContext().getPromptAction().showToast({ message: nowFav ? '已收藏' : '已取消收藏' })
  }

  async addToCart(product: Product): Promise<void> {
    await cartViewModel.addToCart(product)
    this.getUIContext().getPromptAction().showToast({ message: '已加入购物车' })
  }

  async clearAll(): Promise<void> {
    await favoriteRepository.clearAll()
    this.loadFavorites()
    this.showClearConfirm = false
    this.getUIContext().getPromptAction().showToast({ message: '已清空所有收藏' })
  }

  async clearHistory(): Promise<void> {
    await browseHistoryRepository.clear()
    this.historyProducts = []
    this.getUIContext().getPromptAction().showToast({ message: '已清空浏览记录' })
  }

  build() {
    Stack() {
      Column() {
        HeaderComponent({ title: this.currentTab === 0 ? '我的收藏' : '浏览记录' })

        Row({ space: 0 }) {
          Button('收藏')
            .height(36).layoutWeight(1).padding(0)
            .backgroundColor(this.currentTab === 0 ? AppColor.PRIMARY : AppColor.divider())
            .fontSize(14).fontColor(this.currentTab === 0 ? AppColor.WHITE : AppColor.textSecondary())
            .borderRadius(0)
            .onClick(() => { this.currentTab = 0 })
          Button('浏览记录')
            .height(36).layoutWeight(1).padding(0)
            .backgroundColor(this.currentTab === 1 ? AppColor.PRIMARY : AppColor.divider())
            .fontSize(14).fontColor(this.currentTab === 1 ? AppColor.WHITE : AppColor.textSecondary())
            .borderRadius(0)
            .onClick(() => { this.currentTab = 1 })
        }
        .width('92%').borderRadius(18).clip(true).margin({ bottom: 8 })

        if (this.isLoading) {
          LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
        } else if (this.loadError) {
          Column() {
            EmptyView({ message: this.loadError })
            AppButton({ text: '重试', type: AppButtonType.PRIMARY, buttonWidth: 100, buttonHeight: 36, buttonOnClick: () => { this.loadData() } })
          }
          .layoutWeight(1).width('100%').alignItems(HorizontalAlign.Center)
        } else if (this.currentTab === 0 && this.products.length === 0) {
          EmptyView({ message: '还没有收藏商品', icon: $rawfile('empty_favorite.svg') }).layoutWeight(1).width('100%')
        } else if (this.currentTab === 1 && this.historyProducts.length === 0) {
          EmptyView({ message: '暂无浏览记录', icon: $rawfile('ic_clock.svg') }).layoutWeight(1).width('100%')
        } else {
          Column() {
            Refresh({ refreshing: $$this.isRefreshing }) {
              Scroll() {
                Column({ space: 10 }) {
                if (this.currentTab === 0) {
                  ForEach(this.products, (product: Product) => {
                    FavoriteItemRow({
                      product: product,
                      onToggle: () => { this.toggleFavorite(product.id) },
                      onAddToCart: () => { this.addToCart(product) },
                      onCardClick: () => { AppRouter.goToProductDetail(product.id) }
                    })
                  }, (product: Product) => product.id.toString())
                } else {
                  ForEach(this.historyProducts, (product: Product) => {
                    Row() {
                      ProductImage({ src: product.image })
                        .width(90).height(90).borderRadius(12)
                      Column({ space: 5 }) {
                        Text(product.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(product.description).fontSize(12).fontColor(AppColor.textTertiary())
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        Row() {
                          Text('¥' + product.price).fontSize(16).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                          Blank()
                          HeartIcon({ filled: this.favoritedIds.indexOf(product.id) >= 0, iconSize: 20, onToggle: () => { this.toggleFavorite(product.id) } })
                        }.width('100%')
                      }
                      .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 12 })
                    }
                    .width('92%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(14)
                    .shadow(AppShadow.mid())
                    .transition(TransitionEffect.opacity(0).animation({ duration: 300, curve: Curve.EaseOut }))
                    .onClick(() => { AppRouter.goToProductDetail(product.id) })
                  }, (product: Product) => 'h_' + product.id.toString())
                }
              }
              .width('100%').alignItems(HorizontalAlign.Center).padding({ top: 4, bottom: 80 })
            }
            .width('100%').backgroundColor(AppColor.bg()).scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
          }
          .onRefreshing(() => { this.loadData() })
        }
        .layoutWeight(1)

          if (this.currentTab === 0) {
            Column() {
              AppButton({ text: '清空全部收藏', type: AppButtonType.OUTLINE, fontColor: AppColor.CANCEL, buttonWidth: '88%', buttonHeight: 44, buttonOnClick: () => { this.showClearConfirm = true } })
            }
            .width('100%').padding({ top: 8, bottom: 12 }).backgroundColor(AppColor.bg())
          } else {
            Column() {
              AppButton({ text: '清空浏览记录', type: AppButtonType.OUTLINE, fontColor: AppColor.CANCEL, buttonWidth: '88%', buttonHeight: 44, buttonOnClick: () => { this.clearHistory() } })
            }
            .width('100%').padding({ top: 8, bottom: 12 }).backgroundColor(AppColor.bg())
          }
        }
      }
      .width('100%').height('100%')

      if (this.showClearConfirm) {
        Column() {
          Column({ space: 16 }) {
            Text('清空收藏').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            Text('确定要清空全部 ' + this.products.length + ' 件收藏商品吗？').fontSize(14).fontColor(AppColor.textSecondary())
            Row({ space: 12 }) {
              AppButton({ text: '取消', type: AppButtonType.SECONDARY, buttonHeight: 44, buttonOnClick: () => { this.showClearConfirm = false } })
                .layoutWeight(1)
              AppButton({ text: '确认清空', type: AppButtonType.DANGER, buttonHeight: 44, buttonOnClick: () => { this.clearAll() } })
                .layoutWeight(1)
            }
          }
          .width('78%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(20)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
        .onClick(() => { this.showClearConfirm = false })
      }
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn }).opacity(0)
    PageTransitionExit({ duration: 250, curve: Curve.FastOutLinearIn }).opacity(0)
  }
}

@Reusable
@Component
export struct FavoriteItemRow {
  @Prop product: Product = new Product()
  onToggle?: () => void
  onAddToCart?: () => void
  onCardClick?: () => void
  @State showFavIcon: boolean = true

  aboutToReuse(params: Record<string, Object>): void {
    this.showFavIcon = true
    if (params.product !== undefined) {
      this.product = params.product as Product
    }
    if (params.onToggle !== undefined) {
      this.onToggle = params.onToggle as () => void
    }
    if (params.onAddToCart !== undefined) {
      this.onAddToCart = params.onAddToCart as () => void
    }
    if (params.onCardClick !== undefined) {
      this.onCardClick = params.onCardClick as () => void
    }
  }

  build() {
    Row() {
      ProductImage({ src: this.product.image })
        .width(90).height(90).borderRadius(12)
      Column({ space: 5 }) {
        Text(this.product.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.product.description).fontSize(12).fontColor(AppColor.textTertiary())
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Row() {
          Text('¥' + this.product.price).fontSize(22).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
          Blank()
          HeartIcon({ filled: true, iconSize: 22, onToggle: () => { this.onToggle?.() } })
        }.width('100%')
        AppButton({ text: '加入购物车', type: AppButtonType.PRIMARY, fontSize: 12, buttonHeight: 28, buttonOnClick: () => { this.onAddToCart?.() } })
          .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 12 })
    }
    .width('92%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(14)
    .shadow(AppShadow.mid())
    .transition(TransitionEffect.opacity(0).animation({ duration: 300, curve: Curve.EaseOut }))
    .onClick(() => { this.onCardClick?.() })
  }
}
