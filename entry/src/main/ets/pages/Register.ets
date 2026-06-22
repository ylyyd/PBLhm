import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { AppRouter } from '../common/AppRouter'

import { AppConstants } from '../common/Constants'
import { AppColor, AppRadius, AppContainer } from '../common/StyleConstants'
import { AppInput } from '../components/AppInput'
import { AppButton } from '../components/AppButton'

@Component
struct PasswordRequirementItem {
  @Prop label: string = ''
  @Prop met: boolean = false
  @Prop active: boolean = false

  build() {
    Row({ space: 4 }) {
      Text(this.met ? '✓' : '✗')
        .fontSize(12)
        .fontColor(this.active ? (this.met ? AppColor.SUCCESS : AppColor.CANCEL) : AppColor.textDisabledLight())
      Text(this.label)
        .fontSize(12)
        .fontColor(this.active ? (this.met ? AppColor.SUCCESS : AppColor.CANCEL) : AppColor.textDisabledLight())
    }
    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
    .borderRadius(AppRadius.SM)
    .backgroundColor(this.active ? (this.met ? AppColor.statusBgGreen() : AppColor.statusBgRed()) : AppColor.bg())
    .alignItems(VerticalAlign.Center)
  }
}

@Entry
@Component
struct Register {
  @State username: string = ''
  @State nickname: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''

  build() {
    Column() {
      Scroll() {
        Column() {
          Blank().height(24)

          Row() {
            Image($r('app.media.startIcon')).width(56).height(56).borderRadius(AppRadius.CIRCLE)
            Text($r('app.string.register_title'))
              .fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 16 })
          }
          .width(AppContainer.WIDTH).margin({ top: 20, bottom: 36 })

          Column({ space: 14 }) {
          AppInput({ placeholder: '请输入用户名', value: this.username,
            onChange: (v) => { this.username = v }, inputHeight: 52 })
            .width('100%')

          AppInput({ placeholder: '请输入昵称（选填）', value: this.nickname,
            onChange: (v) => { this.nickname = v }, inputHeight: 52 })
            .width('100%')

          AppInput({ placeholder: '请输入密码（至少6位）', value: this.password,
            onChange: (v) => { this.password = v }, inputHeight: 52,
            type: InputType.Password })
            .width('100%')

            Row({ space: 8 }) {
              PasswordRequirementItem({ label: '至少6位', met: this.password.length >= 6, active: this.password.length > 0 })
              PasswordRequirementItem({ label: '包含字母', met: /[a-zA-Z]/.test(this.password), active: this.password.length > 0 })
              PasswordRequirementItem({ label: '包含数字', met: /\d/.test(this.password), active: this.password.length > 0 })
            }
            .width('100%').padding({ left: 4 })

          AppInput({ placeholder: '请确认密码', value: this.confirmPassword,
            onChange: (v) => { this.confirmPassword = v }, inputHeight: 52,
            type: InputType.Password })
            .width('100%')

          }
          .width(AppContainer.WIDTH).alignItems(HorizontalAlign.Center)

          AppButton({ text: '注  册', buttonWidth: AppContainer.WIDTH, buttonHeight: 52,
            fontSize: 18, fontWeight: FontWeight.Bold,
            buttonOnClick: async () => {
              if (this.username === '' || this.password === '' || this.confirmPassword === '') {
                this.getUIContext().getPromptAction().showToast({ message: '请填写完整信息' })
                return
              }
              if (this.password.length < AppConstants.PASSWORD_MIN_LENGTH) {
                this.getUIContext().getPromptAction().showToast({ message: '密码至少6位' })
                return
              }
              if (!/[a-zA-Z]/.test(this.password) || !/\d/.test(this.password)) {
                this.getUIContext().getPromptAction().showToast({ message: '密码必须包含字母和数字' })
                return
              }
              if (this.password !== this.confirmPassword) {
                this.getUIContext().getPromptAction().showToast({ message: '两次密码输入不一致' })
                return
              }
              let errMsg = await sessionViewModel.register(this.username, this.password, this.nickname || this.username)
              if (errMsg === null) {
                this.getUIContext().getPromptAction().showToast({ message: '注册成功！' })
                AppRouter.goToHome()
              } else {
                this.getUIContext().getPromptAction().showToast({ message: errMsg })
              }
            } })
            .margin({ top: 28 })

          Text($r('app.string.register_back_login'))
            .fontSize(14).fontColor(AppColor.PRIMARY).margin({ top: 24, bottom: 40 })
            .onClick(() => { AppRouter.back() })
        }
        .width('100%').alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
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
