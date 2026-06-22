import { AppColor, AppRadius } from '../common/StyleConstants'

@Component
export struct AppInput {
  @Prop label: string = ''
  @Prop placeholder: string = ''
  @Prop value: string = ''
  @Prop type: InputType = InputType.Normal
  @Prop maxLength: number = -1
  @Prop inputHeight: number = 48
  onChange?: (value: string) => void

  build() {
    Column({ space: 6 }) {
      if (this.label) {
        Text(this.label)
          .fontSize(14).fontColor(AppColor.textSecondary()).width('100%')
      }
      TextInput({ placeholder: this.placeholder, text: this.value })
        .onChange((v: string) => { this.onChange?.(v) })
        .height(this.inputHeight)
        .backgroundColor(AppColor.inputBg())
        .borderRadius(AppRadius.MD)
        .padding({ left: 16 })
        .fontSize(16)
        .type(this.type)
        .width('100%')
        .placeholderColor(AppColor.textTertiary())
        .placeholderFont({ size: 16 })
        .maxLength(this.maxLength > 0 ? this.maxLength : -1)
    }
    .width('100%')
  }
}
