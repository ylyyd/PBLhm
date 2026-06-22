import { Product, SKU, ProductSpec } from '../data/model/ProductModel'
import { AppColor, AppRadius } from '../common/StyleConstants'
import { AppButton, AppButtonType } from './AppButton'
import { ProductImage } from './ProductImage'

@Component
export struct SkuBottomSheet {
  @Prop product: Product = new Product()
  @Prop mode: string = 'add_cart'
  @Prop initSkuId: string = ''
  @Prop initPrice: number = 0
  @Prop initImage: string = ''

  onConfirm: (skuId: string, quantity: number) => void = () => {}
  onClose: () => void = () => {}

  @State selectedSpecs: Record<string, string> = {}
  @State matchedSKU: SKU | null = null
  @State currentSkuId: string = ''
  @State currentPrice: number = 0
  @State currentImage: string = ''
  @State quantity: number = 1
  @State panelOffset: number = 600
  @State overlayOpacity: number = 0

  aboutToAppear(): void {
    if (this.initSkuId && this.product.hasSKU()) {
      let found = this.product.skus.find(s => s.id === this.initSkuId)
      if (found) {
        this.matchedSKU = found
        this.currentSkuId = found.id
        this.currentPrice = found.price
        this.currentImage = found.image || this.product.image
        this.selectedSpecs = found.specs
      }
    }
    if (this.product.hasSKU() && !this.currentSkuId) {
      let first: Record<string, string> = {}
      for (let spec of this.product.specs) {
        if (spec.values.length > 0) {
          first[spec.name] = spec.values[0]
        }
      }
      this.selectedSpecs = first
    }
    if (this.product.hasSKU()) {
      this.matchSKU()
    }
    if (this.currentPrice <= 0) {
      this.currentPrice = this.initPrice > 0 ? this.initPrice : this.product.price
    }
    if (!this.currentImage) {
      this.currentImage = this.initImage || this.product.image
    }
    this.getUIContext().animateTo({ duration: 350, curve: Curve.FastOutSlowIn }, () => {
      this.panelOffset = 0
      this.overlayOpacity = 1
    })
  }

  matchSKU(): void {
    if (!this.product.hasSKU()) {
      this.matchedSKU = null
      this.currentSkuId = ''
      this.currentPrice = this.product.price
      this.currentImage = this.product.image
      return
    }
    let selected = this.selectedSpecs
    let specNames: string[] = []
    for (let i = 0; i < this.product.specs.length; i++) {
      specNames.push(this.product.specs[i].name)
    }
    let specCount = 0
    for (let i = 0; i < specNames.length; i++) {
      if (selected[specNames[i]] !== undefined) specCount++
    }
    if (specCount < this.product.specs.length) {
      this.matchedSKU = null
      this.currentSkuId = ''
      this.currentPrice = this.product.price
      this.currentImage = this.product.image
      return
    }
    let found = this.product.skus.find(sku => {
      for (let i = 0; i < specNames.length; i++) {
        if (sku.specs[specNames[i]] !== selected[specNames[i]]) return false
      }
      return true
    })
    this.matchedSKU = found || null
    if (found) {
      this.currentSkuId = found.id
      this.currentPrice = found.price
      this.currentImage = found.image || this.product.image
    } else {
      this.currentSkuId = ''
      this.currentPrice = this.product.price
      this.currentImage = this.product.image
    }
  }

  selectSpec(specName: string, value: string): void {
    let copy: Record<string, string> = {}
    let keys = Object.keys(this.selectedSpecs)
    for (let i = 0; i < keys.length; i++) {
      copy[keys[i]] = this.selectedSpecs[keys[i]]
    }
    copy[specName] = value
    this.selectedSpecs = copy
    this.matchSKU()
    this.quantity = 1
  }

  getStock(): number {
    if (this.product.hasSKU()) {
      return this.matchedSKU ? this.matchedSKU.stock : 0
    }
    return this.product.stock
  }

  isSpecValueDisabled(specName: string, value: string): boolean {
    if (!this.product.hasSKU()) return false
    // Build candidate: 当前已选规格 + 这个值
    let cand: Record<string, string> = {}
    let keys = Object.keys(this.selectedSpecs)
    for (let i = 0; i < keys.length; i++) {
      cand[keys[i]] = this.selectedSpecs[keys[i]]
    }
    cand[specName] = value
    // Find any SKU 匹配已选规格且有库存
    let specNames = this.product.specs.map(s => s.name)
    let match = this.product.skus.find(sku => {
      for (let i = 0; i < specNames.length; i++) {
        let n = specNames[i]
        if (cand[n] === undefined) continue // 未选的维度不限制
        if (sku.specs[n] !== cand[n]) return false
      }
      return sku.stock > 0
    })
    return !match
  }

  getSelectedSpecsDisplay(): string {
    let keys = Object.keys(this.selectedSpecs)
    if (keys.length === 0) return ''
    let vals: string[] = []
    for (let i = 0; i < keys.length; i++) {
      vals.push(this.selectedSpecs[keys[i]])
    }
    return vals.join(', ')
  }

  getDisplayPrice(): number {
    return this.currentPrice > 0 ? this.currentPrice : this.product.price
  }

  getTotalPrice(): number {
    return this.getDisplayPrice() * this.quantity
  }

  close(): void {
    this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutLinearIn }, () => {
      this.panelOffset = 600
      this.overlayOpacity = 0
    })
    setTimeout(() => { this.onClose() }, 270)
  }

  @Builder
  specValueItem(val: string, specName: string) {
    Text(val)
      .fontSize(13)
      .fontColor(this.selectedSpecs[specName] === val ? AppColor.WHITE : (this.isSpecValueDisabled(specName, val) ? AppColor.textDisabledLight() : AppColor.textPrimary()))
      .backgroundColor(this.selectedSpecs[specName] === val ? AppColor.PRIMARY : AppColor.inputBg())
      .border({ width: this.selectedSpecs[specName] === val ? 0 : (this.isSpecValueDisabled(specName, val) ? 0 : 1), color: AppColor.border(), style: BorderStyle.Solid })
      .borderRadius(AppRadius.PILL)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .opacity(this.isSpecValueDisabled(specName, val) && this.selectedSpecs[specName] !== val ? 0.45 : 1.0)
      .onClick(() => {
        if (!this.isSpecValueDisabled(specName, val)) { this.selectSpec(specName, val) }
      })
  }

  build() {
    Column() {
      // ── overlay — fills all space above panel via layoutWeight ──
      Column()
        .layoutWeight(1)
        .width('100%')
        .backgroundColor(AppColor.OVERLAY)
        .opacity(this.overlayOpacity)
        .onClick(() => { this.close() })

      // ── bottom panel — natural content height, bottom sits at screen bottom ──
      Column() {
        // drag handle
        Row()
          .width(40).height(4).backgroundColor(AppColor.border())
          .borderRadius(2).margin({ top: 10, bottom: 6 })

        // ── header: image + price + close ──
        Row({ space: 16 }) {
          ProductImage({ src: this.currentImage, cornerRadius: AppRadius.SM })
            .width(96).height(96)

          Column({ space: 6 }) {
            Row({ space: 2 }) {
              Text('¥').fontSize(18).fontColor(AppColor.PRIMARY).margin({ bottom: 2 })
              Text(String(this.getDisplayPrice())).fontSize(32).fontWeight(FontWeight.Bold)
                .fontColor(AppColor.PRIMARY)
            }.alignItems(VerticalAlign.Bottom)

            Text(this.product.name)
              .fontSize(14).fontColor(AppColor.textPrimary()).fontWeight(FontWeight.Medium)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

            Row({ space: 8 }) {
              if (this.product.hasSKU() && this.getSelectedSpecsDisplay().length > 0) {
                Text(this.getSelectedSpecsDisplay())
                  .fontSize(12).fontColor(this.matchedSKU ? AppColor.textSecondary() : AppColor.textTertiary())
              }
              Text('库存 ' + this.getStock() + '件')
                .fontSize(12).fontColor(AppColor.textTertiary())
            }
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)

          Stack() {
            Rect().width(16).height(1.8).fill(AppColor.textTertiary()).rotate({ angle: 45 })
            Rect().width(16).height(1.8).fill(AppColor.textTertiary()).rotate({ angle: -45 })
          }
          .width(28).height(28)
          .onClick(() => { this.close() })
          .margin({ top: -4 })
        }
        .width('100%')
        .padding({ left: 20, right: 12, top: 8, bottom: 16 })

        // ── SKU Specs ──
        if (this.product.hasSKU()) {
          Column({ space: 16 }) {
            ForEach(this.product.specs, (spec: ProductSpec) => {
              Column({ space: 10 }) {
                Text(spec.name)
                  .fontSize(15).fontColor(AppColor.textPrimary()).fontWeight(FontWeight.Medium)
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(spec.values, (val: string) => {
                    this.specValueItem(val, spec.name)
                  }, (val: string) => spec.name + '_' + val)
                }.width('100%')
              }
              .width('100%').alignItems(HorizontalAlign.Start)
            }, (spec: ProductSpec) => spec.name)
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }

        // ── Quantity ──
        Row() {
          Text('数量').fontSize(15).fontColor(AppColor.textPrimary())
          Blank()
          Row({ space: 0 }) {
            Row() {
              Text('-')
                .fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor(this.quantity <= 1 ? AppColor.textDisabledLight() : AppColor.PRIMARY)
                .textAlign(TextAlign.Center)
            }
            .width(32).height(32)
            .backgroundColor(this.quantity <= 1 ? AppColor.inputBg() : AppColor.primaryBg())
            .borderRadius({ topLeft: 6, bottomLeft: 6 })
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .onClick(() => { if (this.quantity > 1) this.quantity-- })

            Line().height(20).width(1).backgroundColor(AppColor.divider())

            Text(String(this.quantity))
              .width(44).height(32)
              .fontSize(15).fontWeight(FontWeight.Medium)
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColor.cardBg())

            Line().height(20).width(1).backgroundColor(AppColor.divider())

            Row() {
              Text('+')
                .fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor(this.quantity >= this.getStock() ? AppColor.textDisabledLight() : AppColor.PRIMARY)
                .textAlign(TextAlign.Center)
            }
            .width(32).height(32)
            .backgroundColor(this.quantity >= this.getStock() ? AppColor.inputBg() : AppColor.primaryBg())
            .borderRadius({ topRight: 6, bottomRight: 6 })
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .onClick(() => { if (this.quantity < this.getStock()) this.quantity++ })
          }
          .border({ width: 1, color: AppColor.border(), style: BorderStyle.Solid })
          .borderRadius(6)
          .height(32)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 12 })

        // ── Service Tags ──
        Flex({ wrap: FlexWrap.Wrap }) {
          Text('7天无理由退换')
            .fontSize(11).fontColor(AppColor.SUCCESS)
            .backgroundColor(AppColor.statusBgGreen())
            .borderRadius(4).padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .margin({ right: 8, bottom: 6 })
          Text('免运费')
            .fontSize(11).fontColor(AppColor.PRIMARY)
            .backgroundColor(AppColor.primaryBg())
            .borderRadius(4).padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .margin({ right: 8, bottom: 6 })
          Text('官方正品保障')
            .fontSize(11).fontColor(AppColor.statusBlue())
            .backgroundColor(AppColor.statusBgGreen())
            .borderRadius(4).padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .margin({ right: 8, bottom: 6 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 8 })

        // ── Total + CTA ──
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Row({ space: 2 }) {
              Text('¥').fontSize(20).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
              Text(String(this.getTotalPrice())).fontSize(28).fontColor(AppColor.PRIMARY).fontWeight(FontWeight.Bold)
            }.alignItems(VerticalAlign.Bottom)

            if (this.product.hasSKU()) {
              Text(this.getSelectedSpecsDisplay().length > 0
                ? '已选: ' + this.getSelectedSpecsDisplay()
                : '请选择规格')
                .fontSize(11).fontColor(AppColor.textTertiary())
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }

          Blank()

          AppButton({
            text: this.mode === 'add_cart' ? '加入购物车' : (this.mode === 'confirm' ? '确认商品' : '立即购买'),
            type: AppButtonType.PRIMARY,
            buttonWidth: 150,
            buttonHeight: 46,
            buttonRadius: AppRadius.XL,
            fontSize: 16,
            fontWeight: FontWeight.Bold,
            buttonOnClick: () => {
              if (this.product.hasSKU()) {
                let specNames = this.product.specs.map(s => s.name)
                let allSelected = specNames.every(n => this.selectedSpecs[n] !== undefined)
                if (!allSelected) {
                  this.getUIContext().getPromptAction().showToast({ message: '请选择完整规格' })
                  return
                }
                if (!this.currentSkuId) {
                  this.getUIContext().getPromptAction().showToast({ message: '该规格组合暂无库存' })
                  return
                }
              }
              this.onConfirm(this.currentSkuId, this.quantity)
              this.close()
            }
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 24 })
      }
      .width('100%')
      .constraintSize({ minHeight: '55%' })
      .backgroundColor(AppColor.cardBg())
      .borderRadius({ topLeft: AppRadius.XL, topRight: AppRadius.XL })
      .translate({ x: 0, y: this.panelOffset })
    }
    .width('100%').height('100%')
  }
}
