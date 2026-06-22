import { Product, Review, SKU } from '../data/model/ProductModel'
import { AppColor, AppRadius } from '../common/StyleConstants'
import { ProductImage } from './ProductImage'
import { ProductSkuSelector } from './ProductSkuSelector'
import { HeartIcon } from './HeartIcon'

@Component
export struct ProductInfoSection {
  @Prop product: Product = new Product()
  @Prop displayPrice: number = 0
  @Prop displayStock: number = 0
  @Prop isFavorited: boolean = false
  @Prop avgRating: number = 0
  @Prop reviewCount: number = 0
  onToggleFavorite?: () => void
  onSkuChange?: (selectedSpecs: Record<string, string>, matchedSKU: SKU | null, skuPrice: number, skuImage: string, skuId: string) => void

  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.product.name).fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
          .layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        HeartIcon({ filled: this.isFavorited, iconSize: 30, onToggle: () => { this.onToggleFavorite?.() } })
          .margin({ left: 8 })
      }.width('100%')

      Row() {
        Text('¥').fontSize(20).fontColor(AppColor.PRIMARY).margin({ bottom: 4 })
        Text(String(this.displayPrice)).fontSize(36).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
        if (this.displayStock > 0) {
          Text('库存 ' + this.displayStock).fontSize(12).fontColor(AppColor.textTertiary()).margin({ left: 8 })
        } else if (this.displayStock === 0 && !this.product.hasSKU()) {
          Text('库存不足').fontSize(12).fontColor(AppColor.CANCEL).margin({ left: 8 })
        }
        Blank()
        Text(this.product.category).fontSize(13).fontColor(AppColor.PRIMARY).backgroundColor(AppColor.primaryBg())
          .borderRadius(AppRadius.XS).padding({ left: 12, right: 12, top: 6, bottom: 6 })
      }.width('100%')

      if (this.product.shopName) {
        Row() {
          Text('店铺：').fontSize(13).fontColor(AppColor.textTertiary())
          Text(this.product.shopName).fontSize(13).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Medium)
          Blank()
        }.width('100%').margin({ top: 4 })
      }

      ProductSkuSelector({
        specs: this.product.specs,
        skus: this.product.skus,
        productPrice: this.product.price,
        productStock: this.product.stock,
        productImage: this.product.image,
        hasSKU: this.product.hasSKU(),
        onSkuChange: (selectedSpecs: Record<string, string>, matchedSKU: SKU | null, skuPrice: number, skuImage: string, skuId: string) => {
          this.onSkuChange?.(selectedSpecs, matchedSKU, skuPrice, skuImage, skuId)
        }
      })

      Text(this.product.description).fontSize(16).fontColor(AppColor.textSecondary()).width('100%').lineHeight(26)

      Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

      // Stats row
      Row() {
        Column({ space: 4 }) {
          Text('销量').fontSize(12).fontColor(AppColor.textTertiary())
          Text('已售 ' + this.product.salesCount)
            .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        Column({ space: 4 }) {
          Text('评分').fontSize(12).fontColor(AppColor.textTertiary())
          Row({ space: 2 }) {
            Text('★').fontSize(14).fontColor(AppColor.PRIMARY)
            Text(this.avgRating > 0 ? this.avgRating.toString() : '暂无').fontSize(16)
              .fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        Column({ space: 4 }) {
          Text('评价').fontSize(12).fontColor(AppColor.textTertiary())
          Text(this.reviewCount + '条').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
      }
      .width('100%').padding({ top: 12, bottom: 12 }).backgroundColor(AppColor.bg()).borderRadius(AppRadius.MD)
    }
    .padding(20).width('100%').alignItems(HorizontalAlign.Start)
  }
}
