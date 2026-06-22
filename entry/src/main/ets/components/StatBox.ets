import { AppColor, AppRadius } from '../common/StyleConstants'

@Component
export struct StatBox {
  @Prop label: string = ''
  @Prop value: string = ''

  build() {
    Column({ space: 6 }) {
      Text(this.value).fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppColor.PRIMARY)
      Text(this.label).fontSize(12).fontColor(AppColor.textTertiary())
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Center).padding({ top: 12, bottom: 12 }).borderRadius(AppRadius.MD)
  }
}
