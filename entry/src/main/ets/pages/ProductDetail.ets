import { Product, SKU } from '../data/model/ProductModel'
import { productRepository } from '../data/repository/ProductRepository'
import { browseHistoryRepository } from '../data/repository/BrowseHistoryRepository'
import { favoriteRepository } from '../data/repository/FavoriteRepository'
import { cartViewModel } from '../viewmodel/CartViewModel'
import { AppRouter, ProductDetailParams } from '../common/AppRouter'

import { AppColor, AppRadius, AppContainer } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { HeaderComponent } from '../components/HeaderComponent'
import { ProductImage } from '../components/ProductImage'
import { LoadingSkeleton } from '../components/LoadingSkeleton'
import { ProductActionBar } from '../components/ProductActionBar'
import { ProductInfoSection } from '../components/ProductInfoSection'
import { ProductReviewList } from '../components/ProductReviewList'
import { ProductImagePreview } from '../components/ProductImagePreview'
import { SkuBottomSheet } from '../components/SkuBottomSheet'

@Entry
@Component
struct ProductDetail {
  params: ProductDetailParams = new ProductDetailParams()
  @StorageLink('themeMode') themeMode: number = 0
  @State product: Product | null = null
  @State isLoading: boolean = true
  @State refreshCount: number = 0
  @State pinchScale: number = 1
  @State flyImage: string = ''
  @State flyShow: boolean = false
  @State flyX: number = 0
  @State flyY: number = 0
  @State flyW: number = 60
  @State flyH: number = 60
  @State flyScale: number = 1
  @State flyOpacity: number = 1
  @State isFavorited: boolean = false
  @State reviewOrderNumber: string = ''
  @State showImagePreview: boolean = false
  @State previewImageIndex: number = 0
  @State showSkuSheet: boolean = false
  @State sheetMode: string = 'add_cart'

  @State currentSkuPrice: number = 0
  @State currentSkuImage: string = ''
  @State currentSkuId: string = ''
  @State matchedSKU: SKU | null = null
  @State productImages: string[] = []
  @State displayPriceValue: number = 0
  @State displayStockValue: number = 0

  updateProductImages(): void {
    let arr: string[] = []
    if (this.product && this.product.images && this.product.images.length > 0) {
      arr = this.product.images
    }
    if (this.currentSkuImage && arr.indexOf(this.currentSkuImage) === -1) {
      arr = [this.currentSkuImage].concat(arr)
    }
    this.productImages = arr
  }

  updateDisplayValues(): void {
    if (this.currentSkuPrice > 0) {
      this.displayPriceValue = this.currentSkuPrice
    } else if (this.product) {
      this.displayPriceValue = this.product.price
    } else {
      this.displayPriceValue = 0
    }
    if (this.product && this.product.hasSKU() && this.matchedSKU) {
      this.displayStockValue = this.matchedSKU.stock
    } else if (this.product) {
      this.displayStockValue = this.product.stock
    } else {
      this.displayStockValue = 0
    }
  }

  onSkuChange(selectedSpecs: Record<string, string>, matchedSKU: SKU | null, skuPrice: number, skuImage: string, skuId: string): void {
    this.currentSkuPrice = skuPrice
    this.currentSkuImage = skuImage
    this.currentSkuId = skuId
    this.matchedSKU = matchedSKU
    this.updateProductImages()
    this.updateDisplayValues()
  }

  async toggleFavorite(): Promise<void> {
    if (!this.product) return
    this.isFavorited = await favoriteRepository.toggle(this.product.id)
    this.getUIContext().getPromptAction().showToast({ message: this.isFavorited ? '已收藏' : '已取消收藏' })
  }

  async aboutToAppear(): Promise<void> {
    this.isLoading = true
    let routerP = AppRouter.getParams<ProductDetailParams>()
    if (routerP) this.params = routerP
    try {
      let p = this.params
      if (p) {
        this.reviewOrderNumber = p.orderNumber || ''
        await productRepository.load()
        await favoriteRepository.load()
        let serverProduct = await productRepository.getProductDetail(p.productId)
        this.product = serverProduct || null
        if (this.product) {
          this.isFavorited = favoriteRepository.isFavorited(this.product.id)
          browseHistoryRepository.add(this.product.id)
        }
        this.updateProductImages()
        this.updateDisplayValues()
      }
    } finally {
      this.isLoading = false
    }
  }

  async onPageShow(): Promise<void> {
    this.refreshCount++
  }

  startFlyAnimation(img: string, x: number, y: number): void {
    this.flyImage = img
    this.flyX = x - 30
    this.flyY = y - 30
    this.flyW = 60
    this.flyH = 60
    this.flyScale = 1
    this.flyOpacity = 1
    this.flyShow = true
    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 500, curve: Curve.FastOutLinearIn }, () => {
        this.flyY = 0
        this.flyScale = 0.2
        this.flyOpacity = 0
      })
      setTimeout(() => { this.flyShow = false }, 500)
    }, 30)
  }

  build() {
    Stack() {
      Column() {
        HeaderComponent({
          title: '商品详情',
          rightAction: '分享',
          onRightAction: () => { this.getUIContext().getPromptAction().showToast({ message: '链接已复制' }) }
        })

        if (this.isLoading) {
          Scroll() { LoadingSkeleton() }
            .layoutWeight(1).width('100%').backgroundColor(AppColor.cardBg()).scrollBar(BarState.Off)
        } else if (!this.product) {
          Column({ space: 16 }) {
            Blank()
            Text('商品不存在或已下架').fontSize(16).fontColor(AppColor.textTertiary())
AppButton({ text: '返回首页', type: AppButtonType.OUTLINE, buttonWidth: 160, buttonHeight: 44, buttonRadius: 22,
  fontSize: 15, fontWeight: FontWeight.Bold, buttonOnClick: () => { AppRouter.goToHome() } })
            Blank()
          }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Center).backgroundColor(AppColor.cardBg())
        } else {
          Scroll() {
            Column() {
              if (this.productImages.length > 0) {
                Swiper() {
                  ForEach(this.productImages, (img: string, index: number) => {
                    ProductImage({ src: img })
                      .width('100%').height(360)
                      .scale({ x: this.pinchScale, y: this.pinchScale })
                      .gesture(
                        PinchGesture({ fingers: 2 })
                          .onActionUpdate((event: GestureEvent) => {
                            if (event.scale > 0.5) { this.pinchScale = event.scale }
                          })
                          .onActionEnd(() => {
                            this.getUIContext()?.animateTo({ duration: 200, curve: Curve.Smooth }, () => { this.pinchScale = 1 })
                          })
                      )
                      .onClick(() => { this.previewImageIndex = index; this.showImagePreview = true })
                  }, (img: string, index: number) => img + index.toString())
                }
                .width('100%').height(360).autoPlay(false).loop(true)
                .indicator(new DotIndicator().selectedColor(AppColor.PRIMARY).color(AppColor.textTertiary()))
                .onChange(() => { this.pinchScale = 1 })
              } else {
                ProductImage({ src: this.product.image })
                  .width('100%').height(360)
                  .onClick(() => { if (this.product!.image) { this.previewImageIndex = 0; this.showImagePreview = true } })
              }

              ProductInfoSection({
                product: this.product!,
                displayPrice: this.displayPriceValue,
                displayStock: this.displayStockValue,
                isFavorited: this.isFavorited,
                avgRating: this.product.rating,
                reviewCount: this.product.reviewCount,
                onToggleFavorite: () => { this.toggleFavorite() },
                onSkuChange: (selectedSpecs: Record<string, string>, matchedSKU: SKU | null, skuPrice: number, skuImage: string, skuId: string) => {
                  this.onSkuChange(selectedSpecs, matchedSKU, skuPrice, skuImage, skuId)
                }
              })

              Line().width(AppContainer.WIDTH).height(6).backgroundColor(AppColor.inputBg()).margin({ top: 4 })

              Column({ space: 10 }) {
                Row() {
                  Text('图文详情').fontSize(17).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
                  Blank()
                }.width('100%')
                if (this.product.detailHtml && this.product.detailHtml.trim().length > 0) {
                  RichText(this.product.detailHtml).width('100%')
                } else {
                  ForEach(this.product.images, (img: string, index: number) => {
                    ProductImage({ src: img }).width('100%').height(320).borderRadius(AppRadius.MD)
                  }, (img: string, index: number) => 'detail_' + img + index.toString())
                }
              }
              .padding(20).width('100%').alignItems(HorizontalAlign.Start)

              Line().width(AppContainer.WIDTH).height(6).backgroundColor(AppColor.inputBg())

              ProductReviewList({
                productId: this.product.id,
                reviewOrderNumber: this.reviewOrderNumber,
                refreshTrigger: this.refreshCount
              })
              .padding(20).width('100%')

              Blank().height(16)
            }.width('100%')
          }
          .layoutWeight(1).width('100%').backgroundColor(AppColor.cardBg()).scrollBar(BarState.Off)

          ProductActionBar({
            product: this.product,
            currentSkuId: this.currentSkuId,
            matchedSKU: this.matchedSKU,
            onOpenSheet: (mode: string) => {
              // 无 SKU 商品直接执行，跳过底面板
              if (this.product && !this.product.hasSKU()) {
                if (mode === 'add_cart') {
                  cartViewModel.addToCart(this.product).then(() => {
                    let img = this.product!.image
                    this.startFlyAnimation(img, 0, 0)
                  }).catch((e: Error) => {
                    this.getUIContext().getPromptAction().showToast({ message: e.message || '添加购物车失败' })
                  })
                } else {
                  cartViewModel.addToCart(this.product).then(() => {
                    cartViewModel.selectedCheckoutKeys = [this.product!.id.toString() + '_']
                    AppRouter.goToCheckout()
                  }).catch((e: Error) => {
                    this.getUIContext().getPromptAction().showToast({ message: e.message || '添加购物车失败' })
                  })
                }
                return
              }
              this.sheetMode = mode
              this.showSkuSheet = true
            }
          })
        }
      }
      .width('100%').height('100%').backgroundColor(AppColor.bg())

      if (this.showImagePreview) {
        ProductImagePreview({
          images: this.productImages,
          initialIndex: this.previewImageIndex,
          onClose: () => { this.showImagePreview = false }
        })
      }

      if (this.flyShow) {
        ProductImage({ src: this.flyImage })
          .width(this.flyW).height(this.flyH).borderRadius(AppRadius.SM)
          .position({ x: this.flyX, y: this.flyY })
          .scale({ x: this.flyScale, y: this.flyScale })
          .opacity(this.flyOpacity)
      }

      if (this.showSkuSheet && this.product) {
        SkuBottomSheet({
          product: this.product,
          mode: this.sheetMode,
          initSkuId: this.currentSkuId,
          initPrice: this.currentSkuPrice,
          initImage: this.currentSkuImage,
          onConfirm: (skuId: string, quantity: number) => {
            if (this.sheetMode === 'add_cart') {
              cartViewModel.addToCart(this.product!, skuId, quantity).then(() => {
                let img = this.currentSkuImage || this.product!.image
                this.startFlyAnimation(img, 0, 0)
              }).catch((e: Error) => {
                this.getUIContext().getPromptAction().showToast({ message: e.message || '添加购物车失败' })
              })
            } else {
              cartViewModel.addToCart(this.product!, skuId, quantity).then(() => {
                cartViewModel.selectedCheckoutKeys = [this.product!.id.toString() + '_' + (skuId || '')]
                AppRouter.goToCheckout()
              }).catch((e: Error) => {
                this.getUIContext().getPromptAction().showToast({ message: e.message || '添加购物车失败' })
              })
            }
          },
          onClose: () => { this.showSkuSheet = false }
        })
      }
    }
    .width('100%').height('100%')
  }

  pageTransition() {
    PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn }).opacity(0)
    PageTransitionExit({ duration: 350, curve: Curve.FastOutSlowIn }).opacity(0)
  }
}
