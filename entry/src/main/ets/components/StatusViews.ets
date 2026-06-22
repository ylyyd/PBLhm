import { AppRouter } from '../common/AppRouter'
import { AppColor, AppRadius } from '../common/StyleConstants'
import { AppButton, AppButtonType } from './AppButton'

@Component
export struct LoadingView {
  @Prop message: string = '加载中...'
  build() {
    Column() {
      LoadingProgress().width(40).height(40).color(AppColor.PRIMARY)
      Text(this.message).fontSize(14).fontColor(AppColor.textTertiary()).margin({ top: 12 })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct ErrorView {
  @Prop message: string = '加载失败'
  @Prop buttonText: string = '重试'
  onRetry?: () => void

  build() {
    Column({ space: 12 }) {
      Image($rawfile('error_icon.svg')).width(64).height(64).objectFit(ImageFit.Contain)
      Text(this.message).fontSize(15).fontColor(AppColor.textSecondary()).textAlign(TextAlign.Center)
      AppButton({ text: this.buttonText, type: AppButtonType.PRIMARY,
        buttonWidth: 140, buttonHeight: 36, buttonRadius: 20,
        fontSize: 14, buttonOnClick: () => { this.onRetry?.() } })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct EmptyView {
  @Prop message: string = '暂无数据'
  @Prop icon: ResourceStr = $rawfile('empty_box.svg')
  @Prop actionText: string = ''
  action?: () => void

  build() {
    Column({ space: 12 }) {
      Image(this.icon).width(80).height(80).objectFit(ImageFit.Contain)
      Text(this.message).fontSize(14).fontColor(AppColor.textTertiary()).textAlign(TextAlign.Center)
      if (this.actionText && this.action) {
        AppButton({ text: this.actionText, type: AppButtonType.PRIMARY,
          buttonWidth: 140, buttonHeight: 36, buttonRadius: AppRadius.BTN,
          fontSize: 14, fontWeight: FontWeight.Medium,
          buttonOnClick: () => { this.action!() } })
      }
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct BackButton {
  onBack?: () => void

  build() {
    Stack() {
      Circle().width(36).height(36)
        .fill(AppColor.cardBg()).stroke(AppColor.PRIMARY).strokeWidth(1.5)
      Text('‹').fontSize(24).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Medium)
    }
    .onClick(() => {
      if (this.onBack) {
        this.onBack()
      } else {
        AppRouter.back()
      }
    })
  }
}
