import { CartItem, Product } from '../data/model/ProductModel'
import { Address } from '../data/model/AddressModel'
import { cartViewModel } from '../viewmodel/CartViewModel'
import { orderViewModel } from '../viewmodel/OrderViewModel'
import { sessionViewModel } from '../viewmodel/SessionViewModel'
import { addressRepository } from '../data/repository/AddressRepository'
import { cartRepository } from '../data/repository/CartRepository'
import { productRepository } from '../data/repository/ProductRepository'
import { HttpClient, HttpError } from '../data/HttpClient'
import { AppRouter, WebViewParams } from '../common/AppRouter'
import { RoutePath } from '../common/Constants'
import { AppColor, AppCard, AppContainer, AppShadow } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { HeaderComponent } from '../components/HeaderComponent'
import { EmptyView, LoadingView } from '../components/StatusViews'

import { ProductImage } from '../components/ProductImage'
import { SkuBottomSheet } from '../components/SkuBottomSheet'
import { Logger } from '../common/Logger'

@Entry
@Component
struct Checkout {
  @StorageLink('themeMode') themeMode: number = 0
  @State orderNumber: string = ''
  @State selectedAddressId: number = 0
  @State selectedAddressDetail: string = ''
  @State showAddressPicker: boolean = false
  @State addressList: Address[] = []
  @State checkoutItems: CartItem[] = []
  @State checkoutTotal: number = 0
  @State isLoadingAddresses: boolean = false
  @State isSubmitting: boolean = false

  @State pendingOrderNo: string = ''

  @State showSkuSheet: boolean = false
  @State skuSheetProduct: Product | null = null
  @State skuSheetItemId: number = 0
  @State skuSheetSkuId: string = ''

  async loadAddresses(): Promise<void> {
    this.isLoadingAddresses = true
    this.addressList = await addressRepository.getAddresses()
    let lastAddrId = await sessionViewModel.getLastSelectedAddressId()
    let lastMatch = lastAddrId > 0 ? this.addressList.find(a => a.id === lastAddrId) : undefined
    if (lastMatch) {
      this.selectedAddressId = lastMatch.id
      this.selectedAddressDetail = lastMatch.detail
    } else {
      let def = this.addressList.find(a => a.isDefault) || this.addressList[0]
      if (def) {
        this.selectedAddressId = def.id
        this.selectedAddressDetail = def.detail
      } else {
        let user = sessionViewModel.currentUser
        if (user && user.address && this.selectedAddressId === 0) {
          this.selectedAddressDetail = user.address
        }
      }
    }
    this.isLoadingAddresses = false
  }

  selectedAddressLabel(): string {
    let a = this.selectedAddressId > 0 ? this.addressList.find(ad => ad.id === this.selectedAddressId) : undefined
    if (a) {
      return (a.recipientName ? a.recipientName : '') + '  ' + (a.phone ? a.phone : '') + '  ' + a.detail
    }
    return this.selectedAddressDetail
  }

  refreshCheckoutItems(): void {
    let keys = cartViewModel.selectedCheckoutKeys
    let allItems = cartViewModel.items.map(item => item.copy())
    if (keys.length > 0) {
      this.checkoutItems = allItems.filter(item => keys.indexOf(item.productId.toString() + '_' + item.skuInfo.skuId) >= 0)
    } else {
      this.checkoutItems = allItems
    }
    this.checkoutTotal = this.checkoutItems.reduce((sum, item) => sum + item.subtotal, 0)
  }

  async qtyDecrement(itemId: number, skuId?: string): Promise<void> {
    let item = cartViewModel.items.find(i => i.productId === itemId && i.skuInfo.skuId === (skuId || ''))
    if (!item) return
    let key = skuId || ''
    let newQty = item.quantity - 1
    if (item.quantity > 1) {
      await cartViewModel.updateQuantity(itemId, newQty, skuId)
    } else {
      await cartViewModel.removeFromCart(itemId, skuId)
      this.checkoutItems = this.checkoutItems.filter(i => !(i.productId === itemId && i.skuInfo.skuId === key))
      this.recalcTotal()
      return
    }
    this.checkoutItems = this.checkoutItems.map(i => {
      if (i.productId === itemId && i.skuInfo.skuId === key) {
        let c = i.copy()
        c.quantity = newQty
        return c
      }
      return i
    })
    this.recalcTotal()
  }

  async qtyIncrement(itemId: number, skuId?: string): Promise<void> {
    let item = cartViewModel.items.find(i => i.productId === itemId && i.skuInfo.skuId === (skuId || ''))
    if (!item) return
    let key = skuId || ''
    let newQty = item.quantity + 1
    await cartViewModel.updateQuantity(itemId, newQty, skuId)
    this.checkoutItems = this.checkoutItems.map(i => {
      if (i.productId === itemId && i.skuInfo.skuId === key) {
        let c = i.copy()
        c.quantity = newQty
        return c
      }
      return i
    })
    this.recalcTotal()
  }

  recalcTotal(): void {
    this.checkoutTotal = this.checkoutItems.reduce((sum, item) => sum + item.subtotal, 0)
  }

  async handleSubmitOrder(): Promise<void> {
    if (this.isSubmitting) return
    // 验证收货地址
    if (!this.selectedAddressDetail || this.selectedAddressDetail.trim() === '') {
      this.getUIContext().getPromptAction().showToast({ message: '请选择收货地址' })
      return
    }
    // 验证支付密码（当前用户是否已设置支付密码）
    if (!sessionViewModel.currentUser || !(await sessionViewModel.checkPaymentPasswordExists())) {
      this.getUIContext().getPromptAction().showToast({ message: '请先设置支付密码' })
      return
    }
    this.isSubmitting = true
    try {
      let orderNo = await orderViewModel.placeOrder(this.selectedAddressDetail, this.checkoutItems)
      this.pendingOrderNo = orderNo
      cartViewModel.selectedCheckoutKeys = []
      let data: Object = await HttpClient.post('/payment/page/' + orderNo, {})
      let resp = data as Record<string, Object>
      let payUrl = resp.payUrl as string
      if (payUrl) {
        let wp = new WebViewParams()
        wp.url = payUrl
        wp.title = '支付'
        wp.orderNumber = orderNo
        AppRouter.replace(RoutePath.WEBVIEW_PAGE, wp)
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '获取支付链接失败，请重试' })
      }
    } catch (err) {
      let msg = '提交订单失败，请重试'
      if (err instanceof HttpError) {
        msg = err.message
      } else if (err instanceof Error) {
        msg = err.message
      }
      this.getUIContext().getPromptAction().showToast({ message: msg })
    } finally {
      this.isSubmitting = false
    }
  }

  async aboutToAppear(): Promise<void> {
    this.orderNumber = ''
    await this.loadAddresses()
    try {
      await cartRepository.load()
    } catch (err) {
      Logger.error('Checkout.aboutToAppear cart load failed: {0}', err instanceof Error ? err.message : '')
    }
    this.refreshCheckoutItems()
  }

  async onPageShow(): Promise<void> {
    this.orderNumber = ''
    await this.loadAddresses()
    try {
      await cartRepository.load()
    } catch (err) {
      Logger.error('Checkout.onPageShow cart load failed: {0}', err instanceof Error ? err.message : '')
    }
    this.refreshCheckoutItems()
  }



  build() {
    Stack() {
      Column() {
        HeaderComponent({ title: '确认订单' })

      Scroll() {
        Column({ space: 12 }) {
          Column() {
            Row() {
              Text($r('app.string.checkout_address')).fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
              if (!this.showAddressPicker) {
                Image($rawfile('ic_chevron_right_primary.svg')).width(18).height(18).opacity(0.4)
              }
            }.width('100%')
              .onClick(async () => {
                this.showAddressPicker = !this.showAddressPicker
                if (this.showAddressPicker) {
                  await this.loadAddresses()
                }
              })

            if (this.showAddressPicker) {
              if (this.isLoadingAddresses) {
                LoadingView()
              } else if (this.addressList.length === 0) {
                EmptyView({ message: '暂无保存的地址，请先添加', icon: $rawfile('ic_location.svg') })
                  .width('100%').margin({ top: 12 })
                Row({ space: 4 }) {
                  Text('去添加地址').fontSize(14).fontColor(AppColor.PRIMARY)
                  Image($rawfile('ic_chevron_right_primary.svg')).width(14).height(14)
                }
                  .margin({ top: 4 })
                  .onClick(() => { AppRouter.goToAddressManagement() })
              } else {
                  ForEach(this.addressList, (addr: Address) => {
                  Row() {
                    Column({ space: 4 }) {
                      Row({ space: 8 }) {
                        Text(addr.label).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
                        if (addr.isDefault) {
                          Text('默认').fontSize(10).fontColor(AppColor.PRIMARY)
                            .backgroundColor(AppColor.primaryBg()).borderRadius(4).padding({ left: 5, right: 5 })
                        }
                      }
                      Text((addr.recipientName ? addr.recipientName : '') + '  ' + (addr.phone ? addr.phone : ''))
                        .fontSize(14).fontColor(AppColor.textPrimary()).lineHeight(20)
                      Text(addr.detail).fontSize(14).fontColor(AppColor.textSecondary()).lineHeight(20)
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    Circle().width(18).height(18)
                      .fill(addr.id === this.selectedAddressId ? AppColor.PRIMARY : AppColor.cardBg())
                      .stroke(addr.id === this.selectedAddressId ? AppColor.PRIMARY : AppColor.textDisabledLight())
                      .strokeWidth(2)
                  }
                  .width('100%').padding({ top: 10, bottom: 10 })
                  .onClick(async () => {
                    this.selectedAddressId = addr.id
                    this.selectedAddressDetail = addr.detail
                    this.showAddressPicker = false
                    await sessionViewModel.setLastSelectedAddress(addr)
                  })
                })
                Text('+ 添加新地址')
                  .fontSize(14).fontColor(AppColor.PRIMARY).margin({ top: 4 })
                  .onClick(() => { AppRouter.goToAddressManagement() })
              }
            } else {
              if (this.selectedAddressId > 0 || this.selectedAddressDetail) {
                Text(this.selectedAddressLabel())
                  .fontSize(15).fontColor(AppColor.textPrimary()).width('100%').margin({ top: 10 }).lineHeight(22)
              } else {
                Text($r('app.string.checkout_no_address'))
                  .fontSize(15).fontColor(AppColor.PRIMARY).width('100%').margin({ top: 10 }).lineHeight(22)
              }
            }
          }
          .width(AppContainer.WIDTH).padding(18).backgroundColor(AppColor.cardBg()).borderRadius(14)
          .shadow(AppShadow.mid())

          Text($r('app.string.checkout_product_info'))
            .fontSize(17).fontWeight(FontWeight.Bold).width(AppContainer.WIDTH)

          ForEach(this.checkoutItems, (item: CartItem) => {
            Row() {
              ProductImage({ src: item.productImage }).width(72).height(72).borderRadius(12)
              Column({ space: 4 }) {
                Text(item.productName).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                // SKU 规格行 — 有则显示并可点击换规格
                Row({ space: 4 }) {
                  if (item.skuInfo.skuDesc) {
                    Text(item.skuInfo.skuDesc)
                      .fontSize(12).fontColor(AppColor.textTertiary()).lineHeight(18)
                  }
                  if (item.skuInfo.skuDesc) {
                    Text('›').fontSize(14).fontColor(AppColor.textTertiary())
                  }
                }
                .onClick(async () => {
                  let p = await productRepository.getProductDetail(item.productId)
                  if (p) {
                    this.skuSheetProduct = p
                    this.skuSheetItemId = item.productId
                    this.skuSheetSkuId = item.skuInfo.skuId
                    this.showSkuSheet = true
                  }
                })
                Row({ space: 0 }) {
                  AppButton({ text: '−', type: AppButtonType.OUTLINE,
                    buttonWidth: 26, buttonHeight: 26, buttonRadius: 13,
                    fontSize: 14, fontWeight: FontWeight.Medium, fontColor: AppColor.textSecondary(),
                    buttonOnClick: () => { this.qtyDecrement(item.productId, item.skuInfo.skuId) } })
                  Text(item.quantity.toString())
                    .width(32).textAlign(TextAlign.Center)
                    .fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
                  AppButton({ text: '+', type: AppButtonType.PRIMARY,
                    buttonWidth: 26, buttonHeight: 26, buttonRadius: 13,
                    fontSize: 14, fontWeight: FontWeight.Medium,
                    buttonOnClick: () => { this.qtyIncrement(item.productId, item.skuInfo.skuId) } })
                }
              }.margin({ left: 12 }).layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text('¥' + item.subtotal).fontSize(17).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
            }
            .width(AppContainer.WIDTH).padding(14).backgroundColor(AppColor.cardBg()).borderRadius(14)
            .shadow(AppShadow.mid())
          }, (item: CartItem) => item.productId.toString() + '_' + item.skuInfo.skuId + '_' + item.quantity.toString())

          Column({ space: 10 }) {
            Row() {
              Text($r('app.string.checkout_order_no')).fontSize(14).fontColor(AppColor.textTertiary())
              Text(this.orderNumber).fontSize(14).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
            }.width('100%')
            Row() {
              Text($r('app.string.checkout_delivery')).fontSize(14).fontColor(AppColor.textTertiary())
              Text($r('app.string.checkout_delivery_free')).fontSize(14).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
            }.width('100%')
            Row() {
              Text($r('app.string.checkout_payment')).fontSize(14).fontColor(AppColor.textTertiary())
              Text('在线支付').fontSize(14).fontColor(AppColor.textPrimary()).layoutWeight(1).textAlign(TextAlign.End)
            }.width('100%')
            Line().width('100%').height(0.5).backgroundColor(AppColor.divider())
            Row() {
              Text($r('app.string.checkout_subtotal')).fontSize(14).fontColor(AppColor.textTertiary())
              Text('¥' + this.checkoutTotal).fontSize(18).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                .layoutWeight(1).textAlign(TextAlign.End)
            }.width('100%')
          }
          .width(AppContainer.WIDTH).padding(18).backgroundColor(AppColor.cardBg()).borderRadius(14)
          .shadow(AppShadow.mid())
        }
        .width('100%').alignItems(HorizontalAlign.Center).padding({ top: 4, bottom: 120 })
      }
      .layoutWeight(1).width('100%').backgroundColor(AppColor.bg()).scrollBar(BarState.Off)

      Column() {
        Row() {
          Column() {
            Text($r('app.string.checkout_actual_pay')).fontSize(13).fontColor(AppColor.textTertiary())
            Row() {
              Text('¥').fontSize(18).fontColor(AppColor.PRIMARY)
              Text(this.checkoutTotal.toString()).fontSize(28).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
            }
          }
          Blank()
          AppButton({ text: '提交订单', type: AppButtonType.PRIMARY, buttonWidth: 150,
            buttonHeight: 48, fontSize: 17, fontWeight: FontWeight.Bold,
            buttonOnClick: () => { this.handleSubmitOrder() } })
        }
        .width('100%')
      }
      .width('100%').padding({ left: '4%', right: '4%', top: 12, bottom: 12 })
      .backgroundColor(AppColor.cardBg()).shadow(AppShadow.top())
    }
    .width('100%').height('100%').backgroundColor(AppColor.bg())

      if (this.showSkuSheet && this.skuSheetProduct) {
        SkuBottomSheet({
          product: this.skuSheetProduct,
          mode: 'confirm',
          initSkuId: this.skuSheetSkuId,
          initPrice: 0,
          initImage: '',
          onConfirm: async (newSkuId: string, qty: number) => {
            if (newSkuId && newSkuId !== this.skuSheetSkuId) {
              let oldKey = this.skuSheetItemId.toString() + '_' + this.skuSheetSkuId
              let newKey = this.skuSheetItemId.toString() + '_' + newSkuId
              await cartRepository.removeFromCart(this.skuSheetItemId, this.skuSheetSkuId)
              await cartRepository.addToCart(this.skuSheetProduct!, newSkuId, qty)
              // 只替换当前商品的 key，不影响其他已选商品
              let keys = cartViewModel.selectedCheckoutKeys
              let idx = keys.indexOf(oldKey)
              if (idx >= 0) {
                let copy: string[] = []
                for (let i = 0; i < keys.length; i++) {
                  copy.push(i === idx ? newKey : keys[i])
                }
                cartViewModel.selectedCheckoutKeys = copy
              }
              this.skuSheetSkuId = newSkuId
              this.refreshCheckoutItems()
            }
          },
          onClose: () => { this.showSkuSheet = false }
        })
      }
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
    PageTransitionExit({ duration: 350, curve: Curve.FastOutSlowIn })
      .opacity(0)
  }
}
