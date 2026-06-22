import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { AppRouter } from '../common/AppRouter'

import { AppColor, AppRadius, AppShadow, getThemeMode } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppInput } from '../components/AppInput'
import { AppContainer } from '../components/AppContainer'
import { HeaderComponent } from '../components/HeaderComponent'
import { ConfirmDialog } from '../components/DialogComponent'

@Entry
@Component
struct Settings {
  @State paymentPassword: string = ''
  @State newPaymentPwd: string = ''
  @State confirmPaymentPwd: string = ''
  @State showPaymentDialog: boolean = false
  @State isChangingPwd: boolean = false
  @State oldPassword: string = ''
  @State newPassword: string = ''
  @State showChangePwdDialog: boolean = false
  @StorageLink('themeMode') themeMode: number = 0
  @State showThemePicker: boolean = false
  @State isRefreshing: boolean = false
  @State hasPaymentPwd: boolean = false
  private logoutDialog: CustomDialogController | null = null
  private switchAccountDialog: CustomDialogController | null = null

  async aboutToAppear(): Promise<void> {
    if (!sessionViewModel.isLoggedIn()) {
      AppRouter.goToLogin()
    }
    this.themeMode = getThemeMode()
    this.refreshPaymentPwdStatus()
  }

  onPageShow(): void {
    this.themeMode = getThemeMode()
    this.refreshPaymentPwdStatus()
  }

  refreshPaymentPwdStatus(): void {
    let user = sessionViewModel.currentUser
    this.hasPaymentPwd = user !== null && user.paymentPassword !== ''
  }

  onRefreshing(): void {
    this.themeMode = getThemeMode()
    this.isRefreshing = false
  }

  build() {
    Stack() {
      Column() {
        Refresh({ refreshing: $$this.isRefreshing }) {
          Scroll() {
            Column() {
              HeaderComponent({ title: '设置' })

              Column({ space: 0 }) {
                SettingsRow({ iconSrc: $rawfile('ic_shield.svg'), title: '支付密码', desc: this.hasPaymentPwd ? '已设置' : '未设置',
                  onTap: () => { this.isChangingPwd = this.hasPaymentPwd; this.showPaymentDialog = true } })
                Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

                SettingsRow({ iconSrc: $rawfile('ic_key.svg'), title: '修改账户密码', desc: '',
                  onTap: () => { this.showChangePwdDialog = true } })
                Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

                SettingsRow({ iconSrc: $rawfile('ic_map_pin.svg'), title: '收货地址', desc: '',
                  onTap: () => { AppRouter.goToAddressManagement() } })
                Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

                SettingsRow({ iconSrc: $rawfile('ic_palette.svg'), title: '主题切换', desc: ['跟随系统', '浅色模式', '深色模式'][this.themeMode],
                  onTap: () => { this.showThemePicker = true } })
                Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

                SettingsRow({ iconSrc: $rawfile('ic_shuffle.svg'), title: '切换账户', desc: '',
                  onTap: () => { this.confirmSwitchAccount() } })
                Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

                SettingsRow({ iconSrc: $rawfile('ic_logout.svg'), title: '退出登录', desc: '',
                  onTap: () => { this.confirmLogout() } })
              }
              .width('92%').backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD).margin({ top: 16 })
      .shadow(AppShadow.mid())
    }
    .width('100%').padding({ bottom: 30 })
          }
          .width('100%').scrollBar(BarState.Off)
        }
        .layoutWeight(1).width('100%')
        .onRefreshing(() => { this.onRefreshing() })
      }
      .width('100%').height('100%').backgroundColor(AppColor.bg())

      if (this.showPaymentDialog) {
        Column() {
          Column({ space: 16 }) {
            Text(this.isChangingPwd ? '修改支付密码' : '设置支付密码')
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            if (this.isChangingPwd) {
              AppInput({ placeholder: '请输入当前支付密码', value: this.paymentPassword, onChange: (v: string) => { this.paymentPassword = v.replace(/\D/g, '').slice(0, 6) }, type: InputType.Password })
            }
            AppInput({ placeholder: '请输入新支付密码（6位数字）', value: this.newPaymentPwd, onChange: (v: string) => { this.newPaymentPwd = v.replace(/\D/g, '').slice(0, 6) }, type: InputType.Password })
            AppInput({ placeholder: '确认新支付密码', value: this.confirmPaymentPwd, onChange: (v: string) => { this.confirmPaymentPwd = v.replace(/\D/g, '').slice(0, 6) }, type: InputType.Password })
            Row({ space: 12 }) {
              Column() {
                AppButton({ text: '取消', type: AppButtonType.SECONDARY, buttonWidth: '100%', buttonHeight: 48, buttonOnClick: () => { this.showPaymentDialog = false; this.clearPaymentFields() } })
              }.layoutWeight(1)
              Column() {
                AppButton({ text: '确认', type: AppButtonType.PRIMARY, buttonWidth: '100%', buttonHeight: 48, buttonOnClick: () => { this.handleSetPaymentPwd() } })
              }.layoutWeight(1)
            }.width('100%').height(48)
          }
          .width('80%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }

      if (this.showChangePwdDialog) {
        Column() {
          Column({ space: 16 }) {
            Text('修改账户密码').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            AppInput({ placeholder: '当前密码', value: this.oldPassword, onChange: (v: string) => { this.oldPassword = v }, type: InputType.Password })
            AppInput({ placeholder: '新密码（至少6位）', value: this.newPassword, onChange: (v: string) => { this.newPassword = v }, type: InputType.Password })
            Row({ space: 12 }) {
              Column() {
                AppButton({ text: '取消', type: AppButtonType.SECONDARY, buttonWidth: '100%', buttonHeight: 48, buttonOnClick: () => { this.showChangePwdDialog = false; this.clearPwdFields() } })
              }.layoutWeight(1)
              Column() {
                AppButton({ text: '确认修改', type: AppButtonType.PRIMARY, buttonWidth: '100%', buttonHeight: 48, buttonOnClick: () => { this.handleChangePassword() } })
              }.layoutWeight(1)
            }.width('100%').height(48)
          }
          .width('80%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }

      if (this.showThemePicker) {
        Column() {
          Column({ space: 14 }) {
            Text('选择主题').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            ForEach(['跟随系统', '浅色模式', '深色模式'], (mode: string, idx: number) => {
              Row() {
                Text(mode).fontSize(16).fontColor(AppColor.textPrimary()).layoutWeight(1)
                if (this.themeMode === idx) {
                  Path()
                    .width(16).height(16).fill(AppColor.PRIMARY)
                    .commands('M4,9 L7,12 L13,5')
                    .stroke(AppColor.WHITE).strokeWidth(2.5)
                    .strokeLineCap(LineCapStyle.Round).strokeLineJoin(LineJoinStyle.Round)
                }
              }
              .width('100%').padding({ left: 8, right: 8, top: 10, bottom: 10 })
              .onClick(async () => { this.themeMode = idx; this.showThemePicker = false;
                await sessionViewModel.setThemeMode(idx)
                this.getUIContext().getPromptAction().showToast({ message: '主题已切换为' + mode }) })
            }, (mode: string) => mode)
            Column() {
              AppButton({ text: '关闭', type: AppButtonType.SECONDARY, buttonWidth: '100%', buttonHeight: 48, buttonOnClick: () => { this.showThemePicker = false } })
            }.width('100%')
          }
          .width('75%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%')
  }

  clearPaymentFields(): void {
    this.paymentPassword = ''
    this.newPaymentPwd = ''
    this.confirmPaymentPwd = ''
  }

  clearPwdFields(): void {
    this.oldPassword = ''
    this.newPassword = ''
  }

  async handleSetPaymentPwd(): Promise<void> {
    if (this.isChangingPwd) {
      let ok = await sessionViewModel.verifyPaymentPassword(this.paymentPassword)
      if (!ok) {
        this.getUIContext().getPromptAction().showToast({ message: '当前支付密码错误' })
        return
      }
    }
    if (this.newPaymentPwd.length !== 6 || isNaN(Number(this.newPaymentPwd))) {
      this.getUIContext().getPromptAction().showToast({ message: '支付密码需为6位数字' })
      return
    }
    if (this.newPaymentPwd !== this.confirmPaymentPwd) {
      this.getUIContext().getPromptAction().showToast({ message: '两次密码输入不一致' })
      return
    }
    let ok = await sessionViewModel.setPaymentPassword(this.newPaymentPwd)
    if (ok) {
      this.hasPaymentPwd = true
      this.getUIContext().getPromptAction().showToast({ message: '支付密码设置成功' })
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '设置失败，请检查网络连接' })
    }
    this.showPaymentDialog = false
    this.clearPaymentFields()
  }

  async handleChangePassword(): Promise<void> {
    if (this.newPassword.length < 6) {
      this.getUIContext().getPromptAction().showToast({ message: '新密码至少6位' })
      return
    }
    let u = sessionViewModel.currentUser
    let ok = await sessionViewModel.updateProfile({
      'password': this.newPassword,
      'oldPassword': this.oldPassword,
      'address': u?.address || '',
      'nickname': u?.nickname || u?.username || ''
    })
    if (ok) {
      this.getUIContext().getPromptAction().showToast({ message: '密码修改成功' })
      this.showChangePwdDialog = false
      this.clearPwdFields()
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '密码修改失败，请检查当前密码' })
    }
  }

  async doLogout(msg: string): Promise<void> {
    await sessionViewModel.logout()
    this.getUIContext().getPromptAction().showToast({ message: msg })
    AppRouter.goToLogin()
  }

  confirmLogout(): void {
    this.logoutDialog = new CustomDialogController({
      builder: ConfirmDialog({ title: '确认退出', message: '确定要退出登录吗？', onConfirm: () => { this.doLogout('已退出登录') } }),
      autoCancel: true,
      customStyle: true,
      maskColor: 'rgba(0, 0, 0, 0.35)'
    })
    this.logoutDialog.open()
  }

  confirmSwitchAccount(): void {
    this.switchAccountDialog = new CustomDialogController({
      builder: ConfirmDialog({ title: '切换账户', message: '确定要切换账户吗？当前登录信息将被清除。', onConfirm: () => { this.doLogout('已切换到登录页') } }),
      autoCancel: true,
      customStyle: true,
      maskColor: 'rgba(0, 0, 0, 0.35)'
    })
    this.switchAccountDialog.open()
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
      .opacity(0)
    PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
      .opacity(0)
  }
}

@Component
struct SettingsRow {
  @Prop iconSrc: Resource = $rawfile('ic_shield.svg')
  @Prop title: string = ''
  @Prop desc: string = ''
  onTap: () => void = () => {}

  build() {
    Row() {
      Stack() {
        Circle().width(32).height(32).fill(AppColor.primaryBg())
        Image(this.iconSrc).width(18).height(18)
      }.margin({ right: 12 })
      Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
      Blank().layoutWeight(1)
      if (this.desc !== '') {
        Text(this.desc).fontSize(13).fontColor(AppColor.textDisabledLight()).margin({ right: 8 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Image($rawfile('ic_chevron_right_primary.svg')).width(18).height(18)
    }
    .width('100%').padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .onClick(() => { this.onTap() })
  }
}
