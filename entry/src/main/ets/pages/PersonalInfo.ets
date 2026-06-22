import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { orderViewModel } from '../viewmodel/OrderViewModel'
import { AppRouter } from '../common/AppRouter'

import { fileIo } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { AppColor, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppContainer } from '../components/AppContainer'
import { HeaderComponent } from '../components/HeaderComponent'
import { StatBox } from '../components/StatBox'
import { OrderStatusValue } from '../common/Constants'
import { Logger } from '../common/Logger'
import { AppInput } from '../components/AppInput'

@Entry
@Component
struct PersonalInfo {
  @State username: string = ''
  @State nickname: string = ''
  @State phone: string = ''
  @State points: number = 0
  @State memberLevel: number = 0
  @State avatarColor: string = AppColor.PRIMARY
  @State avatarPath: string = ''
  @State avatarLoadError: boolean = false
  @State gender: string = '保密'
  @State age: number = 0
  @State showGenderPicker: boolean = false
  @State showAgeInput: boolean = false
  @State ageText: string = ''
  @State showNicknameEdit: boolean = false
  @State nicknameText: string = ''
  @State showPhoneEdit: boolean = false
  @State phoneText: string = ''

  @State totalSpent: number = 0
  @State yearSpent: number = 0
  @State monthSpent: number = 0
  @State regDays: number = 0
  @State orderCount: number = 0

  aboutToAppear(): void {
    if (!sessionViewModel.isLoggedIn()) {
      AppRouter.goToLogin()
      return
    }
    let user = sessionViewModel.currentUser
    if (user) {
      this.username = user.username
      this.nickname = user.nickname || user.username
      this.phone = user.phone || ''
      this.points = user.points
      this.memberLevel = user.memberLevel
      this.avatarColor = user.avatarColor
      this.avatarPath = user.avatarPath
      this.avatarLoadError = false
      this.gender = user.gender || '保密'
      this.age = user.age || 0
    }
    this.computeStats()
  }

  computeStats(): void {
    let now = new Date()
    let thisYear = now.getFullYear()
    let thisMonth = now.getMonth()
    let total = 0
    let yearTotal = 0
    let monthTotal = 0
    let count = 0
    for (let o of orderViewModel.orders) {
      if (o.status === OrderStatusValue.CANCELLED) continue
      total += o.totalPrice
      count++
      let d = new Date(o.createTime)
      if (d.getFullYear() === thisYear) {
        yearTotal += o.totalPrice
        if (d.getMonth() === thisMonth) {
          monthTotal += o.totalPrice
        }
      }
    }
    this.totalSpent = total
    this.yearSpent = yearTotal
    this.monthSpent = monthTotal
    this.orderCount = count

    let user = sessionViewModel.currentUser
    if (user && user.registrationDate) {
      let reg = new Date(user.registrationDate)
      let diff = now.getTime() - reg.getTime()
      this.regDays = Math.floor(diff / (1000 * 60 * 60 * 24)) + 1
    } else {
      this.regDays = 1
    }
  }

  async pickImage(): Promise<void> {
    try {
      let context = getContext(this)
      let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
      let picker = new photoAccessHelper.PhotoViewPicker()
      let result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      })
      if (result && result.photoUris && result.photoUris.length > 0) {
        let uri = result.photoUris[0]
        let destPath = context.filesDir + '/avatar_' + Date.now() + '.jpg'
        fileIo.copyFileSync(uri, destPath)
        this.avatarPath = destPath
        this.avatarLoadError = false
        await sessionViewModel.saveAvatarPath(destPath)
        this.getUIContext().getPromptAction().showToast({ message: '头像已更新' })
      }
    } catch (err) {
      Logger.error('pickImage failed: ' + JSON.stringify(err))
    }
  }

  selectGender(g: string): void {
    this.gender = g
    this.showGenderPicker = false
    this.saveInfo()
  }

  saveAge(): void {
    let v = parseInt(this.ageText)
    if (isNaN(v) || v < 0 || v > 200) {
      this.getUIContext().getPromptAction().showToast({ message: '请输入有效年龄' })
      return
    }
    this.age = v
    this.showAgeInput = false
    this.saveInfo()
  }

  memberLevelName(): string {
    return ['普通会员', '铜牌会员', '银牌会员', '金牌会员', '钻石会员'][this.memberLevel] || '普通会员'
  }

  saveNickname(): void {
    let v = this.nicknameText.trim()
    if (v === '') {
      this.getUIContext().getPromptAction().showToast({ message: '昵称不能为空' })
      return
    }
    this.nickname = v
    this.showNicknameEdit = false
    this.saveInfo()
  }

  savePhone(): void {
    let v = this.phoneText.trim()
    if (v && !/^1\d{10}$/.test(v)) {
      this.getUIContext().getPromptAction().showToast({ message: '请输入正确的手机号' })
      return
    }
    this.phone = v
    this.showPhoneEdit = false
    this.saveInfo()
  }

  async saveInfo(): Promise<void> {
    await sessionViewModel.updatePersonalInfo(this.username, this.gender, this.age, this.nickname, this.phone)
  }

  build() {
    Stack() {
      Column() {
        HeaderComponent({ title: '个人信息' })

        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 12 }) {
              Stack() {
                if (this.avatarPath !== '' && !this.avatarLoadError) {
                  Circle().width(88).height(88).fill(AppColor.primaryBg())
                  Image('file://' + this.avatarPath)
                    .width(88).height(88).borderRadius(44)
                    .onError(() => { this.avatarLoadError = true })
                } else {
                  Circle().width(88).height(88).fill(AppColor.primaryBg())
                  Text(this.username.charAt(0).toUpperCase()).fontSize(38).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                }
              }
              .onClick(() => { this.pickImage() })

            Text(this.nickname)
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            Text('@' + this.username + '  |  会员: ' + this.memberLevelName() + '  |  ' + this.points + '积分')
              .fontSize(13).fontColor(AppColor.textTertiary()).margin({ top: 2 })
            }
            .width('100%').alignItems(HorizontalAlign.Center).padding({ top: 8, bottom: 8 })

            Column({ space: 0 }) {
              Text('基本资料').fontSize(16).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
                .width('100%').padding({ left: 4, bottom: 12 })

              Row() {
                Text('昵称').fontSize(15).fontColor(AppColor.textSecondary())
                Blank()
                Text(this.nickname).fontSize(15).fontColor(AppColor.textPrimary()).fontWeight(FontWeight.Medium).margin({ right: 6 })
                Image($rawfile('ic_chevron_right_primary.svg')).width(16).height(16)
              }
              .width('100%').padding({ left: 4, top: 14, bottom: 14 })
              .onClick(() => { this.nicknameText = this.nickname; this.showNicknameEdit = true })
              Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

              Row() {
                Text('用户名').fontSize(15).fontColor(AppColor.textSecondary())
                Blank()
                Text(this.username).fontSize(15).fontColor(AppColor.textDisabledLight()).fontWeight(FontWeight.Medium).margin({ right: 6 })
              }
              .width('100%').padding({ left: 4, top: 14, bottom: 14 })
              Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

              Row() {
                Text('手机号').fontSize(15).fontColor(AppColor.textSecondary())
                Blank()
                Text(this.phone || '未设置').fontSize(15).fontColor(AppColor.textPrimary()).fontWeight(FontWeight.Medium).margin({ right: 6 })
                Image($rawfile('ic_chevron_right_primary.svg')).width(16).height(16)
              }
              .width('100%').padding({ left: 4, top: 14, bottom: 14 })
              .onClick(() => { this.phoneText = this.phone; this.showPhoneEdit = true })

              Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

              Row() {
                Text('性别').fontSize(15).fontColor(AppColor.textSecondary())
                Blank()
                Text(this.gender).fontSize(15).fontColor(AppColor.textPrimary()).fontWeight(FontWeight.Medium).margin({ right: 6 })
                Image($rawfile('ic_chevron_right_primary.svg')).width(16).height(16)
              }
              .width('100%').padding({ left: 4, top: 14, bottom: 14 })
              .onClick(() => { this.showGenderPicker = true })

            Line().width('100%').height(0.5).backgroundColor(AppColor.divider())

            Row() {
              Text('年龄').fontSize(15).fontColor(AppColor.textPrimary()).fontWeight(FontWeight.Medium).layoutWeight(1)
              Text(this.age.toString()).fontSize(15).fontColor(AppColor.textSecondary())
                .margin({ right: 12 })
              Image($rawfile('ic_chevron_right_primary.svg')).width(16).height(16)
              }
              .width('100%').padding({ left: 4, top: 14, bottom: 14 })
              .onClick(() => { this.ageText = this.age > 0 ? this.age.toString() : ''; this.showAgeInput = true })

            Column({ space: 0 }) {
              Row() {
                Text('会员信息').fontSize(16).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
                Blank()
              }.width('100%').padding({ left: 4, bottom: 14 })
              Row({ space: 0 }) {
                StatBox({ label: '会员等级', value: this.memberLevelName() })
                StatBox({ label: '积分', value: this.points.toString() })
              }.width('100%')
            }
            .width('92%').padding(16).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
            .shadow(AppShadow.mid())

            Column({ space: 0 }) {
              Row() {
                Text('购物历程').fontSize(16).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
                Blank()
                Text('共 ' + this.orderCount + ' 笔订单').fontSize(13).fontColor(AppColor.textTertiary())
              }
              .width('100%').padding({ left: 4, bottom: 14 })

              Row({ space: 0 }) {
  StatBox({ label: '总消费', value: '¥' + this.totalSpent.toFixed(2) })
  StatBox({ label: '今年消费', value: '¥' + this.yearSpent.toFixed(2) })
              }
              .width('100%')

              Row({ space: 0 }) {
                StatBox({ label: '本月消费', value: '¥' + this.monthSpent.toFixed(2) })
                StatBox({ label: '注册天数', value: this.regDays + '天' })
              }
              .width('100%')
            }
            .width('92%').padding(16).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
            .shadow(AppShadow.mid())

            Blank().height(20)
            }
            .width('92%').padding(16).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
            .shadow(AppShadow.mid())
          }
        }
        .scrollBar(BarState.Off)
      }
      .layoutWeight(1)

      if (this.showGenderPicker) {
        Column() {
          Column({ space: 12 }) {
            Text('选择性别').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            ForEach(['男', '女', '保密'], (g: string) => {
              Row() {
                Text(g).fontSize(16).fontColor(AppColor.textPrimary()).layoutWeight(1)
                if (this.gender === g) {
                  Path()
                    .width(18).height(18).fill(AppColor.PRIMARY)
                    .commands('M4,10 L8,14 L16,4')
                    .stroke(AppColor.WHITE).strokeWidth(2.5)
                    .strokeLineCap(LineCapStyle.Round).strokeLineJoin(LineJoinStyle.Round)
                }
              }
              .width('100%').padding({ left: 8, right: 8, top: 10, bottom: 10 })
              .onClick(() => { this.selectGender(g) })
            }, (g: string) => g)
            AppButton({ text: '关闭', type: AppButtonType.SECONDARY, buttonHeight: 48, buttonWidth: '100%', fontSize: 16, buttonOnClick: () => { this.showGenderPicker = false } })
          }
          .width('75%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }

      if (this.showAgeInput) {
        Column() {
          Column({ space: 16 }) {
            Text('设置年龄').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            AppInput({ placeholder: '请输入年龄', value: this.ageText, onChange: (v) => { this.ageText = v }, type: InputType.Number })
            Row({ space: 12 }) {
              Column() {
                AppButton({ text: '取消', type: AppButtonType.SECONDARY, buttonHeight: 48, buttonWidth: '100%', fontSize: 16, buttonOnClick: () => { this.showAgeInput = false } })
              }.layoutWeight(1)
              Column() {
                AppButton({ text: '确认', type: AppButtonType.PRIMARY, buttonHeight: 48, buttonWidth: '100%', fontSize: 16, buttonOnClick: () => { this.saveAge() } })
              }.layoutWeight(1)
            }.width('100%')
          }
          .width('80%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }

      if (this.showNicknameEdit) {
        Column() {
          Column({ space: 16 }) {
            Text('修改昵称').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            AppInput({ placeholder: '请输入昵称', value: this.nicknameText, onChange: (v) => { this.nicknameText = v } })
            Row({ space: 12 }) {
              Column() {
                AppButton({ text: '取消', type: AppButtonType.SECONDARY, buttonHeight: 48, buttonWidth: '100%', fontSize: 16, buttonOnClick: () => { this.showNicknameEdit = false } })
              }.layoutWeight(1)
              Column() {
                AppButton({ text: '保存', type: AppButtonType.PRIMARY, buttonHeight: 48, buttonWidth: '100%', fontSize: 16, buttonOnClick: () => { this.saveNickname() } })
              }.layoutWeight(1)
            }.width('100%')
          }
          .width('80%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }

      if (this.showPhoneEdit) {
        Column() {
          Column({ space: 16 }) {
            Text('修改手机号').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            AppInput({ placeholder: '请输入手机号', value: this.phoneText, onChange: (v) => { this.phoneText = v }, type: InputType.PhoneNumber })
            Row({ space: 12 }) {
              Column() {
                AppButton({ text: '取消', type: AppButtonType.SECONDARY, buttonHeight: 48, buttonWidth: '100%', fontSize: 16, buttonOnClick: () => { this.showPhoneEdit = false } })
              }.layoutWeight(1)
              Column() {
                AppButton({ text: '保存', type: AppButtonType.PRIMARY, buttonHeight: 48, buttonWidth: '100%', fontSize: 16, buttonOnClick: () => { this.savePhone() } })
              }.layoutWeight(1)
            }.width('100%')
          }
          .width('80%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%')
  }

  pageTransition() {
    PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
    PageTransitionExit({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
  }
}


