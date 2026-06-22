import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { browseHistoryRepository } from '../data/repository/BrowseHistoryRepository'
import { orderViewModel } from '../viewmodel/OrderViewModel'
import { reviewRepository } from '../data/repository/ReviewRepository'
import { addressRepository } from '../data/repository/AddressRepository'
import { Address } from '../data/model/AddressModel'
import { AppRouter } from '../common/AppRouter'
import { TabPage } from '../components/BottomTab'

import { OrderStatusValue } from '../common/Constants'
import { AppColor, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppInput } from '../components/AppInput'
import { AppContainer } from '../components/AppContainer'
import { BackButton, LoadingView, EmptyView } from '../components/StatusViews'
import { messageViewModel } from '../viewmodel/MessageViewModel'
import { Logger } from '../common/Logger'
import { ConfirmDialog } from '../components/DialogComponent'

@Component
export struct ProfileContent {
  switchTab?: (tab: TabPage) => void
  @Prop @Watch('onProfileKeyChange') profileKey: number = 0
  @State username: string = ''
  @State nickname: string = ''
  @State address: string = ''
  @State points: number = 0
  @State memberLevel: number = 0
  @State memberLevelName: string = ''
  @State orderCount: number = 0
  @State avatarColor: string = AppColor.PRIMARY
  @State avatarPath: string = ''
  @State avatarLoadError: boolean = false
  @State pendingPayCount: number = 0
  @State pendingReviewCount: number = 0
  @State pendingShipCount: number = 0
  @State shippingCount: number = 0
  @State completedCount: number = 0
  @State refundCount: number = 0
  @State addresses: Address[] = []
  @State showAddressPicker: boolean = false
  @State selectedAddressId: number = 0
  @State loadingAddresses: boolean = false
  @State unreadMessageCount: number = 0
  @State browseHistoryCount: number = 0
  private logoutDialog: CustomDialogController | null = null
  async refreshProfile(): Promise<void> {
    // 先刷新订单数据，否则 orders 可能为空或过期
    await orderViewModel.refresh()
    let user = sessionViewModel.currentUser
    if (user) {
      this.username = user.username
      this.nickname = user.nickname || user.username
      this.address = user.address || ''
      this.points = user.points
      this.memberLevel = user.memberLevel
      this.memberLevelName = user.memberLevelName
      this.avatarColor = user.avatarColor
      this.avatarPath = user.avatarPath
      this.avatarLoadError = false
    }
    this.orderCount = orderViewModel.orders.length
    this.pendingPayCount = orderViewModel.orders.filter(o => o.status === OrderStatusValue.PENDING_PAYMENT).length
    this.pendingReviewCount = await this.countPendingReviews()
    this.pendingShipCount = orderViewModel.orders.filter(o => o.status === OrderStatusValue.PENDING_SHIP).length
    this.shippingCount = orderViewModel.orders.filter(o => o.status === OrderStatusValue.SHIPPING).length
    this.completedCount = orderViewModel.orders.filter(o => o.status === OrderStatusValue.COMPLETED).length
    this.refundCount = orderViewModel.orders.filter(o => o.status === OrderStatusValue.REFUNDING || o.status === OrderStatusValue.REFUNDED).length
    await messageViewModel.loadUnreadCount()
    this.unreadMessageCount = messageViewModel.unreadCount
    try {
      await browseHistoryRepository.load()
      this.browseHistoryCount = browseHistoryRepository.getAll().length
    } catch (err) {
      Logger.error('Profile.loadData browseHistory failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async countPendingReviews(): Promise<number> {
    let count = 0
    let user = sessionViewModel.currentUser
    if (!user) return 0
    let reviewed = await reviewRepository.getUserReviews(user.username)
    let reviewedIds: Set<number> = new Set()
    for (let r of reviewed) {
      reviewedIds.add(r.productId)
    }
    let seen: Set<string> = new Set()
    for (let o of orderViewModel.orders) {
      if (o.status !== OrderStatusValue.COMPLETED) continue
      for (let ci of o.items) {
        let key = o.orderNumber + '_' + ci.productId
        if (seen.has(key)) continue
        seen.add(key)
        if (!reviewedIds.has(ci.productId)) {
          count++
        }
      }
    }
    return count
  }

  async aboutToAppear(): Promise<void> {
    await this.refreshProfile()
    await this.loadAddresses()
  }

  async onPageShow(): Promise<void> {
    await this.refreshProfile()
    await this.loadAddresses()
  }

  async onProfileKeyChange(): Promise<void> {
    await this.refreshProfile()
    await this.loadAddresses()
  }

  async loadAddresses(): Promise<void> {
    this.loadingAddresses = true
    this.addresses = await addressRepository.getAddresses()
    if (this.addresses.length > 0) {
      let lastAddrId = await sessionViewModel.getLastSelectedAddressId()
      let lastMatch = lastAddrId > 0 ? this.addresses.find(a => a.id === lastAddrId) : undefined
      if (lastMatch) {
        this.address = lastMatch.detail
        this.selectedAddressId = lastMatch.id
      } else {
        let def = this.addresses.find(a => a.isDefault) || this.addresses[0]
        if (def) {
          this.address = def.detail
          this.selectedAddressId = def.id
        }
      }
    }
    this.loadingAddresses = false
  }

  async selectAddress(addr: Address): Promise<void> {
    this.address = addr.detail
    this.selectedAddressId = addr.id
    this.showAddressPicker = false
    await sessionViewModel.setLastSelectedAddress(addr)
    let user = sessionViewModel.currentUser
    if (user) {
      user.address = addr.detail
      try {
        await sessionViewModel.updateProfile({ 'address': addr.detail })
      } catch (_e) {
        Logger.error('selectAddress updateProfile failed')
      }
    }
  }

  confirmLogout(): void {
    this.logoutDialog = new CustomDialogController({
      builder: ConfirmDialog({
        title: '确认退出',
        message: '确定要退出登录吗？',
        onConfirm: () => { sessionViewModel.logout().then(() => { AppRouter.goToLogin() }) }
      }),
      autoCancel: true,
      customStyle: true,
      maskColor: 'rgba(0, 0, 0, 0.35)'
    })
    this.logoutDialog.open()
  }

  maskPhone(phone: string): string {
    if (phone.length === 11) {
      return phone.substring(0, 3) + '****' + phone.substring(7)
    }
    return phone
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          Column() {
            // ── Avatar + Name (horizontal) + Settings ──
            Row() {
              Stack() {
                if (this.avatarPath !== '' && !this.avatarLoadError) {
                  Circle().width(56).height(56).fill(AppColor.primaryBg())
                  Image('file://' + this.avatarPath)
                    .width(50).height(50).borderRadius(25)
                    .onError(() => { this.avatarLoadError = true })
                } else {
                  Circle().width(56).height(56).fill(AppColor.primaryBg())
                  Text(this.username.charAt(0).toUpperCase())
                    .fontSize(24).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                }
              }
              .onClick(() => { AppRouter.goToPersonalInfo() })

              Column({ space: 4 }) {
                Row({ space: 8 }) {
                  Text(this.nickname).fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
                  Text(this.memberLevelName).fontSize(10).fontColor(AppColor.PRIMARY)
                    .backgroundColor(AppColor.primaryBg()).borderRadius(4).padding({ left: 5, right: 5, top: 1, bottom: 1 })
                }
                .alignItems(VerticalAlign.Center)

                Row({ space: 6 }) {
                  Image($rawfile('ic_location.svg')).width(12).height(12)
                  Text((this.address || '选择收货地址')).fontSize(12).fontColor(AppColor.textTertiary())
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .layoutWeight(1).margin({ left: 12 }).alignItems(HorizontalAlign.Start)

              Image($rawfile('ic_settings.svg')).width(22).height(22).opacity(0.5)
                .onClick(() => { AppRouter.goToSettings() })
            }
            .width('100%').padding({ left: 16, right: 16, top: 24, bottom: 16 })
            .onClick(() => { this.loadAddresses(); this.showAddressPicker = true })

            // ── Divider ──
            Line().width('92%').alignSelf(ItemAlign.Center).height(0.5).backgroundColor(AppColor.divider())

            // ── Stats: text-only 5-col row ──
            Row() {
              OrderStatCell({ count: this.pendingPayCount.toString(), label: '待付款',
                onTap: () => { AppRouter.goToOrderHistory('待付款') } })
              OrderStatCell({ count: this.pendingShipCount.toString(), label: '待发货',
                onTap: () => { AppRouter.goToOrderHistory('待发货') } })
              OrderStatCell({ count: this.shippingCount.toString(), label: '待收货',
                onTap: () => { AppRouter.goToOrderHistory('待收货') } })
              OrderStatCell({ count: this.completedCount.toString(), label: '已完成',
                onTap: () => { AppRouter.goToOrderHistory('已完成') } })
              OrderStatCell({ count: this.refundCount.toString(), label: '售后',
                onTap: () => { AppRouter.goToAfterSalesList() } })
            }
            .width('100%').padding({ top: 14, bottom: 14 })
          }
          .width('92%').backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
          .shadow(AppShadow.mid())
          .margin({ top: -16 })

        Column({ space: 8 }) {
          ProfileMenuRow({
            iconSrc: $rawfile('ic_star.svg'),
            title: '我的评价', desc: this.pendingReviewCount > 0 ? this.pendingReviewCount + '件商品待评价' : '查看我的评价',
            onTap: () => { AppRouter.goToMyReviews() }
          })
          ProfileMenuRow({
            iconSrc: $rawfile('ic_heart.svg'),
            title: '我的收藏', desc: '查看收藏的商品',
            onTap: () => { AppRouter.goToFavorites() }
          })
          ProfileMenuRow({
            iconSrc: $rawfile('ic_message.svg'),
            title: '消息中心',
            desc: this.unreadMessageCount > 0 ? this.unreadMessageCount + '条未读' : '查看消息',
            badge: this.unreadMessageCount,
            onTap: () => { AppRouter.goToMessageCenter() }
          })
          ProfileMenuRow({
            iconSrc: $rawfile('ic_clock.svg'),
            title: '浏览记录', desc: this.browseHistoryCount + '件商品',
            onTap: () => { AppRouter.goToBrowseHistory() }
          })
          ProfileMenuRow({
            iconSrc: $rawfile('ic_settings_primary.svg'),
            title: '更多设置', desc: '账户安全、主题等',
            onTap: () => { AppRouter.goToSettings() }
          })
          if (sessionViewModel.currentUser?.isAdmin) {
            ProfileMenuRow({
              iconSrc: $rawfile('ic_settings_primary.svg'),
              title: '管理后台', desc: '商品管理、订单管理',
              onTap: () => { AppRouter.goToAdminDashboard() }
            })
          }
        }
        .width('92%').margin({ top: 16 })

        Blank()

        Row() {
          Text('退出登录').fontSize(14).fontColor(AppColor.textTertiary())
            .padding({ top: 16, bottom: 16 })
        }
        .width('100%').justifyContent(FlexAlign.Center)
        .onClick(() => { this.confirmLogout() })
        .hoverEffect(HoverEffect.Scale)
        }
        .width('100%').backgroundColor(AppColor.bg()).padding({ bottom: 16 })
    }
      .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)

      if (this.showAddressPicker) {
        Column() {
          Column({ space: 12 }) {
            Text('选择收货地址').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
            // 内容区统一用 layoutWeight 撑满，关闭按钮永远在最底部
            if (this.loadingAddresses) {
              LoadingView({ message: '加载地址中...' })
                .layoutWeight(1).width('100%')
            } else if (this.addresses.length === 0) {
              Column({ space: 16 }) {
                EmptyView({ message: '暂无收货地址', icon: $rawfile('ic_location.svg') })
                AppButton({ text: '去创建地址', type: AppButtonType.PRIMARY, buttonHeight: 44,
                  buttonOnClick: () => {
                    this.showAddressPicker = false
                    AppRouter.goToAddressManagement()
                  } })
              }
              .width('100%').alignItems(HorizontalAlign.Center)
              .layoutWeight(1).justifyContent(FlexAlign.Center)
            } else {
              Column() {
                Scroll() {
                  Column() {
                    ForEach(this.addresses, (addr: Address) => {
                      Row() {
                        Column({ space: 4 }) {
                          Row({ space: 8 }) {
                            Text(addr.label).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
                            Text(addr.recipientName).fontSize(13).fontColor(AppColor.textSecondary())
                            Text(this.maskPhone(addr.phone)).fontSize(13).fontColor(AppColor.textTertiary())
                          }
                          .width('100%')
                          Text(addr.detail).fontSize(13).fontColor(AppColor.textSecondary()).width('100%')
                            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                        .layoutWeight(1).alignItems(HorizontalAlign.Start)
                        if (addr.isDefault) {
                          Text('默认').fontSize(11).fontColor(AppColor.WHITE).backgroundColor(AppColor.PRIMARY)
                            .borderRadius(4).padding({ left: 6, right: 6, top: 2, bottom: 2 }).margin({ left: 8 })
                        }
                        if (addr.id === this.selectedAddressId) {
                          Stack() {
                            Circle().width(24).height(24).fill(AppColor.PRIMARY)
                            Image($rawfile('ic_check.svg')).width(16).height(16)
                          }.margin({ left: 8 })
                        }
                      }
                      .width('100%').padding({ top: 12, bottom: 12 })
                      .onClick(() => { this.selectAddress(addr) })
                      if (addr !== this.addresses[this.addresses.length - 1]) {
                        Line().width('100%').height(0.5).backgroundColor(AppColor.divider())
                      }
                    }, (addr: Address) => addr.id.toString())
                  }
                  .width('100%')
                }
                .layoutWeight(1).width('100%').scrollBar(BarState.Off)
                AppButton({ text: '管理地址', type: AppButtonType.TEXT, buttonHeight: 40,
                  buttonOnClick: () => {
                    this.showAddressPicker = false
                    AppRouter.goToAddressManagement()
                  } })
                  .margin({ top: 8 })
              }
              .layoutWeight(1).width('100%')
            }
            AppButton({ text: '关闭', type: AppButtonType.TEXT, fontColor: AppColor.textTertiary(), buttonHeight: 44, buttonOnClick: () => { this.showAddressPicker = false } })
          }
          .width('80%').constraintSize({ maxHeight: '65%' }).padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
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

@Component
struct OrderStatCell {
  @Prop count: string = '0'
  @Prop label: string = ''
  onTap: () => void = () => {}

  build() {
    Column({ space: 2 }) {
      Text(this.count).fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.PRIMARY)
      Text(this.label).fontSize(11).fontColor(AppColor.textTertiary())
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Center)
    .onClick(() => { this.onTap() })
    .hoverEffect(HoverEffect.Scale)
  }
}

@Component
struct ProfileMenuRow {
  @Prop iconSrc: Resource = $rawfile('ic_star.svg')
  @Prop title: string = ''
  @Prop desc: string = ''
  @Prop badge: number = 0
  onTap: () => void = () => {}

  build() {
    Row() {
      Stack() {
        Circle().width(30).height(30).fill(AppColor.primaryBg())
        Image(this.iconSrc).width(16).height(16)
      }.margin({ right: 12 })
      Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
      if (this.badge > 0) {
        Text(this.badge.toString())
          .fontSize(11).fontColor(AppColor.WHITE).backgroundColor(AppColor.CANCEL)
          .borderRadius(10).padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ left: 6 })
      }
      Text(this.desc).fontSize(13).fontColor(AppColor.textDisabledLight()).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).margin({ left: 8, right: 8 })
      Image($rawfile('ic_chevron_right_primary.svg')).width(18).height(18)
    }
    .width('100%').padding({ left: 16, right: 20, top: 14, bottom: 14 })
    .backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
    .shadow(AppShadow.mid())
    .onClick(() => { this.onTap() })
    .hoverEffect(HoverEffect.Scale)
  }
}
