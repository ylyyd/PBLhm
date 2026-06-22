import { Review } from '../data/model/ProductModel'
import { reviewRepository } from '../data/repository/ReviewRepository'
import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { orderViewModel } from '../viewmodel/OrderViewModel'
import { AppColor, AppRadius, AppButton } from '../common/StyleConstants'
import { OrderStatusValue } from '../common/Constants'

@Component
struct StarRating {
  @Prop rating: number = 5
  starSize: number = 14
  color: string = AppColor.PRIMARY

  build() {
    Row({ space: 2 }) {
      ForEach([1, 2, 3, 4, 5], (i: number) => {
        Text(i <= this.rating ? '★' : '☆')
          .fontSize(this.starSize).fontColor(i <= this.rating ? this.color : AppColor.border())
      }, (i: number) => i.toString())
    }
  }
}

@Component
struct StarSelector {
  @Prop current: number = 5
  onChange?: (rating: number) => void

  build() {
    Row({ space: 6 }) {
      ForEach([1, 2, 3, 4, 5], (i: number) => {
        Text(i <= this.current ? '★' : '☆')
          .fontSize(28).fontColor(i <= this.current ? AppColor.PRIMARY : AppColor.border())
          .onClick(() => { this.onChange?.(i) })
      }, (i: number) => i.toString())
    }
  }
}

@Component
struct ReviewItem {
  @Prop review: Review = new Review()
  @Prop isOwn: boolean = false
  onDelete?: () => void

  build() {
    Column() {
      Row({ space: 10 }) {
        Circle().width(36).height(36).fill(AppColor.primaryBg())
        Text(this.review.username.charAt(0).toUpperCase())
          .fontSize(16).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
        Column({ space: 2 }) {
          Row({ space: 8 }) {
            Text(this.review.username).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
            StarRating({ rating: this.review.rating, starSize: 12, color: AppColor.PRIMARY })
          }
          Text(this.review.date).fontSize(11).fontColor(AppColor.textTertiary())
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.isOwn) {
          Text('删除').fontSize(12).fontColor(AppColor.CANCEL)
            .onClick(() => { this.onDelete?.() })
        }
      }.width('100%')

      Text(this.review.comment)
        .fontSize(14).fontColor(AppColor.textSecondary()).lineHeight(22).width('100%').margin({ top: 8 })

      Line().width('100%').height(0.5).backgroundColor(AppColor.divider()).margin({ top: 12 })
    }
    .width('100%').padding({ top: 12 })
  }
}

@Component
export struct ProductReviewList {
  @Prop productId: number = 0
  @Prop reviewOrderNumber: string = ''
  @Prop @Watch('onRefreshTriggerChange') refreshTrigger: number = 0

  @State reviews: Review[] = []
  @State avgRating: number = 0
  @State canReview: boolean = false
  @State alreadyReviewed: boolean = false
  @State showForm: boolean = false
  @State formRating: number = 5
  @State formComment: string = ''
  @State isSubmitting: boolean = false

  aboutToAppear(): void {
    this.loadAll()
  }

  onRefreshTriggerChange(): void {
    this.loadAll()
  }

  async loadAll(): Promise<void> {
    if (!this.productId) return
    this.reviews = await reviewRepository.getReviews(this.productId)
    this.avgRating = await reviewRepository.getAverageRating(this.productId)
    await this.checkCanReview()
  }

  async checkCanReview(): Promise<void> {
    let user = sessionViewModel.currentUser
    if (!user) { this.canReview = false; return }
    let uname: string = user.username
    let existing = this.reviews.find(r => r.username === uname)
    if (existing) {
      this.canReview = true
      this.alreadyReviewed = true
      return
    }
    for (let i = 0; i < orderViewModel.orders.length; i++) {
      let o = orderViewModel.orders[i]
      if (o.username !== user.username) continue
      if (o.status !== OrderStatusValue.COMPLETED) continue
      for (let j = 0; j < o.items.length; j++) {
        if (o.items[j].productId === this.productId) {
          this.canReview = true
          this.alreadyReviewed = false
          return
        }
      }
    }
    this.canReview = false
  }

  async submitReview(rating: number, comment: string): Promise<void> {
    let user = sessionViewModel.currentUser
    if (!user || this.isSubmitting) return
    this.isSubmitting = true
    try {
      let r = new Review()
      r.productId = this.productId
      r.username = user.username
      r.rating = rating
      r.comment = comment
      r.orderNumber = this.reviewOrderNumber
      let now = new Date()
      r.date = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0') + '-' + String(now.getDate()).padStart(2, '0')
      let errMsg = await reviewRepository.addReview(r)
      if (errMsg) {
        this.getUIContext()?.getPromptAction().showToast({ message: errMsg })
        return
      }
      this.showForm = false
      this.formComment = ''
      this.alreadyReviewed = true
      await this.loadAll()
      this.getUIContext()?.getPromptAction().showToast({ message: '评价发布成功！' })
    } finally {
      this.isSubmitting = false
    }
  }

  async deleteReview(review: Review): Promise<void> {
    await reviewRepository.deleteReview(review.productId, review.orderNumber)
    this.showForm = false
    this.formComment = ''
    this.alreadyReviewed = false
    await this.loadAll()
    this.getUIContext()?.getPromptAction().showToast({ message: '评价已删除' })
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('商品评价').fontSize(17).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
        Text('(' + this.reviews.length + '条)').fontSize(14).fontColor(AppColor.textTertiary()).margin({ left: 6 })
        Blank()
      }.width('100%')

      if (this.avgRating > 0) {
        Row({ space: 12 }) {
          Row({ space: 4 }) {
            Text('★').fontSize(22).fontColor(AppColor.PRIMARY)
            Text(this.avgRating.toString()).fontSize(24).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
          }
          Line().width(1).height(32).backgroundColor(AppColor.border())
          StarRating({ rating: Math.round(this.avgRating), starSize: 18, color: AppColor.PRIMARY })
        }
        .width('100%').padding(16).backgroundColor(AppColor.primaryBg()).borderRadius(AppRadius.MD)
      }

      if (this.canReview && !this.alreadyReviewed && !this.showForm) {
        Button('写评价')
          .width('100%').height(AppButton.PRIMARY_HEIGHT).backgroundColor(AppColor.PRIMARY).borderRadius(AppButton.PRIMARY_RADIUS)
          .fontSize(AppButton.FONT_SIZE).fontWeight(FontWeight.Bold)
          .onClick(() => { this.showForm = true })
      }

      if (this.showForm && !this.alreadyReviewed) {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text('评分').fontSize(14).fontColor(AppColor.textSecondary()).width('100%')
            StarSelector({ current: this.formRating, onChange: (r: number) => { this.formRating = r } })
          }.width('100%')

          Column({ space: 6 }) {
            Text('评价内容').fontSize(14).fontColor(AppColor.textSecondary()).width('100%')
            TextArea({ placeholder: '说说你的使用感受...', text: this.formComment })
              .onChange((v: string) => { this.formComment = v })
              .height(100).backgroundColor(AppColor.inputBg()).borderRadius(AppRadius.MD).padding(12).fontSize(15)
          }.width('100%')

          Row({ space: 12 }) {
            Button('取消').height(AppButton.PRIMARY_HEIGHT).backgroundColor(AppColor.divider()).fontColor(AppColor.textSecondary()).borderRadius(AppButton.PRIMARY_RADIUS)
              .layoutWeight(1).fontSize(AppButton.FONT_SIZE)
              .onClick(() => { this.showForm = false; this.formComment = '' })
            Button('提交评价').height(AppButton.PRIMARY_HEIGHT)
              .backgroundColor(this.isSubmitting ? AppColor.textDisabledLight() : AppColor.PRIMARY).borderRadius(AppButton.PRIMARY_RADIUS)
              .layoutWeight(1).fontSize(AppButton.FONT_SIZE).fontWeight(FontWeight.Bold)
              .enabled(this.formComment.trim().length > 0 && !this.isSubmitting)
              .stateEffect(true)
              .onClick(() => { this.submitReview(this.formRating, this.formComment) })
          }.width('100%')
        }
        .width('100%').padding(16).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
        .border({ width: 1, color: AppColor.PRIMARY, style: BorderStyle.Solid })
      }

      if (this.canReview && this.alreadyReviewed) {
        Row() {
          Text('✓ 你已经评价过该商品').fontSize(14).fontColor(AppColor.SUCCESS)
        }.width('100%').padding({ top: 8, bottom: 8 })
      }

      ForEach(this.reviews, (review: Review) => {
        ReviewItem({
          review: review,
          isOwn: review.username === sessionViewModel.currentUser?.username,
          onDelete: () => { this.deleteReview(review) }
        })
      }, (review: Review, index: number) => review.username + '_' + review.date + index.toString())
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }
}
