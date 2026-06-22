import { AppColor, AppRadius } from '../common/StyleConstants'

export enum AppButtonType {
  PRIMARY,
  SECONDARY,
  OUTLINE,
  DANGER,
  TEXT
}

@Component
export struct AppButton {
  @Prop text: string = ''
  @Prop type: AppButtonType = AppButtonType.PRIMARY
  @Prop buttonWidth: string | number = ''
  @Prop buttonHeight: number = 48
  @Prop buttonRadius: number = AppRadius.BTN
  @Prop fontSize: number = 15
  @Prop fontWeight: FontWeight = FontWeight.Medium
  @Prop loading: boolean = false
  @Prop fontColor: string = ''
  buttonOnClick?: () => void

  @Builder
  buttonContent(): void {
    Text(this.text)
      .fontSize(this.fontSize)
      .fontWeight(this.fontWeight)
      .fontColor(this.fontColor !== '' ? this.fontColor : this.getDefaultFontColor())
      .textAlign(TextAlign.Center)
  }

  build() {
    // TEXT button without explicit width → content-sized (works inside Row)
    if (this.type === AppButtonType.TEXT && this.buttonWidth === '') {
      Button() {
        this.buttonContent()
      }
        .height(this.buttonHeight)
        .borderRadius(this.buttonRadius)
        .onClick(() => { this.buttonOnClick?.() })
        .stateEffect(false)
        .focusable(false)
        .backgroundColor(this.getBackgroundColor())
        .border(this.getBorderStyle())
    } else {
      Button() {
        this.buttonContent()
      }
        .width(this.buttonWidth !== '' ? this.buttonWidth : '100%')
        .height(this.buttonHeight)
        .borderRadius(this.buttonRadius)
        .onClick(() => { this.buttonOnClick?.() })
        .stateEffect(false)
        .focusable(false)
        .backgroundColor(this.getBackgroundColor())
        .border(this.getBorderStyle())
    }
  }

  getBackgroundColor(): ResourceColor {
    if (this.type === AppButtonType.PRIMARY) {
      return AppColor.PRIMARY
    } else if (this.type === AppButtonType.SECONDARY) {
      return AppColor.tabInactive()
    } else if (this.type === AppButtonType.OUTLINE) {
      return Color.Transparent
    } else if (this.type === AppButtonType.DANGER) {
      return AppColor.CANCEL
    }
    return Color.Transparent
  }

  getBorderStyle(): BorderOptions | undefined {
    if (this.type === AppButtonType.OUTLINE) {
      return { width: 1, color: AppColor.PRIMARY, style: BorderStyle.Solid }
    }
    return undefined
  }

  getDefaultFontColor(): string {
    if (this.type === AppButtonType.PRIMARY || this.type === AppButtonType.DANGER) {
      return AppColor.WHITE
    } else if (this.type === AppButtonType.SECONDARY) {
      return AppColor.textSecondary()
    } else if (this.type === AppButtonType.OUTLINE) {
      return AppColor.PRIMARY
    } else if (this.type === AppButtonType.TEXT) {
      return AppColor.PRIMARY
    }
    return AppColor.WHITE
  }
}
