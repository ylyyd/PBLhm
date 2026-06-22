import { Product, SKU } from '../data/model/ProductModel'
import { AppColor, AppRadius, AppContainer } from '../common/StyleConstants'
import { AppButton, AppButtonType } from './AppButton'

@Component
export struct ProductActionBar {
  @Prop product: Product | null = null
  @Prop currentSkuId: string = ''
  @Prop matchedSKU: SKU | null = null
  onOpenSheet?: (mode: string) => void

  checkAddDisabled(): string {
    if (!this.product) { return '' }
    if (this.matchedSKU && this.matchedSKU.stock <= 0) {
      return '该规格已售罄'
    }
    if (!this.product.hasSKU() && this.product.stock <= 0) {
      return '该商品已售罄'
    }
    return ''
  }

  build() {
    Row({ space: 12 }) {
      AppButton({ text: '加入购物车', type: AppButtonType.OUTLINE,
        buttonWidth: '48%', buttonHeight: 52, buttonRadius: AppRadius.XL,
        fontSize: 16, fontWeight: FontWeight.Medium, fontColor: AppColor.PRIMARY,
        buttonOnClick: () => {
          let msg = this.checkAddDisabled()
          if (msg) {
            this.getUIContext().getPromptAction().showToast({ message: msg })
            return
          }
          this.onOpenSheet?.('add_cart')
        } })
      AppButton({ text: '立即购买', type: AppButtonType.PRIMARY,
        buttonWidth: '48%', buttonHeight: 52, buttonRadius: AppRadius.XL,
        fontSize: 17, fontWeight: FontWeight.Bold,
        buttonOnClick: () => {
          let msg = this.checkAddDisabled()
          if (msg) {
            this.getUIContext().getPromptAction().showToast({ message: msg })
            return
          }
          this.onOpenSheet?.('buy_now')
        } })
    }
    .width(AppContainer.CONTENT_WIDTH).padding({ top: 12, bottom: 20 })
  }
}
