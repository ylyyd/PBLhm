import { AppColor, AppShadow } from '../common/StyleConstants'

export enum TabPage {
  HOME,
  CART,
  PROFILE,
}

@Component
export struct BottomTab {
  @Prop activeTab: TabPage = TabPage.HOME
  @Prop cartCount: number = 0
  onTabChange?: (tab: TabPage) => void

  build() {
    Row() {
      Column({ space: 3 }) {
        Image($rawfile(this.activeTab === TabPage.HOME ? 'home_filled.svg' : 'home_outline.svg')).width(24).height(24)
        Text('首页').fontSize(11)
          .fontColor(this.activeTab === TabPage.HOME ? AppColor.PRIMARY : AppColor.textTertiary())
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.onTabChange?.(TabPage.HOME)
      })

      Column({ space: 3 }) {
        Stack() {
          Image($rawfile(this.activeTab === TabPage.CART ? 'cart_filled.svg' : 'cart_outline.svg')).width(24).height(24)
          if (this.cartCount > 0) {
            Circle().width(16).height(16).fill(AppColor.CANCEL).position({ x: 14, y: -6 })
            Text(this.cartCount > 99 ? '99+' : this.cartCount.toString())
              .fontSize(9).fontColor(AppColor.WHITE).fontWeight(FontWeight.Bold)
              .position({ x: 14, y: -6 }).width(16).height(16).textAlign(TextAlign.Center).lineHeight(16)
          }
        }.width(24).height(24)
        Text('购物车').fontSize(11)
          .fontColor(this.activeTab === TabPage.CART ? AppColor.PRIMARY : AppColor.textTertiary())
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.onTabChange?.(TabPage.CART)
      })

      Column({ space: 3 }) {
        Image($rawfile(this.activeTab === TabPage.PROFILE ? 'profile_filled.svg' : 'profile_outline.svg')).width(24).height(24)
        Text('我的').fontSize(11)
          .fontColor(this.activeTab === TabPage.PROFILE ? AppColor.PRIMARY : AppColor.textTertiary())
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.onTabChange?.(TabPage.PROFILE)
      })
    }
    .width('100%').height(60).backgroundColor(AppColor.cardBg()).padding({ bottom: 6 })
    .shadow(AppShadow.top())
  }
}
