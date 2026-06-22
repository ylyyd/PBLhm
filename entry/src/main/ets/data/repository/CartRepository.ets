import { CartItem, Product } from '../model/ProductModel'
import { HttpClient, body } from '../HttpClient'
import { Logger } from '../../common/Logger'

class CartItemResponse {
  productId: number = 0
  productName: string = ''
  productPrice: number = 0
  productImage: string = ''
  quantity: number = 0
  skuId: string = ''
  skuDesc: string = ''
  selected: boolean = false
  stock: number = 0
}

export class CartRepository {
  items: CartItem[] = []

  async load(): Promise<void> {
    try {
      let data: Object | null = await HttpClient.getSilent('/cart')
      if (data === null) return // 401 or network error, keep stale data
      let arr: CartItemResponse[] = []
      if (Array.isArray(data)) {
        arr = data as CartItemResponse[]
      } else {
        let obj = data as Record<string, Object>
        arr = obj.items as CartItemResponse[] || []
      }
      this.items = arr.map(d => {
        let ci = new CartItem()
        ci.productId = d.productId
        ci.productName = d.productName
        ci.productPrice = d.productPrice
        ci.productImage = d.productImage
        ci.quantity = d.quantity
        ci.selected = d.selected
        ci.stock = d.stock
        ci.skuInfo.skuId = d.skuId
        ci.skuInfo.skuDesc = d.skuDesc
        return ci
      })
    } catch (err) {
      Logger.error('CartRepository.load failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async addToCart(product: Product, skuId?: string, quantity: number = 1): Promise<void> {
    // 从外部（ProductCard 等）快速加购时自动选最低价 SKU
    if (!skuId && product.hasSKU()) {
      skuId = product.getCheapestSkuId()
    }
    let sku = skuId ? product.skus.find(s => s.id === skuId) : undefined
    if (sku && sku.stock <= 0) {
      throw new Error('该商品已售罄')
    }
    let qty = Math.max(1, Math.min(quantity, sku ? sku.stock : product.stock))
    await HttpClient.post('/cart', body([['productId', product.id], ['quantity', qty], ['skuId', skuId || '']]))
    let key = skuId || ''
    let existing = this.items.find(i => i.productId === product.id && i.skuInfo.skuId === key)
    if (existing) {
      existing.quantity = existing.quantity + qty
    } else {
      let item = new CartItem(product, qty, skuId)
      this.items.push(item)
    }
  }

  async removeFromCart(productId: number, skuId?: string): Promise<void> {
    try {
      let key = skuId || ''
      let url = '/cart/' + productId + (key ? '?skuId=' + encodeURIComponent(key) : '')
      await HttpClient.delete(url)
      let idx = this.items.findIndex(i => i.productId === productId && i.skuInfo.skuId === key)
      if (idx >= 0) this.items.splice(idx, 1)
    } catch (err) {
      Logger.error('CartRepository.removeFromCart failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async updateQuantity(productId: number, quantity: number, skuId?: string): Promise<void> {
    let key = skuId || ''
    await HttpClient.put('/cart/' + productId, body([['quantity', quantity], ['skuId', key]]))
    let item = this.items.find(i => i.productId === productId && i.skuInfo.skuId === key)
    if (item) item.quantity = quantity
  }

  getItemCount(): number {
    let count = 0
    for (let i = 0; i < this.items.length; i++) {
      count += this.items[i].quantity
    }
    return count
  }

  getTotal(selectedKeys?: string[]): number {
    let total = 0
    for (let i = 0; i < this.items.length; i++) {
      let item = this.items[i]
      if (selectedKeys) {
        let key = item.productId.toString() + '_' + item.skuInfo.skuId
        if (selectedKeys.indexOf(key) === -1) continue
      }
      total += item.subtotal
    }
    return total
  }

  async clear(): Promise<void> {
    try {
      await HttpClient.delete('/cart')
      this.items = []
    } catch (err) {
      Logger.error('CartRepository.clear failed: {0}', err instanceof Error ? err.message : '')
    }
  }
}

export const cartRepository = new CartRepository()
