import { ProductSpec, SKU } from '../data/model/ProductModel'
import { AppColor, AppRadius } from '../common/StyleConstants'

@Component
export struct ProductSkuSelector {
  @Prop specs: ProductSpec[] = []
  @Prop skus: SKU[] = []
  @Prop productPrice: number = 0
  @Prop productStock: number = 0
  @Prop productImage: string = ''
  @Prop hasSKU: boolean = false
  
  @State selectedSpecs: Record<string, string> = {}
  @State matchedSKU: SKU | null = null
  @State currentSkuPrice: number = 0
  @State currentSkuImage: string = ''
  @State currentSkuId: string = ''

  onSkuChange?: (selectedSpecs: Record<string, string>, matchedSKU: SKU | null, skuPrice: number, skuImage: string, skuId: string) => void

  aboutToAppear(): void {
    this.initSKUSelection()
  }

  initSKUSelection(): void {
    if (!this.hasSKU) return
    let first: Record<string, string> = {}
    for (let spec of this.specs) {
      if (spec.values.length > 0) {
        first[spec.name] = spec.values[0]
      }
    }
    this.selectedSpecs = first
    this.matchSKU()
  }

  get displayPrice(): number {
    return this.currentSkuPrice > 0 ? this.currentSkuPrice : this.productPrice
  }

  get displayStock(): number {
    if (this.hasSKU && this.matchedSKU) {
      return this.matchedSKU.stock
    }
    return this.productStock
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
  }

  matchSKU(): void {
    if (!this.hasSKU) {
      this.matchedSKU = null
      this.emitChange()
      return
    }
    let selected = this.selectedSpecs
    let specCount = 0
    let specNames: string[] = []
    for (let i = 0; i < this.specs.length; i++) {
      let name = this.specs[i].name
      specNames.push(name)
      if (selected[name] !== undefined) {
        specCount++
      }
    }
    let totalSpecs = this.specs.length
    if (specCount < totalSpecs) {
      this.matchedSKU = null
      this.currentSkuPrice = 0
      this.currentSkuImage = ''
      this.currentSkuId = ''
      this.emitChange()
      return
    }
    let found = this.skus.find(sku => {
      for (let i = 0; i < specNames.length; i++) {
        let key = specNames[i]
        if (sku.specs[key] !== selected[key]) return false
      }
      return true
    })
    this.matchedSKU = found || null
    if (found) {
      this.currentSkuPrice = found.price
      this.currentSkuImage = found.image
      this.currentSkuId = found.id
    } else {
      this.currentSkuPrice = 0
      this.currentSkuImage = ''
      this.currentSkuId = ''
    }
    this.emitChange()
  }

  emitChange(): void {
    this.onSkuChange?.(this.selectedSpecs, this.matchedSKU,
      this.currentSkuPrice, this.currentSkuImage, this.currentSkuId)
  }

  @Builder
  specValueItem(val: string, specName: string) {
    Text(val)
      .fontSize(13)
      .fontColor(this.selectedSpecs[specName] === val ? AppColor.WHITE : AppColor.textPrimary())
      .backgroundColor(this.selectedSpecs[specName] === val ? AppColor.PRIMARY : AppColor.inputBg())
      .border({ width: this.selectedSpecs[specName] === val ? 0 : 1, color: AppColor.border(), style: BorderStyle.Solid })
      .borderRadius(AppRadius.PILL)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .onClick(() => { this.selectSpec(specName, val) })
  }

  build() {
    if (this.hasSKU) {
      Column({ space: 12 }) {
        ForEach(this.specs, (spec: ProductSpec) => {
          Column({ space: 6 }) {
            Text(spec.name).fontSize(14).fontColor(AppColor.textSecondary()).fontWeight(FontWeight.Medium)
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(spec.values, (val: string) => {
                this.specValueItem(val, spec.name)
              }, (val: string) => spec.name + '_' + val)
            }.width('100%')
          }.width('100%')
        }, (spec: ProductSpec) => spec.name)
      }
      .width('100%').padding({ top: 8, bottom: 8 })
    }
  }
}
