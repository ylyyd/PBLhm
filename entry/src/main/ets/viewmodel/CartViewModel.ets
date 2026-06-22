import { CartItem, Product } from '../data/model/ProductModel'
import { cartRepository } from '../data/repository/CartRepository'

export class CartViewModel {
  get items(): CartItem[] {
    return cartRepository.items
  }

  get totalPrice(): number {
    return cartRepository.getTotal()
  }

  async addToCart(product: Product, skuId?: string, quantity: number = 1): Promise<void> {
    return cartRepository.addToCart(product, skuId, quantity)
  }

  async removeFromCart(productId: number, skuId?: string): Promise<void> {
    await cartRepository.removeFromCart(productId, skuId)
  }

  async updateQuantity(productId: number, quantity: number, skuId?: string): Promise<void> {
    await cartRepository.updateQuantity(productId, quantity, skuId)
  }

  selectedCheckoutKeys: string[] = []

  async clear(): Promise<void> {
    await cartRepository.clear()
  }

  isEmpty(): boolean {
    return cartRepository.items.length === 0
  }
}

export const cartViewModel = new CartViewModel()
