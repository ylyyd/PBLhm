import { CartItem } from '../data/model/ProductModel'
import { cartViewModel } from '../viewmodel/CartViewModel'
import { cartRepository } from '../data/repository/CartRepository'
import { AppRouter } from '../common/AppRouter'
import { TabPage } from '../components/BottomTab'
import { AppColor, AppContainer, AppShadow, AppRadius } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { ProductImage } from '../components/ProductImage'
import { BackButton, LoadingView, ErrorView, EmptyView } from '../components/StatusViews'
import { ConfirmDialog } from '../components/DialogComponent'
import { favoriteRepository } from '../data/repository/FavoriteRepository'
import { AppCheckbox } from '../components/AppCheckbox'

class CartDataSource implements IDataSource {
  private items: CartItem[] = []
  private listeners: DataChangeListener[] = []

  update(items: CartItem[]): void {
    this.items = items
    for (let l of this.listeners) {
      l.onDataReloaded()
    }
  }

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): CartItem {
    return this.items[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    let idx = this.listeners.indexOf(listener)
    if (idx >= 0) {
      this.listeners.splice(idx, 1)
    }
  }
}

@Component
export struct CartContent {
  switchTab?: (tab: TabPage) => void
  onCartChange?: () => void
  @Prop @Watch('onCartRefreshKeyChange') cartRefreshKey: number = 0
  @State cartItems: CartItem[] = cartViewModel.items
  @State cartVersion: number = 0
  @State totalPrice: number = 0
  @State loadError: string = ''
  @State isLoading: boolean = true
  @State isRefreshing: boolean = false
  @State selected: Map<string, boolean> = new Map<string, boolean>()
  @State isManageMode: boolean = false
  private cartDataSource: CartDataSource = new CartDataSource()
  private deleteDialog: CustomDialogController | null = null

  onCartRefreshKeyChange(): void {
    this.refreshCart()
  }

  async aboutToAppear(): Promise<void> {
    this.isLoading = true
    this.loadError = ''
    try {
      await cartRepository.load()
      this.refreshCart()
    } catch (err) {
      this.loadError = '加载购物车失败，请检查网络'
    }
    this.isLoading = false
  }

  async onCartRefresh(): Promise<void> {
    try {
      await cartRepository.load()
      this.refreshCart()
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({ message: '刷新失败，请重试' })
    }
    this.isRefreshing = false
  }

  itemKey(item: CartItem): string {
    return item.productId.toString() + '_' + item.skuInfo.skuId
  }

  isAllSelected(): boolean {
    if (this.cartItems.length === 0) return false
    return this.cartItems.every((item): boolean => (this.selected.get(this.itemKey(item)) as boolean) ?? false)
  }

  selectedCount(): number {
    let count = 0
    for (let item of this.cartItems) {
      if (this.selected.get(this.itemKey(item))) {
        count++
      }
    }
    return count
  }

  toggleSelectAll(): void {
    let all = this.isAllSelected()
    for (let item of this.cartItems) {
      this.selected.set(this.itemKey(item), !all)
    }
    this.selected = new Map<string, boolean>(this.selected)
    this.recalcTotal()
  }

  toggleItemByKey(key: string): void {
    this.selected.set(key, !(this.selected.get(key) ?? false))
    this.selected = new Map<string, boolean>(this.selected)
    this.recalcTotal()
  }

  recalcTotal(): void {
    let total = 0
    for (let item of this.cartItems) {
      if (this.selected.get(this.itemKey(item)) ?? false) {
        total += item.productPrice * item.quantity
      }
    }
    this.totalPrice = total
  }

  getSelectedItems(): CartItem[] {
    let sel: CartItem[] = []
    for (let item of this.cartItems) {
      if (this.selected.get(this.itemKey(item)) ?? false) {
        sel.push(item)
      }
    }
    return sel
  }

  async batchDelete(): Promise<void> {
    let sel = this.getSelectedItems()
    if (sel.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请选择要删除的商品' })
      return
    }
    this.showConfirmDialog('批量删除', '确定要删除选中的 ' + sel.length + ' 件商品吗？', '删除', async () => {
      try {
        for (let item of sel) {
          this.selected.delete(this.itemKey(item))
          await cartViewModel.removeFromCart(item.productId, item.skuInfo.skuId)
        }
        await this.refreshCart()
        // 删除后剩余商品全部选中
        for (let item of this.cartItems) {
          this.selected.set(this.itemKey(item), true)
        }
        this.selected = new Map<string, boolean>(this.selected)
        this.recalcTotal()
        this.getUIContext().getPromptAction().showToast({ message: '已删除 ' + sel.length + ' 件商品' })
      } catch (e) {
        this.getUIContext().getPromptAction().showToast({ message: e instanceof Error ? e.message : '删除失败' })
        await this.refreshCart()
      }
    })
  }

  async batchMoveToFavorites(): Promise<void> {
    let sel = this.getSelectedItems()
    if (sel.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请选择要移入收藏夹的商品' })
      return
    }
    try {
      let moved = 0
      for (let item of sel) {
        this.selected.delete(this.itemKey(item))
        await favoriteRepository.toggle(item.productId)
        await cartViewModel.removeFromCart(item.productId, item.skuInfo.skuId)
        moved++
      }
      await this.refreshCart()
      // 移入后剩余商品全部选中
      for (let item of this.cartItems) {
        this.selected.set(this.itemKey(item), true)
      }
      this.selected = new Map<string, boolean>(this.selected)
      this.recalcTotal()
      this.getUIContext().getPromptAction().showToast({ message: '已移入收藏夹 ' + moved + ' 件商品' })
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: e instanceof Error ? e.message : '操作失败' })
      await this.refreshCart()
    }
  }

  async refreshCart(): Promise<void> {
    this.cartItems = cartViewModel.items.map(item => item.copy())
    this.cartVersion++
    for (let item of this.cartItems) {
      let k = this.itemKey(item)
      if (this.selected.get(k) === undefined) {
        this.selected.set(k, item.selected)
      }
    }
    this.selected = new Map<string, boolean>(this.selected)
    this.cartDataSource.update(this.cartItems)
    this.recalcTotal()
    this.onCartChange?.()
  }

  async doDecrementByKey(key: string): Promise<void> {
    let item = this.cartItems.find(i => this.itemKey(i) === key)
    if (!item) return
    try {
      if (item.quantity > 1) {
        await cartViewModel.updateQuantity(item.productId, item.quantity - 1, item.skuInfo.skuId)
      } else {
        await cartViewModel.removeFromCart(item.productId, item.skuInfo.skuId)
      }
      await this.refreshCart()
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: e instanceof Error ? e.message : '操作失败' })
      await this.refreshCart()
    }
  }

  async doIncrementByKey(key: string): Promise<void> {
    let item = this.cartItems.find(i => this.itemKey(i) === key)
    if (!item) return
    try {
      if (item.quantity >= item.stock) {
        this.getUIContext().getPromptAction().showToast({ message: '已达到最大库存' })
        return
      }
      await cartViewModel.updateQuantity(item.productId, item.quantity + 1, item.skuInfo.skuId)
      await this.refreshCart()
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: e instanceof Error ? e.message : '添加失败' })
      await this.refreshCart()
    }
  }

  showConfirmDialog(title: string, message: string, confirmText: string, onConfirm: () => void): void {
    this.deleteDialog = new CustomDialogController({
      builder: ConfirmDialog({
        title: title,
        message: message,
        cancelText: '取消',
        confirmText: confirmText,
        confirmType: AppButtonType.DANGER,
        onConfirm: () => {
          onConfirm()
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.deleteDialog.open()
  }

  build() {
    Column() {
      Row() {
        BackButton({ onBack: () => { this.switchTab?.(TabPage.HOME) } })
        Blank()
        Text($r('app.string.cart_title')).fontSize(20).fontWeight(FontWeight.Bold)
        Blank()
        if (this.isManageMode) {
          Text('完成').fontSize(14).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Medium)
            .onClick(() => { this.isManageMode = false })
        } else {
          Text('管理').fontSize(14).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Medium)
            .onClick(() => { this.isManageMode = true })
        }
      }
      .width(AppContainer.WIDTH).padding({ top: 14, bottom: 12 })

      if (this.isLoading) {
        LoadingView({ message: '加载购物车...' }).layoutWeight(1).width('100%')
      } else if (this.loadError) {
        ErrorView({ message: this.loadError, onRetry: () => this.aboutToAppear() }).layoutWeight(1).width('100%')
      } else if (this.cartItems.length === 0) {
        Column() {
          Blank().layoutWeight(1)
          EmptyView({ message: '购物车是空的', icon: $rawfile('empty_cart.svg'),
            actionText: '去购物', action: () => { this.switchTab?.(TabPage.HOME) } })
          Blank().layoutWeight(1)
        }
        .layoutWeight(1).width('100%')
      } else {
        Column() {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ space: 10 }) {
              ListItem() {
                Row() {
                  AppCheckbox({ checked: this.isAllSelected(), checkSize: 20, onCheck: () => { this.toggleSelectAll() } })
                  Text('全选').fontSize(14).fontColor(AppColor.textSecondary()).margin({ left: 8 })
                  Blank()
                  Text('已选 ' + this.selectedCount() + ' 件').fontSize(13).fontColor(AppColor.textTertiary())
                }
                .width(AppContainer.WIDTH).padding({ left: 4 })
              }

              LazyForEach(this.cartDataSource, (item: CartItem) => {
                ListItem() {
                  CartItemRow({
                    item: item,
                    isItemSelected: (this.selected.get(this.itemKey(item)) ?? false),
                    itemKeyStr: this.itemKey(item),
                    onToggleKey: (k: string) => { this.toggleItemByKey(k) },
                    onDecrementKey: (k: string) => { this.doDecrementByKey(k) },
                    onIncrementKey: (k: string) => { this.doIncrementByKey(k) },
                    onDeleteKey: (k: string) => {
                      let delItem = this.cartItems.find(i => this.itemKey(i) === k)
                      if (!delItem) return
                      let delPid = delItem.productId
                      let delSku = delItem.skuInfo.skuId
                      let delName = delItem.productName
                      this.showConfirmDialog('删除商品', '确定要从购物车中移除「' + delName + '」吗？', '删除', () => {
                        this.selected.delete(k)
                        this.selected = new Map<string, boolean>(this.selected)
                        cartViewModel.removeFromCart(delPid, delSku).then(() => this.refreshCart())
                      })
                    }
                  })
                }
              }, (item: CartItem) => this.itemKey(item) + '_' + this.cartVersion)
            }
            .cachedCount(5)
            .width('100%').backgroundColor(AppColor.bg()).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
            .padding({ top: 4, bottom: 16 })
          }
          .onRefreshing(() => { this.onCartRefresh() })
          .width('100%').height('100%')
        }
        .layoutWeight(1).width('100%')

        if (this.isManageMode) {
          Column() {
            Row() {
              Text('已选 ' + this.selectedCount() + ' 件').fontSize(14).fontColor(AppColor.textSecondary())
              Blank()
              AppButton({ text: '删除', type: AppButtonType.DANGER,
                buttonWidth: 100, buttonHeight: 40, buttonRadius: 20,
                fontSize: 14, fontWeight: FontWeight.Medium,
                buttonOnClick: () => { this.batchDelete() } })
                .margin({ right: 10 })
              AppButton({ text: '移入收藏夹', type: AppButtonType.OUTLINE,
                buttonWidth: 130, buttonHeight: 40, buttonRadius: 20,
                fontSize: 14, fontWeight: FontWeight.Medium,
                buttonOnClick: () => { this.batchMoveToFavorites() } })
            }.width(AppContainer.CONTENT_WIDTH)
          }
          .width('100%').padding({ left: '4%', right: '4%', top: 12, bottom: 12 })
          .backgroundColor(AppColor.cardBg()).shadow(AppShadow.top())
        } else {
          Column() {
            Row() {
              Column() {
                Text('合计').fontSize(13).fontColor(AppColor.textTertiary())
                Row() {
                  Text('¥').fontSize(16).fontColor(AppColor.PRIMARY)
                  Text(this.totalPrice.toString()).fontSize(28).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
                }
              }
              Blank()
  AppButton({ text: '结算', type: AppButtonType.PRIMARY,
            buttonWidth: 140, buttonHeight: 48, buttonRadius: 24, fontSize: 16, fontWeight: FontWeight.Bold,
                buttonOnClick: () => {
                  if (this.totalPrice > 0) {
                    let keys: string[] = []
                    for (let item of this.cartItems) {
                      if (this.selected.get(this.itemKey(item)) ?? false) {
                        keys.push(item.productId.toString() + '_' + item.skuInfo.skuId)
                      }
                    }
                    cartViewModel.selectedCheckoutKeys = keys
                    AppRouter.goToCheckout()
                  }
                } })
            }.width(AppContainer.CONTENT_WIDTH)
          }
          .width('100%').padding({ left: '4%', right: '4%', top: 12, bottom: 12 })
          .backgroundColor(AppColor.cardBg()).shadow(AppShadow.top())
        }
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

@Reusable
@Component
export struct CartItemRow {
  @Prop item: CartItem = new CartItem()
  @Prop isItemSelected: boolean = false
  @Prop itemKeyStr: string = ''
  onToggleKey?: (key: string) => void
  onDecrementKey?: (key: string) => void
  onIncrementKey?: (key: string) => void
  onDeleteKey?: (key: string) => void
  @State version: number = 0

  aboutToReuse(params: Record<string, Object>): void {
    if (params.item !== undefined) {
      this.item = params.item as CartItem
    }
    if (params.isItemSelected !== undefined) {
      this.isItemSelected = params.isItemSelected as boolean
    }
    if (params.itemKeyStr !== undefined) {
      this.itemKeyStr = params.itemKeyStr as string
    }
    this.version++
  }

  build() {
    Row() {
      AppCheckbox({ checked: this.isItemSelected, checkSize: 22, onCheck: () => { this.onToggleKey?.(this.itemKeyStr) } })
        .margin({ right: 8 })

      ProductImage({ src: this.item.productImage })
        .width(90).height(90).borderRadius(12)
        .backgroundColor(AppColor.bg())

      Column({ space: 4 }) {
        Row() {
          Text(this.item.productName).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          Stack() {
            Circle().width(28).height(28).fill(AppColor.bg())
            Path().commands('M9,9 L19,19 M19,9 L9,19')
              .stroke(AppColor.textTertiary()).strokeWidth(1.8).strokeLineCap(LineCapStyle.Round)
          }
            .width(28).height(28)
            .onClick(() => { this.onDeleteKey?.(this.itemKeyStr) })
        }.width('100%')

        if (this.item.skuInfo.skuDesc) {
          Text(this.item.skuInfo.skuDesc)
            .fontSize(12).fontColor(AppColor.textTertiary()).lineHeight(18)
        }

        Blank()
        Row() {
          Text('¥' + this.item.productPrice).fontSize(20).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold).layoutWeight(1)
          Row({ space: 0 }) {
            AppButton({ text: '−', type: AppButtonType.OUTLINE,
              buttonWidth: 28, buttonHeight: 28, buttonRadius: 14,
              fontSize: 16, fontWeight: FontWeight.Medium, fontColor: AppColor.textSecondary(),
              buttonOnClick: () => { this.onDecrementKey?.(this.itemKeyStr) } })
            Text(this.item.quantity.toString())
              .width(36).textAlign(TextAlign.Center)
              .fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
            AppButton({ text: '+', type: AppButtonType.PRIMARY,
              buttonWidth: 28, buttonHeight: 28, buttonRadius: 14,
              fontSize: 16, fontWeight: FontWeight.Medium,
              buttonOnClick: () => { this.onIncrementKey?.(this.itemKeyStr) } })
          }
        }.width('100%').alignItems(VerticalAlign.Bottom)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 8 }).height(90)
    }
    .width('100%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
    .shadow(AppShadow.mid())
    .hoverEffect(HoverEffect.Scale)
    .transition(TransitionEffect.opacity(0).animation({ duration: 300, curve: Curve.EaseOut }))
  }
}
