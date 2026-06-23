import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { AppRouter } from '../common/AppRouter'

import { AppColor, AppContainer } from '../common/StyleConstants'
import { AppInput } from '../components/AppInput'
import { AppButton } from '../components/AppButton'

@Entry
@Component
struct Index {
  @State username: string = ''
  @State password: string = ''
  @State isLoggingIn: boolean = false


  aboutToAppear(): void {
    if (sessionViewModel.isLoggedIn()) {
      AppRouter.goToHome()
    }
  }

  build() {
    Column() {
      Blank().layoutWeight(1)

      Column({ space: 16 }) {
        Image($r('app.media.startIcon')).width(80).height(80).borderRadius(40)

        Column({ space: 4 }) {
          Text($r('app.string.login_title'))
            .fontSize(30).fontWeight(FontWeight.Bold).fontColor(AppColor.PRIMARY)
          Text($r('app.string.login_subtitle'))
            .fontSize(14).fontColor(AppColor.textTertiary())
        }.alignItems(HorizontalAlign.Center)
      }
      .width('100%').alignItems(HorizontalAlign.Center)
      .margin({ bottom: 48 })

      Column({ space: 14 }) {
        AppInput({ placeholder: '请输入用户名', value: this.username, onChange: (v) => { this.username = v } })
          .width(AppContainer.WIDTH)

        AppInput({ placeholder: '请输入密码', value: this.password, onChange: (v) => { this.password = v }, type: InputType.Password })
          .width(AppContainer.WIDTH)
      }
      .width('100%').alignItems(HorizontalAlign.Center)

      AppButton({ text: '登  录', buttonWidth: AppContainer.WIDTH, buttonHeight: 52,
        fontSize: 18, fontWeight: FontWeight.Bold,
        buttonOnClick: async () => {
          if (this.isLoggingIn) return
          if (this.username === '' || this.password === '') {
            this.getUIContext().getPromptAction().showToast({ message: '请输入用户名和密码' })
            return
          }
          this.isLoggingIn = true
          try {
            let user = await sessionViewModel.login(this.username, this.password)
            if (user) {
              this.getUIContext().getPromptAction().showToast({ message: '登录成功，欢迎回来！' })
              AppRouter.goToHome()
            } else {
              this.getUIContext().getPromptAction().showToast({ message: '用户名或密码错误' })
            }
          } finally {
            this.isLoggingIn = false
          }
        } })
        .margin({ top: 28 })
        .opacity(this.isLoggingIn ? 0.6 : 1.0)

      Row({ space: 4 }) {
        Text($r('app.string.login_no_account')).fontSize(14).fontColor(AppColor.textTertiary())
        Text($r('app.string.login_register'))
          .fontSize(14).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Medium)
          .onClick(() => { AppRouter.goToRegister() })
      }
      .margin({ top: 24 })

      Blank().layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor(AppColor.cardBg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
    PageTransitionExit({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
  }
}
