import { Product } from '../data/model/ProductModel'
import { productRepository } from '../data/repository/ProductRepository'
import { cartViewModel } from '../viewmodel/CartViewModel'
import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { AppRouter } from '../common/AppRouter'

import { AppColor, AppRadius, SortOption, AppContainer } from '../common/StyleConstants'
import { EmptyView } from './StatusViews'
import { AppButton, AppButtonType } from './AppButton'
import { ProductCard } from './ProductCard'

const HOT_WORDS: string[] = ['手机', '电脑', '耳机', '充电器', '蓝牙耳机']

@Component
export struct SearchOverlay {
  onClose?: () => void

  @State keyword: string = ''
  @State products: Product[] = []
  @State sortBy: string = SortOption.DEFAULT
  @State priceMin: string = ''
  @State priceMax: string = ''
  @State rating: string = ''
  @State showFilters: boolean = false
  @State searchHistory: string[] = []
  @State suggestions: string[] = []
  @State hasSearched: boolean = false

  async aboutToAppear(): Promise<void> {
    try {
      this.searchHistory = await sessionViewModel.getSearchHistory()
    } catch {}
  }

  doSearch(): void {
    let min = this.priceMin ? Number(this.priceMin) : 0
    let max = this.priceMax ? Number(this.priceMax) : 0
    this.products = productRepository.search(this.keyword, '全部', this.sortBy, min, max)
    // Apply rating filter client-side (only if products have actual review data)
    if (this.rating !== '') {
      let minRating = Number(this.rating)
      let hasRatingData = this.products.some((p: Product) => p.rating > 0)
      if (hasRatingData) {
        this.products = this.products.filter((p: Product) => p.rating >= minRating)
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '评分数据暂不可用' })
      }
    }
    this.hasSearched = true
    this.suggestions = []
    this.saveHistory()
  }

  async saveHistory(): Promise<void> {
    let t = this.keyword.trim()
    if (t === '') return
    this.searchHistory = this.searchHistory.filter(h => h !== t)
    this.searchHistory.unshift(t)
    if (this.searchHistory.length > 8) this.searchHistory = this.searchHistory.slice(0, 8)
    await sessionViewModel.saveSearchHistory(this.searchHistory)
  }

  async clearHistory(): Promise<void> {
    this.searchHistory = []
    await sessionViewModel.clearSearchHistory()
  }

  searchByTerm(term: string): void {
    this.keyword = term
    let min = this.priceMin ? Number(this.priceMin) : 0
    let max = this.priceMax ? Number(this.priceMax) : 0
    this.products = productRepository.search(term, '全部', this.sortBy, min, max)
    this.hasSearched = true
    this.suggestions = []
    this.saveHistory()
  }

  onKeywordChange(value: string): void {
    this.keyword = value
    if (value.trim() === '') {
      this.suggestions = []
      this.hasSearched = false
      return
    }
    this.suggestions = productRepository.getSuggestions(value)
    this.hasSearched = false
  }

  setSort(option: string): void {
    this.sortBy = option
    if (this.hasSearched) this.doSearch()
  }

  build() {
    Stack() {
      Column() {
        Column() {
          Row() {
            Row() {
              Image($rawfile('ic_search.svg')).width(16).height(16).margin({ left: 14 })
              TextInput({ placeholder: '搜索商品名称...', text: this.keyword })
                .onChange((v: string) => { this.onKeywordChange(v) })
                .onSubmit(() => {
                  let t = this.keyword.trim()
                  if (t.length > 0) { this.doSearch() }
                })
                .height(38).backgroundColor(Color.Transparent).fontSize(14).layoutWeight(1)
                .padding({ left: 6, right: 6 }).enterKeyType(EnterKeyType.Search)
            }
            .height(40).backgroundColor(AppColor.inputBg()).borderRadius(AppRadius.LG).layoutWeight(1)

            Text('取消')
              .fontSize(15).fontColor(AppColor.PRIMARY).margin({ left: 12 })
              .onClick(() => { this.onClose?.() })
          }
          .width(AppContainer.CONTENT_WIDTH).padding({ top: 14, bottom: 8 })
        }
        .backgroundColor(AppColor.bg())

        if (!this.hasSearched && this.keyword.trim() === '') {
          Scroll() {
            this.SearchHistoryContent()
          }
          .width('100%').scrollBar(BarState.Off)
          Blank().layoutWeight(1)
        } else if (!this.hasSearched && this.suggestions.length > 0) {
          Scroll() {
            this.SuggestionsContent()
          }
          .width('100%').scrollBar(BarState.Off)
          Blank().layoutWeight(1)
        }

        if (this.hasSearched) {
          Column() {
            Row({ space: 6 }) {
              Text('综合')
                .fontSize(13)
                .fontColor(this.sortBy === SortOption.DEFAULT ? AppColor.WHITE : AppColor.textSecondary())
                .backgroundColor(this.sortBy === SortOption.DEFAULT ? AppColor.PRIMARY : AppColor.divider())
                .borderRadius(AppRadius.PILL)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .onClick(() => { this.setSort(SortOption.DEFAULT) })
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
              Text('销量')
                .fontSize(13)
                .fontColor(this.sortBy === SortOption.SALES ? AppColor.WHITE : AppColor.textSecondary())
                .backgroundColor(this.sortBy === SortOption.SALES ? AppColor.PRIMARY : AppColor.divider())
                .borderRadius(AppRadius.PILL)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .onClick(() => { this.setSort(SortOption.SALES) })
              Text('筛选')
                .fontSize(13).fontColor(AppColor.PRIMARY).backgroundColor(AppColor.primaryBg())
                .borderRadius(AppRadius.PILL)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .onClick(() => { this.showFilters = true })
                .bindSheet(this.showFilters, this.FilterSheetContent, {
                  height: '60%',
                  backgroundColor: AppColor.cardBg(),
                  dragBar: false,
                  onDisappear: () => { this.showFilters = false }
                })
            }
            .width(AppContainer.CONTENT_WIDTH).padding({ bottom: 8 })
          }
          .padding({ top: 4 })
          .backgroundColor(AppColor.bg())

          if (this.products.length === 0) {
            Column() {
              EmptyView({ message: '未找到匹配的商品' }).layoutWeight(1).width('100%')
              AppButton({ text: '去搜索页查看全部结果', type: AppButtonType.OUTLINE,
                fontColor: AppColor.PRIMARY, buttonWidth: 'auto', buttonHeight: 40, buttonRadius: 20,
                fontSize: 14, fontWeight: FontWeight.Medium,
                buttonOnClick: () => { AppRouter.goToSearchPage(this.keyword) }
              })
                .margin({ bottom: 40 })
            }
            .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else {
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
              }, (product: Product) => 'so_' + product.id.toString())
            }
            .columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).width(AppContainer.CONTENT_WIDTH).layoutWeight(1)
            .scrollBar(BarState.Off).padding({ bottom: 8 })

            AppButton({ text: '查看更多结果 →', type: AppButtonType.OUTLINE,
              fontColor: AppColor.PRIMARY, buttonWidth: AppContainer.CONTENT_WIDTH, buttonHeight: 40, buttonRadius: 20,
              fontSize: 14, fontWeight: FontWeight.Medium,
              buttonOnClick: () => { AppRouter.goToSearchPage(this.keyword) }
            })
              .margin({ bottom: 16 })
          }
        }
      }
      .width('100%').height('100%').backgroundColor(AppColor.bg()).justifyContent(FlexAlign.Start)
    }
    .width('100%').height('100%')
  }

  // ── Filter bottom sheet (matches SearchPage style) ──
  @Builder
  FilterSheetContent() {
    Column({ space: 0 }) {
      // ── Header ──
      Row() {
        Text('筛选').fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary()).layoutWeight(1)
        Stack() {
          Rect().width(16).height(1.8).fill(AppColor.textTertiary()).rotate({ angle: 45 })
          Rect().width(16).height(1.8).fill(AppColor.textTertiary()).rotate({ angle: -45 })
        }.width(24).height(24).onClick(() => { this.showFilters = false })
      }.width('100%').padding({ bottom: 12 })

      Divider().strokeWidth(0.5).color(AppColor.divider())

      Scroll() {
        Column({ space: 0 }) {
          // ── 价格区间 ──
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

          // ── 商品评价 ──
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
        AppButton({ text: '重置', type: AppButtonType.OUTLINE, buttonHeight: 44,
          buttonRadius: AppRadius.BTN, fontSize: 15, buttonOnClick: () => {
            this.priceMin = ''
            this.priceMax = ''
            this.rating = ''
          } })
          .layoutWeight(1)
        AppButton({ text: '确定', type: AppButtonType.PRIMARY, buttonHeight: 44,
          buttonRadius: AppRadius.BTN, fontSize: 15, buttonOnClick: () => {
            this.showFilters = false
            this.doSearch()
          } })
          .layoutWeight(1)
      }
      .width('100%').padding({ top: 12, bottom: 24 })
    }
    .padding(24)
  }

  @Builder
  SearchHistoryContent() {
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
          ForEach(HOT_WORDS, (word: string) => {
            Text(word)
              .fontSize(13).fontColor(AppColor.PRIMARY).backgroundColor(AppColor.primaryBg())
              .borderRadius(AppRadius.PILL).padding({ left: 14, right: 14, top: 5, bottom: 5 })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.searchByTerm(word) })
          }, (word: string) => word)
        }.width('100%')
      }.width('100%')
    }
    .width(AppContainer.CONTENT_WIDTH).padding({ top: 24 })
  }

  @Builder
  SuggestionsContent() {
    Column() {
      ForEach(this.suggestions, (s: string) => {
          Row() {
            Image($rawfile('ic_search.svg')).width(14).height(14).margin({ right: 8 })
            Text(s).fontSize(14).fontColor(AppColor.textPrimary())
          Blank()
          Text('搜索').fontSize(12).fontColor(AppColor.PRIMARY)
        }
        .width('100%').padding({ left: 4, right: 4, top: 12, bottom: 12 })
        .borderRadius(8)
        .onClick(() => { this.searchByTerm(s) })
      }, (s: string) => s)
    }
    .width(AppContainer.CONTENT_WIDTH).padding({ top: 24 })
  }
}
