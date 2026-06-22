import { AppColor } from '../common/StyleConstants'

@Component
export struct AppCheckbox {
  @Prop checked: boolean = false
  @Prop checkSize: number = 22
  onCheck?: () => void

  build() {
    Stack() {
      Circle()
        .width(this.checkSize).height(this.checkSize)
        .fill(this.checked ? AppColor.PRIMARY : AppColor.cardBg())
        .stroke(this.checked ? AppColor.PRIMARY : AppColor.textDisabledLight())
        .strokeWidth(2)
      if (this.checked) {
        Path()
          .commands(this.checkPath())
          .stroke(AppColor.WHITE).strokeWidth(2.5)
          .strokeLineCap(LineCapStyle.Round).strokeLineJoin(LineJoinStyle.Round)
      }
    }
    .onClick(() => { this.onCheck?.() })
  }

  checkPath(): string {
    if (this.checkSize <= 20) {
      return 'M6,11 L9,14 L15.5,6.5'
    }
    return 'M7,12 L10.5,15.5 L17,7'
  }
}
