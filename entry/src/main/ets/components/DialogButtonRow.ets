import { AppButton, AppButtonType } from './AppButton'

@Component
export struct DialogButtonRow {
  @Prop cancelText: string = '取消'
  @Prop confirmText: string = '确定'
  @Prop confirmType: AppButtonType = AppButtonType.PRIMARY
  onCancel: () => void = () => {}
  onConfirm: () => void = () => {}

  build() {
    Row({ space: 12 }) {
      Column() {
        AppButton({ text: this.cancelText, type: AppButtonType.SECONDARY, buttonHeight: 48, buttonWidth: '100%', fontSize: 16, buttonOnClick: () => { this.onCancel() } })
      }.layoutWeight(1)
      Column() {
        AppButton({ text: this.confirmText, type: this.confirmType, buttonHeight: 48, buttonWidth: '100%', fontSize: 16, buttonOnClick: () => { this.onConfirm() } })
      }.layoutWeight(1)
    }.width('100%').height(48)
  }
}
