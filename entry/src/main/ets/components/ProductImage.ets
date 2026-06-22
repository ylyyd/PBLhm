import { AppColor, AppRadius } from '../common/StyleConstants'

@Component
export struct ProductImage {
  @Prop @Watch('onSrcChange') src: string = ''
  @Prop fit: number = ImageFit.Cover
  @Prop cornerRadius: number = AppRadius.MD
  @State showPlaceholder: boolean = false

  onSrcChange(): void {
    this.showPlaceholder = false
  }

  build() {
    Stack() {
      if (this.src && this.src.trim().length > 0 && !this.showPlaceholder) {
        Image($rawfile(this.src.trim()))
          .width('100%').height('100%')
          .objectFit(this.fit)
          .autoResize(true)
          .onError(() => {
            this.showPlaceholder = true
          })
      } else {
        Image($rawfile('ic_product_placeholder.svg'))
          .width('100%').height('100%')
          .objectFit(this.fit)
          .backgroundColor(AppColor.bg())
      }
      // Edge fade overlay for natural edge blending
      Row()
        .width('100%').height('100%')
        .border({ width: 1.5, color: '#0A000000' })
        .borderRadius(this.cornerRadius)
    }
    .clip(true)
    .borderRadius(this.cornerRadius)
  }
}
