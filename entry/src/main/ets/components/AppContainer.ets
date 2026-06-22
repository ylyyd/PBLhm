import { AppColor } from '../common/StyleConstants'
import { BackButton } from './StatusViews'

@Component
export struct AppContainer {
  @Prop title: string = ''
  @Prop showBack: boolean = true
  @State contentSpace: number = 0

  @BuilderParam content: () => void = this.defaultContent

  @Builder
  defaultContent() {
    Column() {}
  }

  build() {
    Column() {
      if (this.showBack) {
        Row() {
          BackButton()
          Blank()
          Text(this.title)
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
          Blank().width(36)
        }
        .width('92%').padding({ top: 14, bottom: 10 })
      }
      this.content()
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())
  }
}
