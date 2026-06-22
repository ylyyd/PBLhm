import { Product } from '../data/model/ProductModel'
import { AppColor, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppButton, AppButtonType } from './AppButton'
import { ProductImage } from './ProductImage'

@Reusable
@Component
export struct ProductCard {
  @Prop product: Product = new Product()
  onAddToCart?: () => void
  onBuyNow?: () => void
  onCardClick?: () => void
  onFlyFrom?: (x: number, y: number) => void
  @State showPlaceholder: boolean = false
  @State cardX: number = 0
  @State cardY: number = 0
  @State cardW: number = 0
  @State cardH: number = 0

  aboutToReuse(params: Record<string, Object>): void {
    this.showPlaceholder = false
    if (params.product !== undefined) {
      this.product = params.product as Product
    }
    if (params.onAddToCart !== undefined) {
      this.onAddToCart = params.onAddToCart as () => void
    }
    if (params.onBuyNow !== undefined) {
      this.onBuyNow = params.onBuyNow as () => void
    }
    if (params.onCardClick !== undefined) {
      this.onCardClick = params.onCardClick as () => void
    }
    if (params.onFlyFrom !== undefined) {
      this.onFlyFrom = params.onFlyFrom as (x: number, y: number) => void
    }
  }

  build() {
    Column() {
      Stack() {
        ProductImage({ src: this.product.image, fit: ImageFit.Cover })
          .width('100%').height(150)
        if (this.product.salesCount > 0) {
          Text('已售' + this.product.salesCount + '件')
            .fontSize(10).fontColor(AppColor.WHITE)
            .backgroundColor(AppColor.OVERLAY).borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .position({ x: 8, y: 8 })
        }
        if (this.product.salesCount > 100) {
          Text('热卖')
            .fontSize(10).fontColor(AppColor.WHITE)
            .backgroundColor(AppColor.PRIMARY).borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .position({ x: 8, y: 30 })
        }
        if (this.product.rating === 0) {
          Text('新品')
            .fontSize(10).fontColor(AppColor.WHITE)
            .backgroundColor(AppColor.SUCCESS).borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .position({ x: 8, y: this.product.salesCount > 100 ? 52 : 30 })
        }
        if (this.product.rating > 0) {
          Row({ space: 2 }) {
            ForEach([1, 2, 3, 4, 5], (i: number) => {
              Text(i <= Math.round(this.product.rating) ? '★' : '☆')
                .fontSize(12)
                .fontColor(i <= Math.round(this.product.rating) ? AppColor.STAR : AppColor.border())
            }, (i: number) => i.toString())
          }
          .padding({ left: 4, right: 4, top: 2, bottom: 2 })
          .backgroundColor(AppColor.OVERLAY).borderRadius(AppRadius.XS)
          .position({ x: 8, y: 126 })
        }
      }
      .width('100%').height(150).clip(true)
      .borderRadius({ topLeft: AppRadius.LG, topRight: AppRadius.LG })

      Column({ space: 8 }) {
        Text(this.product.name)
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')

        Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

        Row({ space: 6 }) {
          if (this.product.hasSKU()) {
            Text('¥' + this.product.getMinSkuPrice()).fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppColor.PRIMARY).letterSpacing(0.5)
            if (this.product.getMaxSkuPrice() > this.product.getMinSkuPrice()) {
              Text('起').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppColor.textTertiary()).margin({ left: -2, top: 8 })
            }
          } else {
            Text('¥' + this.product.price).fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppColor.PRIMARY).letterSpacing(0.5)
          }
          Blank()
          if (this.product.salesCount > 0) {
            Text('已售' + this.product.salesCount).fontSize(10).fontColor(AppColor.textTertiary())
          }
        }.width('100%')

        Row({ space: 8 }) {
          AppButton({ text: '加入购物车', type: AppButtonType.OUTLINE,
            buttonWidth: '48%', buttonHeight: 32, buttonRadius: 16,
            fontSize: 13, fontWeight: FontWeight.Medium,
            fontColor: AppColor.PRIMARY,
            buttonOnClick: () => {
              this.onAddToCart?.()
              this.onFlyFrom?.(this.cardX + this.cardW / 2, this.cardY + this.cardH - 16)
            } })
          AppButton({ text: '立即购买', type: AppButtonType.PRIMARY,
            buttonWidth: '48%', buttonHeight: 32, buttonRadius: 16,
            fontSize: 13, fontWeight: FontWeight.Bold,
            buttonOnClick: () => { this.onBuyNow?.() } })
        }.width('100%')
      }
      .padding(12).alignItems(HorizontalAlign.Start).width('100%')
    }
    .width('100%')
    .backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
    .border({ width: 0.5, color: AppColor.border(), style: BorderStyle.Solid })
    .shadow(AppShadow.mid()).padding(0)
    .onClick(() => { this.onCardClick?.() })
    .hoverEffect(HoverEffect.Scale)
    .onAreaChange((oldVal: Area, newVal: Area) => {
      this.cardX = newVal.globalPosition.x as number
      this.cardY = newVal.globalPosition.y as number
      this.cardW = newVal.width as number
      this.cardH = newVal.height as number
    })
  }
}
