import { display } from '@kit.ArkUI'
import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { addressRepository } from '../data/repository/AddressRepository'
import { cartViewModel } from '../viewmodel/CartViewModel'
import { AppRouter, MainTabParams } from '../common/AppRouter'
import { AppColor, AppRadius } from '../common/StyleConstants'
import { ProductImage } from '../components/ProductImage'
import { BottomTab, TabPage } from '../components/BottomTab'
import { HomeContent } from './Home'
import { CartContent } from './Cart'
import { ProfileContent } from './Profile'

@Entry
@Component
struct MainTab {
  params: MainTabParams = new MainTabParams()
  @State activeTab: TabPage = TabPage.HOME
  @State contentX: string = '0'
  @State contentOpacity: number = 1
  @State profileKey: number = 0
  @State cartRefreshKey: number = 0
  @State cartCount: number = 0
  @State flyImage: string = ''
  @State flyShow: boolean = false
  @State flyX: number = 0
  @State flyY: number = 0
  @State flyW: number = 50
  @State flyH: number = 50
  @State flyTargetX: number = 0
  @State flyTargetY: number = 0
  @State flyOpacity: number = 1
  @State flyScale: number = 1
  @StorageLink('themeMode') themeMode: number = 0
  private tabDirection: number = 0
  private switching: boolean = false
  private windowW: number = 0
  private windowH: number = 0

  aboutToAppear(): void {
    let d = display.getDefaultDisplaySync()
    this.windowW = d.width
    this.windowH = d.height
    this.cartCount = cartViewModel.items.length
    let routerP = AppRouter.getParams<MainTabParams>()
    if (routerP) this.params = routerP
    let p = this.params
    if (p && p.tab !== undefined) {
      this.activeTab = p.tab as TabPage
    }
    if (!sessionViewModel.isLoggedIn()) {
      AppRouter.goToLogin()
    }
  }

  async syncUserAddress(): Promise<void> {
    let list = await addressRepository.getAddresses()
    let def = list.length > 0 ? (list.find(a => a.isDefault) || list[0]) : undefined
    let user = sessionViewModel.currentUser
    if (user) {
      user.address = def ? def.detail : ''
    }
  }

  onPageShow(): void {
    this.cartCount = cartViewModel.items.length
    this.cartRefreshKey++
    this.profileKey++
    this.syncUserAddress()
  }

  onCartChange(): void {
    this.cartCount = cartViewModel.items.length
  }

  handleFlyToCart(image: string, startX: number, startY: number): void {
    if (this.flyShow) return
    this.flyImage = image
    this.flyX = startX - 25
    this.flyY = startY - 25
    this.flyW = 50
    this.flyH = 50
    this.flyScale = 1
    this.flyOpacity = 1
    this.flyTargetX = this.windowW * 0.5 - 12
    this.flyTargetY = this.windowH - 30
    this.flyShow = true
    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 500, curve: Curve.FastOutLinearIn }, () => {
        this.flyX = this.flyTargetX
        this.flyY = this.flyTargetY
        this.flyW = 24
        this.flyH = 24
        this.flyScale = 0.4
        this.flyOpacity = 0.3
      })
      setTimeout(() => {
        this.flyShow = false
        this.cartCount = cartViewModel.items.length
      }, 500)
    }, 30)
  }

  switchTab(target: TabPage): void {
    if (this.switching || target === this.activeTab) return
    this.switching = true
    this.tabDirection = target - this.activeTab

    let enterX = this.tabDirection > 0 ? '100%' : '-100%'

    this.activeTab = target
    this.contentX = enterX
    this.contentOpacity = 1

    this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.contentX = '0'
    })

    setTimeout(() => {
      this.switching = false
    }, 300)
  }

  build() {
    Column() {
      Stack() {
        if (this.activeTab === TabPage.HOME) {
          HomeContent({
            switchTab: (tab: TabPage) => this.switchTab(tab),
            onCartChange: () => this.onCartChange(),
            onFlyToCart: (image: string, x: number, y: number) => this.handleFlyToCart(image, x, y)
          })
        } else if (this.activeTab === TabPage.CART) {
          CartContent({ switchTab: (tab: TabPage) => this.switchTab(tab), onCartChange: () => this.onCartChange(), cartRefreshKey: this.cartRefreshKey })
        } else if (this.activeTab === TabPage.PROFILE) {
          ProfileContent({ switchTab: (tab: TabPage) => this.switchTab(tab), profileKey: this.profileKey })
        }

        if (this.flyShow) {
          ProductImage({ src: this.flyImage })
            .width(this.flyW).height(this.flyH).borderRadius(AppRadius.SM)
            .position({ x: this.flyX, y: this.flyY })
            .scale({ x: this.flyScale, y: this.flyScale })
            .opacity(this.flyOpacity)
        }
      }
      .layoutWeight(1).width('100%').clip(true)
      .offset({ x: this.contentX })
      .opacity(this.contentOpacity)

      BottomTab({ activeTab: this.activeTab, cartCount: this.cartCount, onTabChange: (tab: TabPage) => this.switchTab(tab) })
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
