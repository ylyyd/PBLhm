import { AppColor, AppHeader } from '../common/StyleConstants'
import { BackButton } from './StatusViews'

@Component
export struct HeaderComponent {
  @Prop title: string = ''
  @Prop showBack: boolean = true
  @Prop rightAction: string = ''
  @Prop rightActionColor: string = ''
  onBack?: () => void
  onRightAction?: () => void

  build() {
    Row() {
      if (this.showBack) {
        BackButton({ onBack: this.onBack })
      } else {
        Blank().width(AppHeader.BACK_SIZE)
      }
      Blank()
      Text(this.title).fontSize(AppHeader.TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
      Blank()
      if (this.rightAction) {
        Text(this.rightAction)
          .fontSize(14).fontColor(this.rightActionColor || AppColor.PRIMARY).fontWeight(FontWeight.Medium)
          .onClick(() => { this.onRightAction?.() })
      } else {
        Blank().width(36)
      }
    }
    .width(AppHeader.WIDTH).padding({ top: AppHeader.TOP_PADDING, bottom: AppHeader.BOTTOM_PADDING })
  }
}
