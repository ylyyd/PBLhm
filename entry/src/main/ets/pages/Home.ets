import { Product } from '../data/model/ProductModel'
import { productRepository } from '../data/repository/ProductRepository'
import { cartViewModel } from '../viewmodel/CartViewModel'
import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { AppRouter } from '../common/AppRouter'
import { AppConstants } from '../common/Constants'

import { EmptyView } from '../components/StatusViews'
import { SearchOverlay } from '../components/SearchOverlay'
import { ProductCard } from '../components/ProductCard'
import { ProductDataSource } from '../data/ProductDataSource'
import { AppColor, SortOption, AppContainer, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppConfig } from '../common/Config'
import { TabPage } from '../components/BottomTab'
import { Logger } from '../common/Logger'

const HOT_WORDS: string[] = ['手机', '电脑', '耳机', '鼠标', '键盘', '充电器', '蓝牙耳机', '数据线']
const BANNER_IMAGES: string[] = ['mi14ultra_1.png', 'mate60pro_1.png', 'macbookair_1.png']
const SORT_OPTIONS: string[] = [SortOption.DEFAULT, SortOption.PRICE_ASC, SortOption.PRICE_DESC, SortOption.SALES]
const DEFAULT_CATEGORIES: string[] = ['手机', '电脑', '配件', '家电', '生活', '服装', '美妆', '食品', '图书', '运动']

@Component
struct ShimmerBlock {
  @Prop w: string = '100%'
  @Prop h: string = '20px'
  @Prop r: string = '8px'
  @State shimmerOpacity: number = 0.3
  private shimmerTimer: number = -1

  aboutToAppear(): void {
    this.startShimmer()
  }

  aboutToReuse(): void {
    this.startShimmer()
  }

  startShimmer(): void {
    this.shimmerTimer = setTimeout(() => {
      this.shimmerOpacity = 0.3
    this.getUIContext().animateTo({ duration: 600, curve: Curve.EaseInOut }, () => {
      this.shimmerOpacity = 0.7
    })
    }, 0)
  }

  build() {
    Column()
      .width(this.w).height(this.h).borderRadius(this.r)
      .backgroundColor(AppColor.textDisabledLight()).opacity(this.shimmerOpacity)
  }
}

@Component
struct BodySkeleton {
  build() {
    Column() {
      ShimmerBlock({ w: '92%', h: '160px', r: '14px' }).margin({ top: 10, bottom: 4 })
      ShimmerBlock({ w: '92%', h: '22px', r: '6px' }).margin({ top: 8, bottom: 10 })
      Grid() {
        ForEach([1, 2, 3, 4], (i: number) => {
          GridItem() {
            Column() {
              ShimmerBlock({ w: '100%', h: '150px', r: '14px' })
              Column({ space: 6 }) {
                ShimmerBlock({ w: '80%', h: '16px', r: '4px' })
                ShimmerBlock({ w: '60%', h: '12px', r: '4px' })
                ShimmerBlock({ w: '40%', h: '24px', r: '4px' })
                Row({ space: 6 }) {
                  ShimmerBlock({ w: '48%', h: '30px', r: '15px' })
                  ShimmerBlock({ w: '48%', h: '30px', r: '15px' })
                }.width('100%')
              }.padding(12).alignItems(HorizontalAlign.Start)
            }
            .borderRadius(AppRadius.MD).backgroundColor(AppColor.cardBg())
          }
        }, (i: number) => i.toString())
      }
      .columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).width(AppContainer.WIDTH)
    }
    .width('100%').alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct HomeContent {
  switchTab?: (tab: TabPage) => void
  onCartChange?: () => void
  onFlyToCart?: (image: string, x: number, y: number) => void
  @State products: Product[] = []
  private productDataSource: ProductDataSource = new ProductDataSource()
  @State searchText: string = ''
  @State searchHistory: string[] = []
  @State currentBanner: number = 0
  @State avatarColor: string = AppColor.PRIMARY
  @State avatarLetter: string = ''
  @State avatarPath: string = ''
  @State avatarLoadError: boolean = false
  @State showSkeleton: boolean = true
  @State skOverlayOpacity: number = 1.0
  @State showSearch: boolean = false
  @State bannerLoadErrors: boolean[] = [false, false, false]
  @State categoryList: string[] = []
  private pendingFlyX: number = 0
  private pendingFlyY: number = 0

  async aboutToAppear(): Promise<void> {
    await productRepository.load()
    this.products = productRepository.getAll()
    this.productDataSource.setData(this.products)
    this.updateAvatar()
    try {
      this.searchHistory = await sessionViewModel.getSearchHistory()
    } catch (err) {
      Logger.error('Home.aboutToAppear searchHistory failed: {0}', err)
    }
    // Load dynamic categories
    let parents = productRepository.getParentCategories()
    this.categoryList = parents.length > 0 ? parents : DEFAULT_CATEGORIES
    this.getUIContext()?.animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.skOverlayOpacity = 0.0
    })
    setTimeout(() => {
      this.showSkeleton = false
    }, 250)
  }

  updateAvatar(): void {
    let user = sessionViewModel.currentUser
    if (user) {
      this.avatarColor = user.avatarColor
      this.avatarLetter = user.username.charAt(0).toUpperCase()
      this.avatarPath = user.avatarPath
      this.avatarLoadError = false
    } else {
      this.avatarColor = AppColor.PRIMARY
      this.avatarLetter = '?'
      this.avatarPath = ''
      this.avatarLoadError = false
    }
  }

  searchByTerm(term: string): void {
    AppRouter.goToSearchPage(term)
  }

  handleAddToCart(product: Product): void {
    if (product.hasSKU() && product.skus.length > 0 && product.skus[0].stock <= 0) {
      this.getUIContext().getPromptAction().showToast({ message: '该商品已售罄' })
      return
    }
    cartViewModel.addToCart(product).then(() => {
      this.onCartChange?.()
      this.onFlyToCart?.(product.image, this.pendingFlyX, this.pendingFlyY)
    }).catch((e: Error) => {
      this.getUIContext().getPromptAction().showToast({ message: e.message || '添加失败' })
    })
  }

  private getBannerSrc(img: string): ResourceStr {
    let idx = BANNER_IMAGES.indexOf(img)
    if (this.bannerLoadErrors[idx]) {
      return $rawfile(img)
    }
    return AppConfig.API_BASE_URL + '/uploads/banners/' + img
  }

  private onBannerError(img: string): void {
    let idx = BANNER_IMAGES.indexOf(img)
    if (idx >= 0) {
      this.bannerLoadErrors[idx] = true
    }
  }

  private getCategoryIcon(cat: string): string {
    const MAP: Record<string, string> = {
      '手机': 'ic_cat_phone.svg', '电脑': 'ic_cat_computer.svg', '配件': 'ic_cat_accessory.svg',
      '家电': 'ic_cat_appliance.svg', '生活': 'ic_cat_lifestyle.svg', '服装': 'ic_cat_clothing.svg',
      '美妆': 'ic_cat_beauty.svg', '食品': 'ic_cat_food.svg', '图书': 'ic_cat_book.svg',
      '运动': 'ic_cat_sport.svg', '母婴': 'ic_cat_baby.svg', '宠物': 'ic_cat_pet.svg',
      '家装': 'ic_cat_home.svg', '汽车': 'ic_cat_car.svg', '医药': 'ic_cat_medicine.svg'
    }
    return MAP[cat] || 'ic_box.svg'
  }

  handleBuyNow(product: Product): void {
    AppRouter.goToProductDetail(product.id)
  }

  build() {
    Stack() {
      Column() {
        // ── Header: Logo + Search Bar + Avatar ──
        Row({ space: 8 }) {
          // Logo + App Name
          Row({ space: 6 }) {
            Image($r('app.media.app_icon')).width(28).height(28).borderRadius(14)
            Text(AppConstants.APP_NAME)
              .fontSize(17).fontWeight(FontWeight.Bold).fontColor(AppColor.PRIMARY)
          }
          .alignItems(VerticalAlign.Center)

          // Search bar (tappable, opens overlay)
          Row() {
            Image($rawfile('ic_search.svg')).width(16).height(16).margin({ left: 12 })
            Text('  搜索商品...').fontSize(14).fontColor(AppColor.textTertiary())
            Blank()
          }
          .height(38).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.PILL)
          .layoutWeight(1)
          .shadow(AppShadow.mid())
          .onClick(() => { this.showSearch = true })

          // Avatar
          Stack() {
            if (this.avatarPath !== '' && !this.avatarLoadError) {
              Circle().width(34).height(34).fill(AppColor.primaryBg())
              Image('file://' + this.avatarPath)
                .width(34).height(34).borderRadius(AppRadius.CIRCLE)
                .onError(() => { this.avatarLoadError = true })
            } else {
              Circle().width(34).height(34).fill(AppColor.primaryBg())
              Text(this.avatarLetter).fontSize(14).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
            }
          }
          .width(34).height(34)
          .onClick(() => { this.switchTab?.(TabPage.PROFILE) })
        }
        .width(AppContainer.WIDTH).padding({ top: 12, bottom: 8 })

        // ── Banner Swiper (card-style) ──
        Column() {
          Swiper() {
            ForEach(BANNER_IMAGES, (img: string) => {
              Stack() {
                Image(this.getBannerSrc(img))
                  .width('100%').height(155)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(AppRadius.MD)
                  .onError(() => {
                    this.onBannerError(img)
                  })
              }
              .borderRadius(AppRadius.MD)
              .clip(true)
              .width('100%')
            }, (img: string) => img)
          }
          .loop(true)
          .autoPlay(true)
          .interval(4000)
          .indicator(new DotIndicator()
            .color(AppColor.textTertiary())
            .selectedColor(AppColor.PRIMARY)
            .itemWidth(6)
            .selectedItemWidth(16))
          .width('100%').height(165)
        }
        .width(AppContainer.WIDTH).padding(12)
        .backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        .shadow(AppShadow.mid())
        .margin({ top: 6 })

        // ── Categories (热门分类) ──
        Column() {
          Row() {
            Text('热门分类').fontSize(16).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            Blank()
            Row({ space: 4 }) {
              Text('查看更多').fontSize(12).fontColor(AppColor.PRIMARY)
              Image($rawfile('ic_chevron_right_primary.svg')).width(12).height(12)
            }
            .onClick(() => { AppRouter.goToSearchPage('') })
          }
          .width(AppContainer.WIDTH).padding({ left: 4, right: 4, bottom: 12 })

          // ── Categories — circle icons in scroll strip ──
          Scroll() {
            Row({ space: 16 }) {
              ForEach(this.categoryList, (cat: string) => {
                Column({ space: 8 }) {
                  Stack() {
                    Image($rawfile(this.getCategoryIcon(cat))).width(32).height(32)
                  }
                  Text(cat).fontSize(11).fontColor(AppColor.textSecondary()).fontWeight(FontWeight.Medium)
                    .lineHeight(14).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width(64).alignItems(HorizontalAlign.Center)
                .onClick(() => { AppRouter.goToSearchPage('', cat) })
              })
            }
            .padding({ left: 12, right: 12 })
          }
          .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          .width(AppContainer.WIDTH)
        }
        .width(AppContainer.WIDTH).margin({ top: 4, bottom: 8 })

        // ── Product Grid ──
        if (this.showSkeleton) {
          BodySkeleton()
            .layoutWeight(1).width(AppContainer.WIDTH)
            .opacity(this.skOverlayOpacity)
            .animation({ duration: 200 })
        } else if (this.products.length === 0) {
          EmptyView({ message: '未找到匹配的商品', icon: $rawfile('ic_search.svg') })
        } else {
          Grid() {
            LazyForEach(this.productDataSource, (product: Product) => {
              GridItem() {
                ProductCard({
                  product: product,
                  onAddToCart: () => { this.handleAddToCart(product) },
                  onBuyNow: () => { this.handleBuyNow(product) },
                  onCardClick: () => { AppRouter.goToProductDetail(product.id) },
                  onFlyFrom: (x: number, y: number) => {
                    this.pendingFlyX = x
                    this.pendingFlyY = y
                  }
                })
              }
            }, (product: Product) => product.id.toString())
          }
          .columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).width(AppContainer.WIDTH).layoutWeight(1)
          .cachedCount(4).scrollBar(BarState.Off)
        }
      }
      .layoutWeight(1).width('100%')

      if (this.showSearch) {
        SearchOverlay({
          onClose: () => { this.showSearch = false }
        })
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
