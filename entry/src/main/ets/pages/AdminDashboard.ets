import { AppRouter } from '../common/AppRouter'
import { adminRepository } from '../data/repository/AdminRepository'
import { AppColor, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'

import { HeaderComponent } from '../components/HeaderComponent'
import { LoadingView } from '../components/StatusViews'

@Entry
@Component
struct AdminDashboard {
  @State productCount: number = 0
  @State orderCount: number = 0
  @State userCount: number = 0
  @State revenue: number = 0
  @State isLoading: boolean = true

  async aboutToAppear(): Promise<void> {
    await this.loadData()
  }

  async onPageShow(): Promise<void> {
    await this.loadData()
  }

  async loadData(): Promise<void> {
    this.isLoading = true
    let d = await adminRepository.getDashboard()
    this.productCount = d.productCount
    this.orderCount = d.orderCount
    this.userCount = d.userCount
    this.revenue = d.revenue
    this.isLoading = false
  }

  build() {
    Column() {
      HeaderComponent({ title: '管理后台' })

      if (this.isLoading) {
        LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Row({ space: 12 }) {
              StatCard({ label: '商品', value: this.productCount.toString(), color: AppColor.SUCCESS })
              StatCard({ label: '订单', value: this.orderCount.toString(), color: AppColor.PRIMARY })
              StatCard({ label: '用户', value: this.userCount.toString(), color: AppColor.statusBlue() })
            }.width('100%')

            Row({ space: 12 }) {
              StatCard({ label: '总收入', value: '¥' + this.revenue.toFixed(0), color: AppColor.statusPink() })
            }.width('100%')

            Column({ space: 10 }) {
              Text('管理功能').fontSize(16).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary()).width('100%')

              Column() {
                AppButton({ text: '商品管理', type: AppButtonType.TEXT,
                  buttonWidth: '100%', buttonHeight: 56,
                  fontSize: 16, fontWeight: FontWeight.Medium,
                  buttonOnClick: () => { AppRouter.goToAdminProducts() } })
              }
                .width('100%').backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
                .shadow(AppShadow.mid())

              Column() {
                AppButton({ text: '分类管理', type: AppButtonType.TEXT,
                  buttonWidth: '100%', buttonHeight: 56,
                  fontSize: 16, fontWeight: FontWeight.Medium,
                  buttonOnClick: () => { AppRouter.goToAdminCategories() } })
              }
                .width('100%').backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
                .shadow(AppShadow.mid())

              Column() {
                AppButton({ text: '订单管理', type: AppButtonType.TEXT,
                  buttonWidth: '100%', buttonHeight: 56,
                  fontSize: 16, fontWeight: FontWeight.Medium,
                  buttonOnClick: () => { AppRouter.goToAdminOrders() } })
              }
                .width('100%').backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
                .shadow(AppShadow.mid())
            }
            .width('100%').padding(16).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.PILL)
            .shadow(AppShadow.mid())
          }
          .width('92%').padding({ bottom: 24 })
        }
        .layoutWeight(1).width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn }).opacity(0)
    PageTransitionExit({ duration: 250, curve: Curve.FastOutLinearIn }).opacity(0)
  }
}

@Component
struct StatCard {
  @Prop label: string = ''
  @Prop value: string = ''
  @Prop color: string = AppColor.SUCCESS

  build() {
    Column() {
      Text(this.value).fontSize(26).fontWeight(FontWeight.Bold).fontColor(this.color)
      Text(this.label).fontSize(13).fontColor(AppColor.textTertiary()).margin({ top: 4 })
    }
    .layoutWeight(1).padding(16).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD).alignItems(HorizontalAlign.Center)
    .shadow(AppShadow.mid())
  }
}
