import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { User } from '../data/model/UserModel'
import { AppRouter } from '../common/AppRouter'

import { fileIo } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import http from '@ohos.net.http'
import { AppColor } from '../common/StyleConstants'
import { AppConstants } from '../common/Constants'
import { AppInput } from '../components/AppInput'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppContainer } from '../components/AppContainer'
import { HeaderComponent } from '../components/HeaderComponent'
import { AppConfig } from '../common/Config'
import { Logger } from '../common/Logger'

@Entry
@Component
struct EditProfile {
  @State username: string = ''
  @State nickname: string = ''
  @State oldPassword: string = ''
  @State password: string = ''
  @State address: string = ''
  @State avatarColor: string = AppColor.PRIMARY
  @State avatarPath: string = ''
  @State avatarLoadError: boolean = false

  aboutToAppear(): void {
    if (!sessionViewModel.isLoggedIn()) {
      AppRouter.goToLogin()
      return
    }
    let user = sessionViewModel.currentUser
    if (user) {
      this.username = user.username
      this.nickname = user.nickname || user.username
      this.address = user.address
      this.avatarColor = user.avatarColor
      this.avatarPath = user.avatarPath
      this.avatarLoadError = false
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
        await this.uploadAvatar(destPath)
      }
    } catch (err) {
      Logger.error('pickImage failed: ' + JSON.stringify(err))
    }
  }

  async uploadAvatar(filePath: string): Promise<void> {
    try {
      let httpRequest = http.createHttp()
      let resp: http.HttpResponse = await httpRequest.request(AppConfig.API_BASE_URL + '/upload', {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'multipart/form-data' },
        extraData: filePath,
        connectTimeout: 10000,
        readTimeout: 30000
      })
      httpRequest.destroy()
      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        try {
          let data = JSON.parse(resp.result as string) as Record<string, Object>
          let serverUrl = data.url as string
          if (serverUrl) {
            let fullUrl = AppConfig.API_BASE_URL.replace('/api', '') + serverUrl
            await sessionViewModel.saveAvatarPath(fullUrl)
            await sessionViewModel.updateProfile({ 'avatar': fullUrl, 'address': this.address })
            this.getUIContext().getPromptAction().showToast({ message: '头像已更新' })
            return
          }
        } catch {}
      }
      await this.saveAvatarLocal(filePath)
    } catch (err) {
      await this.saveAvatarLocal(filePath)
      Logger.error('uploadAvatar failed: ' + JSON.stringify(err))
    }
  }

  private async saveAvatarLocal(filePath: string): Promise<void> {
    await sessionViewModel.saveAvatarPath(filePath)
    await sessionViewModel.updateProfile({ 'avatar': filePath, 'address': this.address })
    this.getUIContext().getPromptAction().showToast({ message: '头像已更新（本地）' })
  }

  build() {
    Column() {
      HeaderComponent({ title: '编辑资料' })

      Column({ space: 12 }) {
        Stack() {
          if (this.avatarPath !== '' && !this.avatarLoadError) {
            Circle().width(80).height(80).fill(AppColor.primaryBg())
            Image('file://' + this.avatarPath)
              .width(80).height(80).borderRadius(40)
              .onError(() => { this.avatarLoadError = true })
          } else {
            Circle().width(80).height(80).fill(AppColor.primaryBg())
            Text(this.username.charAt(0).toUpperCase()).fontSize(36).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
          }
        }
        .onClick(() => { this.pickImage() })
        Text('点击更换头像').fontSize(13).fontColor(AppColor.PRIMARY)
      }
      .width('100%').alignItems(HorizontalAlign.Center).margin({ top: 8, bottom: 24 })

      Column({ space: 18 }) {
        Row() {
          Text('用户名').fontSize(15).fontColor(AppColor.textTertiary())
          Text(this.username).fontSize(16).fontColor(AppColor.textPrimary()).fontWeight(FontWeight.Medium).margin({ left: 12 })
        }.width('100%').padding({ left: 12 })

        AppInput({ label: '昵称', placeholder: '请输入昵称', value: this.nickname, onChange: (v) => { this.nickname = v } })
        AppInput({ label: '当前密码', placeholder: '修改密码时请输入当前密码', value: this.oldPassword, type: InputType.Password, onChange: (v) => { this.oldPassword = v } })
        AppInput({ label: '新密码', placeholder: '留空则不修改', value: this.password, type: InputType.Password, onChange: (v) => { this.password = v } })
        AppInput({ label: '收货地址', placeholder: '请输入收货地址', value: this.address, onChange: (v) => { this.address = v } })
      }
      .width('88%')

      AppButton({ text: '保存', type: AppButtonType.PRIMARY, buttonOnClick: async () => {
        if (this.password !== '') {
          if (this.oldPassword === '') {
            this.getUIContext().getPromptAction().showToast({ message: '修改密码请输入当前密码' })
            return
          }
          if (this.password.length < AppConstants.PASSWORD_MIN_LENGTH) {
            this.getUIContext().getPromptAction().showToast({ message: '密码至少6位' })
            return
          }
        }
        let params: Record<string, Object> = {
          'address': this.address,
          'nickname': this.nickname,
          'avatarColor': this.avatarColor,
          'avatar': this.avatarPath
        }
        if (this.password !== '') {
          params['password'] = this.password
          params['oldPassword'] = this.oldPassword
        }
        let ok = await sessionViewModel.updateProfile(params)
        if (ok) {
          this.getUIContext().getPromptAction().showToast({ message: '修改成功！' })
          AppRouter.back()
        } else {
          this.getUIContext().getPromptAction().showToast({ message: '修改失败' })
        }
      } })

      Blank().layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
    PageTransitionExit({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
  }
}
