import { Product } from '../data/model/ProductModel'
import { productRepository } from '../data/repository/ProductRepository'
import { cartViewModel } from '../viewmodel/CartViewModel'
import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { AppRouter, SearchPageParams } from '../common/AppRouter'
import { AppColor, AppRadius, AppContainer, SortOption } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppInput } from '../components/AppInput'
import { EmptyView, LoadingView } from '../components/StatusViews'
import { ProductCard } from '../components/ProductCard'
import { Logger } from '../common/Logger'

@Component
struct SearchHistoryPanelComponent {
  searchHistory: string[] = []
  clearHistory: () => void = () => {}
  searchByTerm: (term: string) => void = (t: string) => {}

  build() {
    Column({ space: 12 }) {
      Scroll() {
        Column({ space: 12 }) {
          if (this.searchHistory.length > 0) {
            Column({ space: 8 }) {
              Row() {
                Text('搜索历史').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary()).layoutWeight(1)
                Text('清空').fontSize(13).fontColor(AppColor.PRIMARY)
                  .onClick(() => { this.clearHistory() })
              }.width('100%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.searchHistory, (term: string) => {
                  Text(term)
                    .fontSize(13).fontColor(AppColor.textSecondary()).backgroundColor(AppColor.inputBg())
                    .borderRadius(AppRadius.PILL).padding({ left: 14, right: 14, top: 5, bottom: 5 })
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => { this.searchByTerm(term) })
                }, (term: string) => term)
              }.width('100%')
            }.width('100%')
          }

          Column({ space: 8 }) {
            Text('热门搜索').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary()).width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(['手机', '电脑', '耳机', '充电器', '蓝牙耳机'], (word: string) => {
                Text(word)
                  .fontSize(13).fontColor(AppColor.PRIMARY).backgroundColor(AppColor.primaryBg())
                  .borderRadius(AppRadius.PILL).padding({ left: 14, right: 14, top: 5, bottom: 5 })
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => { this.searchByTerm(word) })
              }, (word: string) => word)
            }.width('100%')
          }.width('100%')
        }
        .width('100%').padding({ bottom: 8 })
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }
    .layoutWeight(1).width(AppContainer.WIDTH).padding({ top: 24 })
  }
}

@Entry
@Component
struct SearchPage {
  params: SearchPageParams = new SearchPageParams()
  @State keyword: string = ''
  @State category: string = ''
  @State products: Product[] = []
  @State sortBy: string = SortOption.DEFAULT
  @State priceMin: string = ''
  @State priceMax: string = ''
  @State showFilters: boolean = false
  @State searchHistory: string[] = []
  @State isLoading: boolean = false
  @State totalResults: number = 0
  @State currentPage: number = 1
  @State hasMore: boolean = false
  @State showCategoryPicker: boolean = false
  @State pickerParent: string = ''
  @State rating: string = ''

  private pickerIcon(cat: string): string {
    const MAP: Record<string, string> = {
      '手机': 'ic_cat_phone.svg', '电脑': 'ic_cat_computer.svg', '配件': 'ic_cat_accessory.svg',
      '家电': 'ic_cat_appliance.svg', '生活': 'ic_cat_lifestyle.svg', '服装': 'ic_cat_clothing.svg', '美妆': 'ic_cat_beauty.svg'
    }
    return MAP[cat] || 'ic_box.svg'
  }

  async aboutToAppear(): Promise<void> {
    let routerP = AppRouter.getParams<SearchPageParams>()
    if (routerP) this.params = routerP
    try {
      this.searchHistory = await sessionViewModel.getSearchHistory()
    } catch (err) { Logger.error('获取搜索历史失败: {0}', (err as Error).message) }
    let params = this.params
    if (params) {
      if (params.keyword) this.keyword = params.keyword
      if (params.category) this.category = params.category
      await this.doSearch()
    }
  }

  async doSearch(append: boolean = false): Promise<void> {
    this.isLoading = true
    try {
      let min = this.priceMin ? Number(this.priceMin) : 0
      let max = this.priceMax ? Number(this.priceMax) : 0
      let page = append ? this.currentPage + 1 : 1
      if (!append) { this.products = [] }
      let result = await productRepository.searchServer(this.keyword, this.sortBy, min, max, page, 20, this.category)
      let items = result.items || []
      // Apply rating filter client-side (only if products have actual review data)
      if (this.rating !== '') {
        let minRating = Number(this.rating)
        let hasRatingData = items.some((p: Product) => p.rating > 0)
        if (hasRatingData) {
          items = items.filter((p: Product) => p.rating >= minRating)
        } else {
          this.getUIContext().getPromptAction().showToast({ message: '评分数据暂不可用' })
        }
      }
      if (append) {
        this.products = this.products.concat(items)
      } else {
        this.products = items
      }
      this.totalResults = result.total || items.length
      this.currentPage = page
      this.hasMore = this.products.length < (result.total || 0)
    } catch (err) {
      this.totalResults = 0
      this.hasMore = false
    }
    this.isLoading = false
  }

  async saveHistory(term: string): Promise<void> {
    this.searchHistory = this.searchHistory.filter(h => h !== term)
    this.searchHistory.unshift(term)
    if (this.searchHistory.length > 8) this.searchHistory = this.searchHistory.slice(0, 8)
    await sessionViewModel.saveSearchHistory(this.searchHistory)
  }

  async clearHistory(): Promise<void> {
    this.searchHistory = []
    await sessionViewModel.clearSearchHistory()
  }

  async searchByTerm(term: string): Promise<void> {
    this.keyword = term
    this.category = ''
    this.showCategoryPicker = false
    this.pickerParent = ''
    await this.saveHistory(term)
    await this.doSearch()
  }

  async selectCategory(cat: string): Promise<void> {
    this.category = cat
    this.showCategoryPicker = false
    this.pickerParent = ''
    await this.doSearch()
  }

  async clearCategory(): Promise<void> {
    this.category = ''
    this.showCategoryPicker = false
    this.pickerParent = ''
    await this.doSearch()
  }

  currentParent(): string {
    if (!this.category) return ''
    const idx = this.category.indexOf('>')
    return idx !== -1 ? this.category.substring(0, idx) : this.category
  }

  childFullCategory(child: string): string {
    // Use pickerParent (the parent currently selected in the picker UI),
    // NOT currentParent() which reads from this.category.
    // When this.category is empty (e.g., opened SearchPage without a preset category),
    // currentParent() returns '' producing ">child" — which matches nothing.
    return this.pickerParent + '>' + child
  }

  async setSort(option: string): Promise<void> {
    this.sortBy = option
    this.showFilters = false
    await this.doSearch()
  }

  async applyPriceFilter(): Promise<void> {
    this.showFilters = false
    await this.doSearch()
  }

  // ── Category sheet: left-right split (bindSheet) ──
  @Builder
  CategorySheetContent() {
    Column({ space: 0 }) {
      // ── Header ──
      Row() {
        Text('商品分类').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
        Blank()
        Row() {
          Text('×')
            .fontSize(20)
            .fontColor(AppColor.textTertiary())
        }
        .width(28).height(28)
        .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.pickerParent = ''
          this.showCategoryPicker = false
        })
      }
      .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 12 })

      Divider().strokeWidth(0.5).color(AppColor.divider())

      // ── Left-Right split body ──
      Row({ space: 0 }) {
        // ── LEFT: parent categories + "全部" ──
        Column() {
          Scroll() {
            Column({ space: 0 }) {
              // "全部"
              Row() {
                Text('全部').fontSize(14)
                  .fontColor(!this.category ? AppColor.PRIMARY : AppColor.textPrimary())
                  .fontWeight(!this.category ? FontWeight.Medium : FontWeight.Regular)
                Blank()
                if (!this.category) {
                  Text('当前').fontSize(10).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Medium)
                }
              }
              .width('100%').height(44).padding({ left: 16, right: 16 })
              .backgroundColor(!this.category ? AppColor.primaryBg() : Color.Transparent)
              .onClick(() => {
                this.pickerParent = ''
                this.clearCategory()
                this.showCategoryPicker = false
              })

              // Parent categories — highlight only by actual selection (currentParent)
              ForEach(productRepository.getParentCategories(), (cat: string) => {
                Row() {
                  Text(cat).fontSize(14)
                    .fontColor(this.currentParent() === cat ? AppColor.PRIMARY : AppColor.textPrimary())
                    .fontWeight(this.currentParent() === cat ? FontWeight.Medium : FontWeight.Regular)
                  Blank()
                  if (this.currentParent() === cat) {
                    Text('当前').fontSize(10).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Medium)
                  }
                }
                .width('100%').height(44).padding({ left: 16, right: 16 })
                .backgroundColor(this.currentParent() === cat ? AppColor.primaryBg() : Color.Transparent)
                .onClick(() => {
                  const children = productRepository.getChildren(cat)
                  if (children.length > 0) {
                    this.pickerParent = cat
                  } else {
                    this.pickerParent = ''
                    this.selectCategory(cat)
                    this.showCategoryPicker = false
                  }
                })
              }, (cat: string) => cat)
            }
            .width('100%')
          }
          .layoutWeight(1).width('100%').scrollBar(BarState.Off)
        }
        .width('35%').backgroundColor(AppColor.inputBg())

        // ── Divider ──
        Column().width(1).height('100%').backgroundColor(AppColor.divider())

        // ── RIGHT: parent category (selectable) + subcategories ──
        Column() {
          if (this.pickerParent !== '' && productRepository.getChildren(this.pickerParent).length > 0) {
            Scroll() {
              Column({ space: 0 }) {
                // ── 大类本身（可选）─
                Row() {
                  Row() {
                    Text(this.pickerParent + '（全部）').fontSize(14)
                      .fontColor(this.category === this.pickerParent ? AppColor.WHITE : AppColor.PRIMARY)
                      .fontWeight(FontWeight.Medium)
                  }
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .backgroundColor(this.category === this.pickerParent ? AppColor.PRIMARY : AppColor.primaryBg())
                  .borderRadius(AppRadius.PILL)
                  .layoutWeight(1)

                  if (this.category === this.pickerParent) {
                    Text('✓').fontSize(12).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                  }
                }
                .width('100%').height(44).padding({ left: 16, right: 16 })
                .backgroundColor(this.category === this.pickerParent ? AppColor.primaryBg() : Color.Transparent)
                .borderRadius(AppRadius.SM)
                .onClick(() => {
                  this.selectCategory(this.pickerParent)
                  this.showCategoryPicker = false
                })

                // ── 子分类列表 ──
                ForEach(productRepository.getChildren(this.pickerParent), (child: string) => {
                  Row() {
                    Column() {
                      Text(child).fontSize(14)
                        .fontColor(this.category === this.childFullCategory(child) ? AppColor.PRIMARY : AppColor.textPrimary())
                        .fontWeight(this.category === this.childFullCategory(child) ? FontWeight.Medium : FontWeight.Regular)
                    }
                    .layoutWeight(1)

                    if (this.category === this.childFullCategory(child)) {
                      Row({ space: 4 }) {
                        Circle().width(18).height(18).fill(AppColor.PRIMARY)
                        Text('✓').fontSize(10).fontColor(AppColor.WHITE)
                      }
                      .width(18).height(18).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
                    }
                  }
                  .width('100%').height(44).padding({ left: 16, right: 16 })
                  .backgroundColor(this.category === this.childFullCategory(child) ? AppColor.primaryBg() : Color.Transparent)
                  .borderRadius(AppRadius.SM)
                  .onClick(() => {
                    this.selectCategory(this.childFullCategory(child))
                    this.showCategoryPicker = false
                  })
                }, (child: string) => child)
              }
              .width('100%')
            }
            .layoutWeight(1).width('100%').scrollBar(BarState.Off)
          } else {
            // Empty state
            Column() {
              Text(this.pickerParent !== '' ? '暂无子分类' : '请选择左侧分类')
                .fontSize(13).fontColor(AppColor.textTertiary())
            }
            .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          }
        }
        .width('65%')
      }
      .layoutWeight(1).width('100%')

      // ── Bottom bar ──
      Divider().strokeWidth(0.5).color(AppColor.divider())
      Row({ space: 12 }) {
        AppButton({ text: '重置', type: AppButtonType.OUTLINE,
          buttonHeight: 44, buttonRadius: AppRadius.BTN, fontSize: 15,
          buttonOnClick: () => {
            this.pickerParent = ''
            this.clearCategory()
          } })
          .layoutWeight(1)
        AppButton({ text: '确定', type: AppButtonType.PRIMARY,
          buttonHeight: 44, buttonRadius: AppRadius.BTN, fontSize: 15,
          buttonOnClick: () => {
            this.showCategoryPicker = false
          } })
          .layoutWeight(1)
      }
      .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 30 })
    }
    .width('100%')
  }

  // ── Filter bottom sheet (bindSheet) ──
  @Builder
  FilterSheetContent() {
    Column({ space: 0 }) {
      // ── Header ──
      Row() {
        Text('筛选').fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary()).layoutWeight(1)
        // Custom X icon using rotated Rects (avoids font rendering ghosting)
        Stack() {
          Rect().width(16).height(1.8).fill(AppColor.textTertiary()).rotate({ angle: 45 })
          Rect().width(16).height(1.8).fill(AppColor.textTertiary()).rotate({ angle: -45 })
        }.width(24).height(24).onClick(() => { this.showFilters = false })
      }.width('100%').padding({ bottom: 12 })

      Divider().strokeWidth(0.5).color(AppColor.divider())

      Scroll() {
        Column({ space: 0 }) {
          // ── 1. 价格区间 ──
          Text('价格区间').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
            .padding({ top: 16, bottom: 10 })
          Row({ space: 8 }) {
            TextInput({ placeholder: '最低价', text: this.priceMin })
              .onChange((v: string) => { this.priceMin = v })
              .type(InputType.Number).height(40).fontSize(14)
              .backgroundColor(AppColor.inputBg()).borderRadius(AppRadius.SM)
              .padding({ left: 12 }).layoutWeight(1)
            Text('—').fontSize(14).fontColor(AppColor.textTertiary())
            TextInput({ placeholder: '最高价', text: this.priceMax })
              .onChange((v: string) => { this.priceMax = v })
              .type(InputType.Number).height(40).fontSize(14)
              .backgroundColor(AppColor.inputBg()).borderRadius(AppRadius.SM)
              .padding({ left: 12 }).layoutWeight(1)
          }.width('100%')

          Divider().strokeWidth(0.5).color(AppColor.divider()).margin({ top: 12, bottom: 4 })

          // ── 3. 商品评价 ──
          Text('商品评价').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
            .padding({ top: 16, bottom: 10 })
          Flex({ wrap: FlexWrap.Wrap }) {
            Text('全部')
              .fontSize(13)
              .fontColor(this.rating === '' ? AppColor.WHITE : AppColor.textSecondary())
              .backgroundColor(this.rating === '' ? AppColor.PRIMARY : AppColor.inputBg())
              .borderRadius(AppRadius.PILL)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.rating = '' })
            Text('3星及以上')
              .fontSize(13)
              .fontColor(this.rating === '3' ? AppColor.WHITE : AppColor.textSecondary())
              .backgroundColor(this.rating === '3' ? AppColor.PRIMARY : AppColor.inputBg())
              .borderRadius(AppRadius.PILL)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.rating = '3' })
            Text('4星及以上')
              .fontSize(13)
              .fontColor(this.rating === '4' ? AppColor.WHITE : AppColor.textSecondary())
              .backgroundColor(this.rating === '4' ? AppColor.PRIMARY : AppColor.inputBg())
              .borderRadius(AppRadius.PILL)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.rating = '4' })
            Text('仅好评')
              .fontSize(13)
              .fontColor(this.rating === '4.5' ? AppColor.WHITE : AppColor.textSecondary())
              .backgroundColor(this.rating === '4.5' ? AppColor.PRIMARY : AppColor.inputBg())
              .borderRadius(AppRadius.PILL)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.rating = '4.5' })
          }.width('100%')
        }
        .width('100%').padding({ bottom: 16 })
      }
      .scrollable(ScrollDirection.Vertical).scrollBar(BarState.Off)

      // ── Bottom buttons ──
      Divider().strokeWidth(0.5).color(AppColor.divider())
      Row({ space: 12 }) {
        AppButton({ text: '重置', type: AppButtonType.OUTLINE, buttonHeight: 48,
          buttonRadius: AppRadius.BTN, fontSize: 15, buttonOnClick: () => {
            this.priceMin = ''
            this.priceMax = ''
            this.rating = ''
          } })
          .layoutWeight(1)
        AppButton({ text: '确定', type: AppButtonType.PRIMARY, buttonHeight: 48,
          buttonRadius: AppRadius.BTN, fontSize: 15, buttonOnClick: () => {
            this.showFilters = false
            if (this.pickerParent !== '') { this.pickerParent = '' }
            this.doSearch()
          } })
          .layoutWeight(1)
      }
      .width('100%').padding({ top: 12, bottom: 24 })
    }
    .padding(24)
  }

  build() {
    Column() {
      // Row 1: Search bar
      Row() {
        Row() {
          Image($rawfile('ic_search.svg')).width(16).height(16).margin({ left: 14 })
          TextInput({ placeholder: '搜索商品名称...', text: this.keyword })
            .onChange((v: string) => { this.keyword = v })
            .onSubmit(async () => {
              let t = this.keyword.trim()
              if (t.length > 0) { await this.searchByTerm(t) }
            })
            .height(38).backgroundColor(Color.Transparent).fontSize(14).layoutWeight(1)
            .padding({ left: 6, right: 6 })
        }
        .height(40).backgroundColor(AppColor.inputBg()).borderRadius(AppRadius.LG).layoutWeight(1)

        Text('取消')
          .fontSize(15).fontColor(AppColor.PRIMARY).margin({ left: 12 })
          .onClick(() => { AppRouter.back() })
      }
      .width(AppContainer.WIDTH).padding({ top: 14, bottom: 6 })

      // Row 2: Compact sort bar (JD/Taobao style)
      Row({ space: 6 }) {
        // [全部▾] — dropdown category selector
        Row({ space: 4 }) {
          Text(this.category ? this.currentParent() : '全部')
            .fontSize(13)
            .fontColor(this.category ? AppColor.PRIMARY : AppColor.textPrimary())
            .fontWeight(this.category ? FontWeight.Medium : FontWeight.Regular)
          Text('▾')
            .fontSize(9)
            .fontColor(this.category ? AppColor.PRIMARY : AppColor.textTertiary())
            .margin({ top: 1 })
        }
        .borderRadius(AppRadius.PILL)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(this.category ? AppColor.primaryBg() : AppColor.inputBg())
        .border({ width: 1, color: this.category ? AppColor.PRIMARY : AppColor.border() })
        .onClick(() => {
          // always reset, then init from current category
          this.pickerParent = this.category ? this.currentParent() : ''
          this.showCategoryPicker = true
        })
        .bindSheet($$this.showCategoryPicker, this.CategorySheetContent(), {
          height: '55%',
          backgroundColor: AppColor.cardBg(),
          dragBar: false,
          onDisappear: () => {
            this.pickerParent = ''
            this.showCategoryPicker = false
          }
        })

        // [综合]
        Text('综合')
          .fontSize(13)
          .fontColor(this.sortBy === SortOption.DEFAULT ? AppColor.WHITE : AppColor.textSecondary())
          .backgroundColor(this.sortBy === SortOption.DEFAULT ? AppColor.PRIMARY : AppColor.divider())
          .borderRadius(AppRadius.PILL)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .onClick(() => { this.setSort(SortOption.DEFAULT) })

        // [价格↑] or [价格↓] — toggle asc/desc
        Text(this.sortBy === SortOption.PRICE_DESC ? '价格↓' : '价格↑')
          .fontSize(13)
          .fontColor(this.sortBy === SortOption.PRICE_ASC || this.sortBy === SortOption.PRICE_DESC ? AppColor.WHITE : AppColor.textSecondary())
          .backgroundColor(this.sortBy === SortOption.PRICE_ASC || this.sortBy === SortOption.PRICE_DESC ? AppColor.PRIMARY : AppColor.divider())
          .borderRadius(AppRadius.PILL)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .onClick(() => {
            if (this.sortBy === SortOption.PRICE_ASC) {
              this.setSort(SortOption.PRICE_DESC)
            } else {
              this.setSort(SortOption.PRICE_ASC)
            }
          })

        // [销量]
        Text('销量')
          .fontSize(13)
          .fontColor(this.sortBy === SortOption.SALES ? AppColor.WHITE : AppColor.textSecondary())
          .backgroundColor(this.sortBy === SortOption.SALES ? AppColor.PRIMARY : AppColor.divider())
          .borderRadius(AppRadius.PILL)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .onClick(() => { this.setSort(SortOption.SALES) })

        // [筛选]
        Text('筛选')
          .fontSize(13)
          .fontColor(AppColor.PRIMARY)
          .backgroundColor(AppColor.primaryBg())
          .borderRadius(AppRadius.PILL)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .onClick(() => { this.showFilters = true })
          .bindSheet(this.showFilters, this.FilterSheetContent, {
            height: '70%',
            backgroundColor: AppColor.cardBg(),
            dragBar: false,
            onDisappear: () => { this.showFilters = false }
          })
      }
      .width(AppContainer.WIDTH).padding({ bottom: 8 })

      // Thin divider below header
      Divider().strokeWidth(0.5).color(AppColor.divider())

      // Content area
      if (this.isLoading) {
        LoadingView({ message: '搜索中...' }).layoutWeight(1).width('100%')
      } else if (!this.keyword && !this.category && this.products.length === 0) {
        SearchHistoryPanelComponent({ searchHistory: this.searchHistory, clearHistory: () => { this.clearHistory() }, searchByTerm: (term: string) => { this.searchByTerm(term) } })
      } else if (this.products.length === 0) {
        Column() {
          EmptyView({ message: '未找到匹配的商品', icon: $rawfile('ic_search.svg') })
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        // Product grid with infinite scroll (no "加载更多" button)
        Grid() {
          ForEach(this.products, (product: Product) => {
            GridItem() {
              ProductCard({
                product: product,
                onAddToCart: () => {
                  if (product.hasSKU() && product.skus.length > 0 && product.skus[0].stock <= 0) {
                    this.getUIContext().getPromptAction().showToast({ message: '该商品已售罄' })
                    return
                  }
                  cartViewModel.addToCart(product).then(() => {
                    this.getUIContext().getPromptAction().showToast({ message: '已加入购物车' })
                  }).catch((e: Error) => {
                    this.getUIContext().getPromptAction().showToast({ message: e.message || '添加失败' })
                  })
                },
                onBuyNow: () => {
                  AppRouter.goToProductDetail(product.id)
                },
                onCardClick: () => { AppRouter.goToProductDetail(product.id) }
              })
            }
          }, (product: Product) => 'search_' + product.id.toString())
        }
        .columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).width(AppContainer.WIDTH)
        .layoutWeight(1).scrollBar(BarState.Off).padding({ bottom: 16 })
        .onScrollIndex((first: number, last: number) => {
          if (last >= this.products.length - 3 && this.hasMore && !this.isLoading) {
            this.doSearch(true)
          }
        })
      }
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
      .slide(SlideEffect.Top)
    PageTransitionExit({ duration: 250, curve: Curve.FastOutLinearIn })
      .slide(SlideEffect.Top)
  }
}

