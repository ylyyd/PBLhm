import { Address } from '../data/model/AddressModel'
import { addressRepository } from '../data/repository/AddressRepository'
import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { AppRouter } from '../common/AppRouter'

import { HeaderComponent } from '../components/HeaderComponent'
import { EmptyView, LoadingView } from '../components/StatusViews'
import { AppColor, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppInput } from '../components/AppInput'
import { AppButton, AppButtonType } from '../components/AppButton'
import { ConfirmDialog } from '../components/DialogComponent'

// 地址卡片子组件 — @ObjectLink 确保 @Observed Address 属性变更后 UI 正确刷新
@Component
struct AddressCard {
  @ObjectLink addr: Address
  lastSelectedAddrId: number = 0
  onSelect?: (addr: Address) => void
  onSetDefault?: (id: number) => void
  onEdit?: (addr: Address) => void
  onDelete?: (id: number) => void

  build() {
    // 卡片容器 — 100%撑满 ListItem，背景/圆角/阴影覆盖整行
    Column() {
      // 内容区域 — 左对齐
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(this.addr.label)
            .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
          if (this.addr.isDefault) {
            Text('默认').fontSize(11).fontColor(AppColor.PRIMARY).backgroundColor(AppColor.primaryBg())
              .borderRadius(4).padding({ left: 6, right: 6 })
          }
          if (this.addr.id === this.lastSelectedAddrId) {
            Text('当前已选').fontSize(10).fontColor(AppColor.WHITE)
              .backgroundColor(AppColor.SUCCESS).borderRadius(4).padding({ left: 6, right: 6 })
          }
        }
        Text((this.addr.recipientName ? this.addr.recipientName : '') + '  ' + (this.addr.phone ? this.addr.phone : ''))
          .fontSize(14).fontColor(AppColor.textPrimary()).lineHeight(20)
        Text(this.addr.detail)
          .fontSize(14).fontColor(AppColor.textSecondary()).lineHeight(20)

        // 操作按钮组
        Row() {
          if (!this.addr.isDefault) {
            AppButton({ text: '设为默认', type: AppButtonType.TEXT, buttonOnClick: () => { this.onSetDefault?.(this.addr.id) } })
          }
          AppButton({ text: '编辑', type: AppButtonType.TEXT, buttonOnClick: () => { this.onEdit?.(this.addr) } })
            .margin({ left: 16 })
          AppButton({ text: '删除', type: AppButtonType.TEXT, fontColor: AppColor.CANCEL, buttonOnClick: () => { this.onDelete?.(this.addr.id) } })
            .margin({ left: 16 })
        }
        .width('100%').alignItems(VerticalAlign.Center)
      }
      .width('100%').padding({ left: 18, right: 18, top: 16, bottom: 16 })
      .alignItems(HorizontalAlign.Start) // ← 关键：所有文字左对齐
    }
    .width('100%') // ← 撑满 ListItem
    .borderRadius(14)
    .backgroundColor(this.addr.id === this.lastSelectedAddrId ? AppColor.primaryBg() : AppColor.cardBg())
    .border({ width: this.addr.id === this.lastSelectedAddrId ? 1.5 : 0, color: AppColor.PRIMARY, style: BorderStyle.Solid })
    .shadow({ radius: this.addr.id === this.lastSelectedAddrId ? 8 : 2, color: this.addr.id === this.lastSelectedAddrId ? AppColor.PRIMARY_ALPHA : AppColor.shadowLight(), offsetY: 2 })
    .onClick(() => { this.onSelect?.(this.addr) })
    .hoverEffect(HoverEffect.Scale)
  }
}

@Entry
@Component
struct AddressManagement {
  @State addressList: Address[] = []
  @State showAddPanel: boolean = false
  @State editLabel: string = ''
  @State editRecipientName: string = ''
  @State editPhone: string = ''
  @State editDetail: string = ''
  @State editIsDefault: boolean = false
  @State editingId: number = 0
  @State lastSelectedAddrId: number = 0
  @State isLoading: boolean = true
  @State refreshKey: number = 0

  async aboutToAppear(): Promise<void> {
    this.isLoading = true
    this.lastSelectedAddrId = await sessionViewModel.getLastSelectedAddressId()
    await this.refresh()
    this.isLoading = false
  }

  async onPageShow(): Promise<void> {
    this.lastSelectedAddrId = await sessionViewModel.getLastSelectedAddressId()
    await this.refresh()
  }

  async refresh(): Promise<void> {
    let list = await addressRepository.getAddresses()
    this.addressList = list
    this.lastSelectedAddrId = await sessionViewModel.getLastSelectedAddressId()
    this.refreshKey++
  }

  startAdd(): void {
    this.editingId = 0
    this.editLabel = ''
    this.editRecipientName = ''
    this.editPhone = ''
    this.editDetail = ''
    this.editIsDefault = false
    this.showAddPanel = true
  }

  startEdit(addr: Address): void {
    this.editingId = addr.id
    this.editLabel = addr.label
    this.editRecipientName = addr.recipientName
    this.editPhone = addr.phone
    this.editDetail = addr.detail
    this.editIsDefault = addr.isDefault
    this.showAddPanel = true
  }

  cancelEdit(): void {
    this.showAddPanel = false
  }

  async saveAddress(): Promise<void> {
    if (!this.editLabel.trim() || !this.editRecipientName.trim() || !this.editPhone.trim() || !this.editDetail.trim()) {
      this.getUIContext().getPromptAction().showToast({ message: '请填写完整信息' })
      return
    }
    if (!/^1\d{10}$/.test(this.editPhone.trim())) {
      this.getUIContext().getPromptAction().showToast({ message: '手机号格式不正确' })
      return
    }
    if (this.editDetail.trim().length < 5) {
      this.getUIContext().getPromptAction().showToast({ message: '详细地址至少5个字' })
      return
    }
    try {
      if (this.editingId === 0) {
        let addr = new Address()
        addr.label = this.editLabel.trim()
        addr.recipientName = this.editRecipientName.trim()
        addr.phone = this.editPhone.trim()
        addr.detail = this.editDetail.trim()
        addr.isDefault = this.editIsDefault
        await addressRepository.addAddress(addr)
      } else {
        let addr = new Address()
        addr.id = this.editingId
        addr.label = this.editLabel.trim()
        addr.recipientName = this.editRecipientName.trim()
        addr.phone = this.editPhone.trim()
        addr.detail = this.editDetail.trim()
        addr.isDefault = this.editIsDefault
        await addressRepository.updateAddress(addr)
      }
      this.showAddPanel = false
      await this.refresh()
      // debug: 验证数据加载结果
      if (this.addressList.length > 0) {
        this.getUIContext().getPromptAction().showToast({ message: '已加载 ' + this.addressList.length + ' 个地址' })
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '地址列表为空' })
      }
    } catch (err) {
      let msg = '保存失败'
      if (err instanceof Error) msg = msg + ': ' + err.message
      this.getUIContext().getPromptAction().showToast({ message: msg })
    }
  }

  async deleteAddress(id: number): Promise<void> {
    let addrId = id
    let dialog = new CustomDialogController({
      builder: ConfirmDialog({
        title: '删除地址',
        message: '确定要删除该地址吗？',
        onConfirm: () => {
          addressRepository.deleteAddress(addrId).then(async () => {
            await this.refresh()
          })
        }
      }),
      autoCancel: true,
      customStyle: false
    })
    dialog.open()
  }

  async selectAddress(addr: Address): Promise<void> {
    await sessionViewModel.setLastSelectedAddress(addr)
    AppRouter.back()
  }

  isSelectedAddress(addr: Address): boolean {
    return addr.id === this.lastSelectedAddrId
  }

  async setDefault(id: number): Promise<void> {
    try {
      await addressRepository.setDefault(id)
      await this.refresh()
      AppRouter.back()
    } catch (_) {
      this.getUIContext().getPromptAction().showToast({ message: '设置默认地址失败' })
    }
  }

  build() {
    // 纯 Column 布局：内容占满(layoutWeight)，底部按钮固定，不覆盖内容
    Column() {
      HeaderComponent({ title: '地址管理' })

      // 主内容区 — 撑满剩余空间
      if (this.isLoading) {
        LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
      } else if (this.showAddPanel) {
        Scroll() {
          // 居中容器：88% 宽度表单卡片在 Scroll 中水平居中
          Column() {
            Column({ space: 16 }) {
              AppInput({ label: '标签', placeholder: '如：家、公司、学校', value: this.editLabel, onChange: (v) => { this.editLabel = v } })
              AppInput({ label: '收货人', placeholder: '请输入收货人姓名', value: this.editRecipientName, onChange: (v) => { this.editRecipientName = v } })
              AppInput({ label: '手机号', placeholder: '请输入手机号', value: this.editPhone, onChange: (v) => { this.editPhone = v } })
              AppInput({ label: '详细地址', placeholder: '请输入详细地址', value: this.editDetail, onChange: (v) => { this.editDetail = v } })
              Row({ space: 12 }) {
                Toggle({ type: ToggleType.Checkbox, isOn: this.editIsDefault })
                  .onChange((v: boolean) => { this.editIsDefault = v })
                Text('设为默认地址').fontSize(15).fontColor(AppColor.textPrimary())
                Blank()
              }.width('100%')
              Row({ space: 12 }) {
                Column() {
                  AppButton({ text: '取消', type: AppButtonType.SECONDARY, buttonWidth: '100%', buttonHeight: 48, buttonOnClick: () => { this.cancelEdit() } })
                }.layoutWeight(1)
                Column() {
                  AppButton({ text: '保存', type: AppButtonType.PRIMARY, buttonWidth: '100%', buttonHeight: 48, buttonOnClick: async () => { await this.saveAddress() } })
                }.layoutWeight(1)
              }.width('100%').height(48)
            }
            .width('100%').padding(20).backgroundColor(AppColor.cardBg()).borderRadius(14)
            .shadow(AppShadow.mid())
          }
          .width('92%').alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      } else if (this.addressList.length === 0) {
        Column() {
          EmptyView({ message: '暂无地址', icon: $rawfile('ic_location.svg') })
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          List({ space: 12 }) {
            ForEach(this.addressList, (addr: Address) => {
              ListItem() {
                AddressCard({
                  addr: addr,
                  lastSelectedAddrId: this.lastSelectedAddrId,
                  onSelect: (a) => { this.selectAddress(a) },
                  onSetDefault: (id) => { this.setDefault(id) },
                  onEdit: (a) => { this.startEdit(a) },
                  onDelete: (id) => { this.deleteAddress(id) }
                })
              }
            })
          }
          .width('100%').padding({ top: 8, left: 16, right: 16 })
        }
        .layoutWeight(1).width('100%')
      }

      // 底部添加按钮 — 加载/表单页隐藏
      if (!this.isLoading && !this.showAddPanel) {
        Column() {
          AppButton({
            text: '添加地址',
            type: AppButtonType.PRIMARY,
            buttonHeight: 48,
            buttonOnClick: () => { this.startAdd() }
          })
          .width('92%')
        }
        .width('100%')
        .padding({ top: 12, bottom: 28 })
        .alignItems(HorizontalAlign.Center)
      }
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
