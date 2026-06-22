import { AppColor, AppRadius } from '../common/StyleConstants'
import { ProductImage } from './ProductImage'

@Component
export struct ProductImagePreview {
  @Prop images: string[] = []
  @Prop initialIndex: number = 0
  onClose?: () => void

  build() {
    Stack() {
      // 图片轮播 - 占满全屏
      Swiper() {
        ForEach(this.images, (img: string, index: number) => {
          ProductImage({ src: img, fit: ImageFit.Contain })
            .width('100%').height('100%')
            .onClick(() => { this.onClose?.() })
        }, (img: string, index: number) => 'preview_' + img + index.toString())
      }
      .width('100%').height('100%')
      .autoPlay(false).loop(true)
      .index(this.initialIndex)

      // 关闭按钮 - 使用 Row 包裹加大触控区域，Swiper 不截胡
      Row() {
        Text('✕')
          .fontSize(24)
          .fontColor(AppColor.WHITE)
      }
      .width(44).height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(22)
      .backgroundColor('rgba(0,0,0,0.35)')
      .position({ x: '88%', y: 40 })
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => { this.onClose?.() })
    }
    .width('100%').height('100%')
    .backgroundColor(AppColor.OVERLAY_HEAVY)
  }
}
