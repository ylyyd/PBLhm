import { OrderStatusValue } from '../../common/Constants'

@Observed
export class Review {
  @Track productId: number = 0
  @Track username: string = ''
  @Track rating: number = 5
  @Track date: string = ''
  @Track comment: string = ''
  @Track orderNumber: string = ''
}

@Observed
export class ProductSpec {
  @Track name: string = ''
  @Track values: string[] = []
}

@Observed
export class SKU {
  @Track id: string = ''
  @Track specs: Record<string, string> = {}
  @Track price: number = 0
  @Track stock: number = 0
  @Track image: string = ''
}

@Observed
export class Product {
  @Track id: number = 0
  @Track name: string = ''
  @Track price: number = 0
  @Track image: string = ''
  @Track images: string[] = []
  @Track description: string = ''
  @Track detailHtml: string = ''
  @Track category: string = ''
  @Track specs: ProductSpec[] = []
  @Track skus: SKU[] = []
  @Track shopId: number = 0
  @Track shopName: string = ''
  @Track salesCount: number = 0
  @Track rating: number = 0
  @Track reviewCount: number = 0
  @Track stock: number = 0

  getDefaultSKU(): SKU | undefined {
    return this.skus.length > 0 ? this.skus[0] : undefined
  }

  getSKUPrice(skuId: string): number {
    let sku = this.skus.find(s => s.id === skuId)
    return sku ? sku.price : this.price
  }

  getSKUImage(skuId: string): string {
    let sku = this.skus.find(s => s.id === skuId)
    return sku && sku.image ? sku.image : this.image
  }

  hasSKU(): boolean {
    return this.skus.length > 0
  }

  getCheapestSkuId(): string {
    if (!this.hasSKU()) return ''
    let min = this.skus[0]
    for (let i = 1; i < this.skus.length; i++) {
      if (this.skus[i].price < min.price) min = this.skus[i]
    }
    return min.id
  }

  getMinSkuPrice(): number {
    if (!this.hasSKU()) return this.price
    let min = this.skus[0].price
    for (let i = 1; i < this.skus.length; i++) {
      if (this.skus[i].price < min) min = this.skus[i].price
    }
    return min
  }

  getMaxSkuPrice(): number {
    if (!this.hasSKU()) return this.price
    let max = this.skus[0].price
    for (let i = 1; i < this.skus.length; i++) {
      if (this.skus[i].price > max) max = this.skus[i].price
    }
    return max
  }
}

@Observed
export class CartItemSKUInfo {
  @Track skuId: string = ''
  @Track skuDesc: string = ''
}

@Observed
export class CartItem {
  @Track productId: number = 0
  @Track productName: string = ''
  @Track productPrice: number = 0
  @Track productImage: string = ''
  @Track quantity: number = 0
  @Track selected: boolean = true
  @Track stock: number = 0
  @Track skuInfo: CartItemSKUInfo = new CartItemSKUInfo()

  constructor(product?: Product, quantity: number = 1, skuId?: string) {
    if (product) {
      this.productId = product.id
      this.productName = product.name
      this.productPrice = product.price
      this.productImage = product.image
      this.quantity = quantity
      this.stock = product.stock
      if (skuId && product.hasSKU()) {
        this.skuInfo.skuId = skuId
        let sku = product.skus.find(s => s.id === skuId)
        if (sku) {
          this.productPrice = sku.price
          this.productImage = sku.image || product.image
          this.stock = sku.stock
          this.skuInfo.skuDesc = Object.values(sku.specs).join(', ')
        }
      }
    }
  }

  copy(): CartItem {
    let item = new CartItem()
    item.productId = this.productId
    item.productName = this.productName
    item.productPrice = this.productPrice
    item.productImage = this.productImage
    item.quantity = this.quantity
    item.selected = this.selected
    item.stock = this.stock
    item.skuInfo.skuId = this.skuInfo.skuId
    item.skuInfo.skuDesc = this.skuInfo.skuDesc
    return item
  }

  get subtotal(): number {
    return this.productPrice * this.quantity
  }
}

@Observed
export class Order {
  @Track orderNumber: string = ''
  @Track username: string = ''
  @Track items: CartItem[] = []
  @Track totalPrice: number = 0
  @Track createTime: string = ''
  @Track status: string = OrderStatusValue.PENDING_PAYMENT
  @Track address: string = ''
  @Track cancelReason: string = ''
  @Track payMethod: string = ''
  @Track payTime: string = ''
  @Track trackingNumber: string = ''
  @Track expressCompany: string = ''
  @Track estimatedDelivery: string = ''
  @Track shipTime: string = ''
  @Track receiveTime: string = ''
  @Track paymentDeadline: string = ''
}
