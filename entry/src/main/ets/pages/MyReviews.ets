import { Order, CartItem, Review, Product } from '../data/model/ProductModel'
import { orderViewModel } from '../viewmodel/OrderViewModel'
import { orderRepository } from '../data/repository/OrderRepository'
import { reviewRepository } from '../data/repository/ReviewRepository'
import { productRepository } from '../data/repository/ProductRepository'
import { AppColor, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { ProductImage } from '../components/ProductImage'
import { AppRouter } from '../common/AppRouter'
import { OrderStatusValue } from '../common/Constants'
import { HeaderComponent } from '../components/HeaderComponent'
import { EmptyView, LoadingView } from '../components/StatusViews'
import { ConfirmDialog } from '../components/DialogComponent'

@Entry
@Component
struct MyReviews {
  private deleteDialog: CustomDialogController | null = null
  @State currentTab: number = 0
  @State reviewableItems: ReviewableItem[] = []
  @State submittedReviews: Review[] = []
  @State isLoading: boolean = true

  aboutToAppear(): void {
    this.loadData()
  }

  onPageShow(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    this.isLoading = true
    await orderRepository.load()
    this.reviewableItems = await this.getReviewableItems()
    this.submittedReviews = await this.getSubmittedReviews()
    this.isLoading = false
  }

  async getSubmittedReviews(): Promise<Review[]> {
    let user = sessionViewModel.currentUser
    if (!user) return []
    return await reviewRepository.getUserReviews(user.username)
  }

  async getReviewableItems(): Promise<ReviewableItem[]> {
    let items: ReviewableItem[] = []
    let user = sessionViewModel.currentUser
    if (!user) return items
    let reviewedKeys: string[] = await reviewRepository.getReviewHistory(user.username)
    let reviewedSet: Set<string> = new Set(reviewedKeys)
    let seen: Set<string> = new Set()
    for (let o of orderViewModel.orders) {
      if (o.status !== OrderStatusValue.COMPLETED) continue
      for (let ci of o.items) {
        let key = o.orderNumber + '_' + ci.productId
        if (seen.has(key)) continue
        seen.add(key)
        if (reviewedSet.has(key)) continue
        let item = new ReviewableItem()
        item.productId = ci.productId
        item.productName = ci.productName
        item.productImage = ci.productImage
        item.orderNumber = o.orderNumber
        items.push(item)
      }
    }
    return items
  }

  async deleteReview(review: Review): Promise<void> {
    this.deleteDialog = new CustomDialogController({
      builder: ConfirmDialog({
        title: '删除评价',
        message: '确定要删除该评价吗？',
        confirmText: '删除',
        onConfirm: () => {
          this.deleteDialog?.close()
          reviewRepository.deleteReview(review.productId, review.orderNumber).then(() => {
            this.getSubmittedReviews().then(reviews => { this.submittedReviews = reviews })
            this.getReviewableItems().then(items => { this.reviewableItems = items })
            this.getUIContext().getPromptAction().showToast({ message: '评价已删除' })
          })
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.deleteDialog.open()
  }

  build() {
    Column() {
      HeaderComponent({ title: '我的评价' })

      Row({ space: 0 }) {
        Button('待评价')
          .height(38).layoutWeight(1).padding(0)
          .backgroundColor(this.currentTab === 0 ? AppColor.PRIMARY : AppColor.divider())
          .fontSize(14).fontColor(this.currentTab === 0 ? AppColor.WHITE : AppColor.textSecondary())
          .borderRadius(0)
          .onClick(() => { this.currentTab = 0 })
        Button('已评价')
          .height(38).layoutWeight(1).padding(0)
          .backgroundColor(this.currentTab === 1 ? AppColor.PRIMARY : AppColor.divider())
          .fontSize(14).fontColor(this.currentTab === 1 ? AppColor.WHITE : AppColor.textSecondary())
          .borderRadius(0)
          .onClick(() => { this.currentTab = 1 })
      }
      .width('92%').borderRadius(19).clip(true).margin({ bottom: 8 })

      if (this.isLoading) {
        LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
      } else if (this.currentTab === 0) {
        if (this.reviewableItems.length === 0) {
          Column() {
            Blank().layoutWeight(1)
            EmptyView({ message: '暂无待评价商品', icon: $rawfile('ic_star.svg') })
            Text('去完成订单后再来评价吧').fontSize(13).fontColor(AppColor.textDisabledLight()).margin({ top: 4 })
            Blank().layoutWeight(1)
          }
          .layoutWeight(1).width('100%').alignItems(HorizontalAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.reviewableItems, (item: ReviewableItem) => {
              ListItem() {
                Row() {
                  ProductImage({ src: item.productImage })
                    .width(80).height(80).borderRadius(12)
                  Column({ space: 6 }) {
                    Text(item.productName).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text('来自订单：' + item.orderNumber.slice(-8)).fontSize(11).fontColor(AppColor.textDisabledLight())
                    AppButton({ text: '去评价', type: AppButtonType.PRIMARY, fontSize: 13, buttonHeight: 32, buttonOnClick: () => { AppRouter.goToProductDetail(item.productId, item.orderNumber) } })
                      .padding({ left: 20, right: 20 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 12 })
                }
                .padding(14).backgroundColor(AppColor.cardBg()).borderRadius(14)
                .shadow(AppShadow.mid())
                .transition(TransitionEffect.opacity(0).animation({ duration: 300, curve: Curve.EaseOut }))
                .onClick(() => { AppRouter.goToProductDetail(item.productId, item.orderNumber) })
                .hoverEffect(HoverEffect.Scale)
              }
            }, (item: ReviewableItem) => item.orderNumber + '_' + item.productId.toString())
          }
          .width('92%').layoutWeight(1).backgroundColor(AppColor.bg()).padding({ bottom: 24 })
        }
      } else {
        if (this.submittedReviews.length === 0) {
          Column() {
            Blank().layoutWeight(1)
            EmptyView({ message: '暂无已评价商品', icon: $rawfile('ic_star.svg') })
            Blank().layoutWeight(1)
          }
          .layoutWeight(1).width('100%').alignItems(HorizontalAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.submittedReviews, (review: Review) => {
              ListItem() {
                Column() {
                  Row() {
                    Circle().width(36).height(36).fill(AppColor.primaryBg())
                    Text((review.username || '?').charAt(0).toUpperCase()).fontSize(16).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                    Column({ space: 2 }) {
                      Row({ space: 8 }) {
                        Text(review.username || '匿名用户').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
                        Row({ space: 2 }) {
                          ForEach([1, 2, 3, 4, 5], (star: number) => {
                            Text(star <= review.rating ? '★' : '☆').fontSize(13).fontColor(star <= review.rating ? AppColor.PRIMARY : AppColor.textDisabledLight())
                          }, (star: number) => star.toString())
                        }
                      }.margin({ left: 10 })
                      Text(review.date || '').fontSize(11).fontColor(AppColor.textDisabledLight()).margin({ left: 10 })
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    Text('删除')
                      .fontSize(11).fontColor(AppColor.CANCEL).fontWeight(FontWeight.Medium)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .borderRadius(6).border({ width: 0.5, color: AppColor.CANCEL, style: BorderStyle.Solid })
                      .onClick(() => { this.deleteReview(review) })
                      .focusable(false)
                  }
                  .width('100%')

                  Text(review.comment || '').fontSize(14).fontColor(AppColor.textSecondary()).width('100%').lineHeight(22).margin({ top: 10 })
                }
                .padding(14).backgroundColor(AppColor.cardBg()).borderRadius(14)
                .shadow(AppShadow.mid())
                .transition(TransitionEffect.opacity(0).animation({ duration: 300, curve: Curve.EaseOut }))
                .onClick(() => { AppRouter.goToProductDetail(review.productId) })
                .hoverEffect(HoverEffect.Scale)
              }
            }, (review: Review) => review.productId.toString() + '_' + review.date + '_' + review.orderNumber)
          }
          .width('92%').layoutWeight(1).backgroundColor(AppColor.bg()).padding({ bottom: 24 })
        }
      }
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg()).justifyContent(FlexAlign.Start)
  }

  pageTransition() {
    PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
    PageTransitionExit({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
  }
}

class ReviewableItem {
  productId: number = 0
  productName: string = ''
  productImage: string = ''
  orderNumber: string = ''
}
