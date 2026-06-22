import { afterSalesRepository, AfterSalesItem } from '../data/repository/AfterSalesRepository'
import { orderViewModel } from '../viewmodel/OrderViewModel'
import { AppRouter, OrderDetailParams } from '../common/AppRouter'
import { AppColor, AppRadius, AppFont, AppCard } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { HeaderComponent } from '../components/HeaderComponent'
import { LoadingView } from '../components/StatusViews'
import { CartItem, Order } from '../data/model/ProductModel'
import { ProductImage } from '../components/ProductImage'
import { photoAccessHelper } from '@kit.MediaLibraryKit'

const AFTER_SALE_TYPES: string[] = ['refund', 'return', 'exchange']
const AFTER_SALE_TYPE_LABELS: Record<string, string> = { 'refund': '仅退款', 'return': '退货退款', 'exchange': '换货' }
const APPLY_REASONS: string[] = ['质量问题', '不想要了', '商品与描述不符', '发错货/漏发', '其他']
const AFTER_SALE_STATUS_LABELS: Record<string, string> = {
  'pending': '待处理', 'processing': '处理中', 'approved': '已通过',
  'rejected': '已拒绝', 'completed': '已完成', 'cancelled': '已取消'
}

function OrderStatusColor(status: string): string {
  if (status.indexOf('退款') !== -1) return AppColor.statusPink()
  if (status === '已完成') return AppColor.SUCCESS
  if (status === '已取消') return AppColor.textTertiary()
  if (status === '待付款' || status === '待发货' || status === '待收货') return AppColor.statusBlue()
  if (status === '配送中') return AppColor.PRIMARY
  return AppColor.textPrimary()
}

// 合并显示售后状态：如果订单已退款，优先展示"已退款"，否则展示售后申请状态
function EffectiveStatus(afterSale: AfterSalesItem | null): string {
  if (!afterSale) return ''
  // 订单已退款 → 显示"已退款"（用户最关心的）
  if (afterSale.currentOrderStatus === '已退款') return '已退款'
  // 已取消 → 显示"已取消"
  if (afterSale.status === 'cancelled') return '已取消'
  // 其他 → 显示售后状态标签
  return AFTER_SALE_STATUS_LABELS[afterSale.status] || afterSale.status
}

function EffectiveStatusColor(status: string): string {
  if (status === '已退款') return AppColor.statusPink()
  if (status === '已通过') return AppColor.SUCCESS
  if (status === '已拒绝' || status === '已取消') return AppColor.CANCEL
  if (status === '已完成') return AppColor.SUCCESS
  return AppColor.PRIMARY
}

@Entry
@Component
struct AfterSales {
  params: OrderDetailParams = new OrderDetailParams()
  @State afterSale: AfterSalesItem | null = null
  @State orderNumber: string = ''
  @State loading: boolean = true
  @State order: Order | null = null

  // Form fields
  @State applyType: string = 'refund'
  @State applyReason: string = ''
  @State applyDescription: string = ''
  @State showReasonSheet: boolean = false
  @State evidenceImages: string[] = []
  @State submitting: boolean = false

  async aboutToAppear(): Promise<void> {
    let routerP = AppRouter.getParams<OrderDetailParams>()
    if (routerP) this.params = routerP
    let p = this.params
    if (p) {
      this.orderNumber = p.orderNumber
    }
    await this.loadData()
  }

  async onPageShow(): Promise<void> {
    await this.loadData()
  }

  async loadData(): Promise<void> {
    this.loading = true
    let p = this.params
    if (p) {
      this.orderNumber = p.orderNumber
      // 拉订单数据（申请表单需要）
      this.order = await orderViewModel.fetchOrder(this.orderNumber)
      // 拉售后数据（含 current_order_status 实时订单状态）
      let existing = await afterSalesRepository.getByOrder(this.orderNumber)
      if (existing) {
        this.afterSale = existing
      }
    }
    this.loading = false
  }

  async doApply(): Promise<void> {
    if (!this.applyReason) {
      this.getUIContext().getPromptAction().showToast({ message: '请选择退款原因' })
      return
    }
    this.submitting = true
    let amount = this.order ? this.order.totalPrice : 0
    let productId = this.order && this.order.items.length > 0 ? this.order.items[0].productId : 0
    let ok = await afterSalesRepository.create(this.orderNumber, productId, this.applyType, this.applyReason, amount)
    if (ok) {
      this.getUIContext().getPromptAction().showToast({ message: '售后申请已提交' })
      let item = await afterSalesRepository.getByOrder(this.orderNumber)
      if (item) {
        this.afterSale = item
      }
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '提交失败，请稍后重试' })
    }
    this.submitting = false
  }

  async doCancel(): Promise<void> {
    if (!this.afterSale) return
    let ok = await afterSalesRepository.deleteRecord(this.afterSale.id)
    if (ok) {
      this.getUIContext().getPromptAction().showToast({ message: '售后申请已取消' })
      AppRouter.back()
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '取消失败' })
    }
  }

  async doDelete(): Promise<void> {
    if (!this.afterSale) return
    let ok = await afterSalesRepository.deleteRecord(this.afterSale.id)
    if (ok) {
      this.getUIContext().getPromptAction().showToast({ message: '已删除' })
      AppRouter.back()
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '删除失败' })
    }
  }

  async pickImages(): Promise<void> {
    try {
      let context = getContext(this)
      let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
      let picker = new photoAccessHelper.PhotoViewPicker()
      let result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 6 - this.evidenceImages.length
      })
      if (result && result.photoUris && result.photoUris.length > 0) {
        let newUris: string[] = []
        for (let i = 0; i < result.photoUris.length; i++) {
          newUris.push(result.photoUris[i])
        }
        this.evidenceImages = this.evidenceImages.concat(newUris)
      }
    } catch (err) {
      // user cancelled or permission denied
    }
  }

  @Builder
  ReasonSheetBuilder() {
    Column() {
      Row().width(40).height(4).backgroundColor(AppColor.textTertiary())
        .borderRadius(2).margin({ top: 8, bottom: 4 })
      Text('选择退款原因')
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
        .width('100%').textAlign(TextAlign.Start).padding({ left: 20, top: 8, bottom: 4 })

      List({ space: 0 }) {
        ForEach(APPLY_REASONS, (r: string) => {
          ListItem() {
            Row() {
              Text(r).fontSize(15).fontColor(AppColor.textPrimary())
              Blank()
              if (this.applyReason === r) {
                Text('✓').fontSize(16).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
              }
            }
            .width('100%').height(48).padding({ left: 20, right: 20 })
            .backgroundColor(this.applyReason === r ? AppColor.primaryBg() : Color.Transparent)
            .onClick(() => {
              this.applyReason = r
              this.showReasonSheet = false
            })
          }
        }, (r: string) => r)
      }
      .width('100%').height(APPLY_REASONS.length * 48 + 8)
      .borderRadius({ topLeft: 0, topRight: 0 })
    }
    .width('100%').backgroundColor(AppColor.cardBg())
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  @Builder
  OrderItemsSection(items: CartItem[]) {
    Column({ space: 8 }) {
      ForEach(items, (item: CartItem, idx: number) => {
        Row({ space: 10 }) {
          ProductImage({ src: item.productImage, cornerRadius: 8 }).width(64).height(64)
          Column({ space: 3 }) {
            Text(item.productName)
              .fontSize(14).fontColor(AppColor.textPrimary()).lineHeight(18).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (item.skuInfo && item.skuInfo.skuDesc) {
              Text(item.skuInfo.skuDesc).fontSize(11).fontColor(AppColor.textTertiary())
            }
            Row() {
              Text('¥' + item.productPrice.toFixed(2)).fontSize(13).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Medium)
              Text('x' + item.quantity).fontSize(12).fontColor(AppColor.textTertiary()).margin({ left: 6 })
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start).height(64).justifyContent(FlexAlign.Center)
        }.width('100%')
        if (idx < items.length - 1) {
          Row().width('100%').height(1).backgroundColor(AppColor.divider()).margin({ left: 74 })
        }
      }, (item: CartItem, idx: number) => item.productId + '_' + idx)
    }
    .width('92%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
    .shadow({ radius: AppCard.ELEVATION, color: AppCard.shadowColor(), offsetX: 0, offsetY: 1 })
  }

  build() {
    Column() {
      HeaderComponent({ title: '申请售后' })

      if (this.loading) {
        LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
      } else if (this.afterSale) {
        // === 已申请 — 售后状态查看 ===
        Scroll() {
          Column({ space: 10 }) {
            Column() {
              Text(EffectiveStatus(this.afterSale))
                .fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor(EffectiveStatusColor(EffectiveStatus(this.afterSale)))
                .width('100%')
              Text('申请编号: ' + this.afterSale.id).fontSize(12).fontColor(AppColor.textTertiary()).width('100%').margin({ top: 2 })
            }
            .width('92%').padding(12).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)

            Column({ space: 6 }) {
              Row() {
                Text('订单编号').fontSize(13).fontColor(AppColor.textTertiary()).width(70)
                Text(this.afterSale.orderNumber.slice(-8)).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
                Text('详情 ›').fontSize(12).fontColor(AppColor.PRIMARY).margin({ left: 4 })
              }
              .width('100%').onClick(() => { if (this.afterSale) { AppRouter.goToOrderDetail(this.afterSale.orderNumber) } })
              Row() {
                Text('订单状态').fontSize(13).fontColor(AppColor.textTertiary()).width(70)
                Text(this.afterSale.currentOrderStatus || this.afterSale.orderStatus || '')
                  .fontSize(13).fontColor(OrderStatusColor(this.afterSale.currentOrderStatus || ''))
                  .fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.End)
              }.width('100%')
              InfoRow({ label: '售后类型', value: AFTER_SALE_TYPE_LABELS[this.afterSale.type] || this.afterSale.type })
              InfoRow({ label: '退款原因', value: this.afterSale.reason })
              InfoRow({ label: '退款金额', value: '¥' + this.afterSale.refundAmount.toFixed(2) })
              InfoRow({ label: '申请时间', value: this.afterSale.applyTime.slice(0, 16) })
              if (this.afterSale.processTime) {
                InfoRow({ label: '处理时间', value: this.afterSale.processTime.slice(0, 16) })
              }
              if (this.afterSale.processNote) {
                InfoRow({ label: '处理备注', value: this.afterSale.processNote })
              }
            }
            .width('92%').padding(12).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)

            if (EffectiveStatus(this.afterSale) === '待处理') {
              // 待处理 → 可取消申请（撤回 + 还原订单）
              AppButton({ text: '取消申请', type: AppButtonType.OUTLINE, fontColor: AppColor.CANCEL, buttonOnClick: () => { this.doCancel() } })
                .width('92%').height(44).margin({ top: 4 })
            } else if (this.afterSale.status !== 'cancelled') {
              // 已退款/已通过/已拒绝/已完成 → 可删除记录
              AppButton({ text: '删除记录', type: AppButtonType.OUTLINE, fontColor: AppColor.textTertiary(), buttonOnClick: () => { this.doDelete() } })
                .width('92%').height(44).margin({ top: 4 })
            }
          }
          .width('100%').alignItems(HorizontalAlign.Center).padding({ top: 8, bottom: 24 })
        }
        .layoutWeight(1).width('100%')
      } else {
        // === 全屏售后申请表单 ===
        Scroll() {
          Column({ space: 10 }) {
            // ── 1. 订单商品卡片 ──
            if (this.order && this.order.items.length > 0) {
              this.OrderItemsSection(this.order!.items)

              // ── 2. 售后类型 ──
              Column({ space: 8 }) {
                Text('售后类型').fontSize(13).fontColor(AppColor.textSecondary())
                Row({ space: 8 }) {
                  ForEach(AFTER_SALE_TYPES, (t: string) => {
                    Text(AFTER_SALE_TYPE_LABELS[t] || t)
                      .fontSize(13).padding({ left: 16, right: 16, top: 7, bottom: 7 })
                      .backgroundColor(this.applyType === t ? AppColor.PRIMARY : AppColor.inputBg())
                      .fontColor(this.applyType === t ? AppColor.WHITE : AppColor.textPrimary())
                      .borderRadius(16)
                      .onClick(() => { this.applyType = t })
                  }, (t: string) => t)
                }
              }
              .width('92%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)

              // ── 3. 退款金额 ──
              Row() {
                Text('退款金额').fontSize(13).fontColor(AppColor.textSecondary())
                Blank()
                Text('¥' + (this.order ? this.order.totalPrice.toFixed(2) : '0.00'))
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.PRIMARY)
              }
              .width('92%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
              .shadow({ radius: AppCard.ELEVATION, color: AppCard.shadowColor(), offsetX: 0, offsetY: 1 })

              // ── 4. 退款原因（底部弹窗选择）──
              Column() {
                Row() {
                  Text('退款原因').fontSize(13).fontColor(AppColor.textSecondary())
                  Blank()
                  Text(this.applyReason || '请选择退款原因')
                    .fontSize(14).fontColor(this.applyReason ? AppColor.textPrimary() : AppColor.textTertiary())
                    .margin({ right: 6 })
                  Text('▸').fontSize(12).fontColor(AppColor.textTertiary())
                }
                .width('100%').height(44).padding({ left: 14, right: 14 })
                .onClick(() => { this.showReasonSheet = true })
              }
              .width('92%').backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)

              // ── 5. 问题描述 ──
              Column({ space: 6 }) {
                Row() {
                  Text('问题描述').fontSize(13).fontColor(AppColor.textSecondary())
                  Text('（选填）').fontSize(11).fontColor(AppColor.textTertiary()).margin({ left: 4 })
                }
                TextArea({ text: this.applyDescription, placeholder: '请详细描述您遇到的问题，有助于卖家快速处理您的申请...' })
                  .height(100).padding(10).fontSize(13)
                  .backgroundColor(AppColor.inputBg()).borderRadius(AppRadius.SM)
                  .onChange((v: string) => { this.applyDescription = v })
                  .maxLength(500)
                Text((this.applyDescription.length) + '/500').fontSize(11).fontColor(AppColor.textTertiary())
                  .width('100%').textAlign(TextAlign.End)
              }
              .width('92%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)

              // ── 6. 上传凭证（选填）──
              Column({ space: 8 }) {
                Row() {
                  Text('上传凭证').fontSize(13).fontColor(AppColor.textSecondary())
                  Text('（选填）').fontSize(11).fontColor(AppColor.textTertiary()).margin({ left: 4 })
                  Blank()
                  Text(this.evidenceImages.length + '/6').fontSize(11).fontColor(AppColor.textTertiary())
                }

                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.evidenceImages, (uri: string, idx: number) => {
                    Stack() {
                      Image(uri).width(68).height(68).borderRadius(8).objectFit(ImageFit.Cover)
                      Text('×').fontSize(14).fontColor(AppColor.WHITE).width(18).height(18)
                        .textAlign(TextAlign.Center).backgroundColor('#66000000').borderRadius(9)
                        .position({ top: -4, right: -4 })
                        .onClick(() => {
                          let arr: string[] = []
                          for (let i = 0; i < this.evidenceImages.length; i++) {
                            if (i !== idx) arr.push(this.evidenceImages[i])
                          }
                          this.evidenceImages = arr
                        })
                    }.width(68).height(68).margin({ bottom: 8, right: 8 })
                  }, (uri: string) => uri)

                  if (this.evidenceImages.length < 6) {
                    Column() {
                      Text('+').fontSize(28).fontColor(AppColor.textTertiary()).lineHeight(30)
                      Text('上传').fontSize(10).fontColor(AppColor.textTertiary())
                    }
                    .width(68).height(68).backgroundColor(AppColor.inputBg()).borderRadius(8)
                    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                    .margin({ bottom: 8, right: 8 })
                    .onClick(() => { this.pickImages() })
                  }
                }
                .width('100%')
              }
              .width('92%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
              .shadow({ radius: AppCard.ELEVATION, color: AppCard.shadowColor(), offsetX: 0, offsetY: 1 })

              // ── 7. 提交按钮 ──
              AppButton({
                text: '提交申请',
                type: AppButtonType.PRIMARY,
                loading: this.submitting,
                buttonOnClick: () => { this.doApply() }
              })
                .width('92%').height(48).margin({ top: 4, bottom: 12 })
            }
          }
          .width('100%').alignItems(HorizontalAlign.Center).padding({ top: 6, bottom: 24 })
        }
        .layoutWeight(1).width('100%')
        .backgroundColor(AppColor.bg())
      }
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())
    .bindSheet($$this.showReasonSheet, this.ReasonSheetBuilder(), { height: APPLY_REASONS.length * 48 + 80 })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn }).opacity(0)
    PageTransitionExit({ duration: 250, curve: Curve.FastOutLinearIn }).opacity(0)
  }
}

@Component
struct InfoRow {
  @Prop label: string = ''
  @Prop value: string = ''

  build() {
    Row() {
      Text(this.label).fontSize(13).fontColor(AppColor.textTertiary()).width(70)
      Text(this.value).fontSize(13).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
    }.width('100%')
  }
}
