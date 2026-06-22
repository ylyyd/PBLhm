import { AppColor, AppContainer, AppRadius } from '../common/StyleConstants'
import { AppButton, AppButtonType } from './AppButton'
import { DialogButtonRow } from './DialogButtonRow'

@CustomDialog
export struct ConfirmDialog {
  controller?: CustomDialogController
  @State title: string = ''
  @State message: string = ''
  @State cancelText: string = '取消'
  @State confirmText: string = '确定'
  @State confirmType: AppButtonType = AppButtonType.PRIMARY
  onConfirm: () => void = () => {}

  build() {
    Column() {
      Column({ space: 12 }) {
        Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
          .textAlign(TextAlign.Center).width('100%')
        if (this.message.length > 0) {
          Text(this.message).fontSize(14).fontColor(AppColor.textSecondary())
            .textAlign(TextAlign.Center).width('100%').lineHeight(22)
        }
      }
      .padding({ bottom: 16 })

      DialogButtonRow({
        cancelText: this.cancelText,
        confirmText: this.confirmText,
        confirmType: this.confirmType,
        onCancel: () => { this.controller?.close() },
        onConfirm: () => {
          this.onConfirm()
          this.controller?.close()
        }
      })
    }
    .padding(24)
    .backgroundColor(AppColor.cardBg())
    .borderRadius(AppRadius.LG)
    .width(AppContainer.DIALOG_WIDTH)
    .shadow({ radius: 12, color: AppColor.shadowLight(), offsetX: 0, offsetY: 4 })
  }
}
