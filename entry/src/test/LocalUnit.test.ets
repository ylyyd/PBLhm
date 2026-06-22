import { describe, beforeAll, beforeEach, it, expect } from '@ohos/hypium';
import { Product } from '../main/ets/data/model/ProductModel'
import { productRepository } from '../main/ets/data/repository/ProductRepository'
import { cartRepository } from '../main/ets/data/repository/CartRepository'

export default function localUnitTest() {
  describe('ProductRepository', () => {
    it('getAll_should_return_all_products', 0, () => {
      let products = productRepository.getAll()
      expect(products.length).assertEqual(20)
    })

    it('getById_should_return_correct_product', 0, () => {
      let product = productRepository.getById(1)
      expect(product).not().assertNull()
      if (product) {
        expect(product.name).assertEqual('华为Mate60 Pro')
      }
    })

    it('getById_should_return_null_for_unknown_id', 0, () => {
      let product = productRepository.getById(999)
      expect(product).assertNull()
    })

    it('search_should_filter_by_category', 0, () => {
      let results = productRepository.search('', '手机')
      expect(results.length).assertEqual(4)
    })

    it('search_should_filter_by_keyword', 0, () => {
      let results = productRepository.search('华为', '全部')
      expect(results.length).assertEqual(2)
      expect(results[0].id).assertEqual(1)
    })

    it('search_should_return_all_for_empty_keyword_and_all_category', 0, () => {
      let results = productRepository.search('', '全部')
      expect(results.length).assertEqual(20)
    })

    it('getCategories_should_return_all_categories', 0, () => {
      let cats = productRepository.getParentCategories()
      expect(cats.length).assertEqual(6)
      expect(cats[0]).assertEqual('全部')
    })
  })

  describe('CartRepository', () => {
    let product1: Product
    let product2: Product

    beforeAll(() => {
      product1 = productRepository.getById(1)!
      product2 = productRepository.getById(2)!
    })

    beforeEach(() => {
      cartRepository.clear()
    })

    it('addToCart_should_add_new_item', 0, () => {
      cartRepository.addToCart(product1)
      expect(cartRepository.items.length).assertEqual(1)
      expect(cartRepository.items[0].productId).assertEqual(product1.id)
      expect(cartRepository.items[0].quantity).assertEqual(1)
    })

    it('addToCart_should_increase_quantity_for_existing_item', 0, () => {
      cartRepository.addToCart(product1)
      cartRepository.addToCart(product1)
      expect(cartRepository.items.length).assertEqual(1)
      expect(cartRepository.items[0].quantity).assertEqual(2)
    })

    it('addToCart_should_handle_multiple_products', 0, () => {
      cartRepository.addToCart(product1)
      cartRepository.addToCart(product2)
      expect(cartRepository.items.length).assertEqual(2)
    })

    it('removeFromCart_should_remove_item', 0, () => {
      cartRepository.addToCart(product1)
      cartRepository.addToCart(product2)
      cartRepository.removeFromCart(product1.id)
      expect(cartRepository.items.length).assertEqual(1)
      expect(cartRepository.items[0].productId).assertEqual(product2.id)
    })

    it('updateQuantity_should_change_quantity', 0, () => {
      cartRepository.addToCart(product1)
      cartRepository.updateQuantity(product1.id, 5)
      expect(cartRepository.items[0].quantity).assertEqual(5)
    })

    it('getTotal_should_be_zero_for_empty_cart', 0, () => {
      expect(cartRepository.getTotal()).assertEqual(0)
    })

    it('getTotal_should_calculate_correctly', 0, () => {
      cartRepository.addToCart(product1)
      cartRepository.addToCart(product1)
      expect(cartRepository.getTotal()).assertEqual(product1.price * 2)
    })

    it('clear_should_empty_cart', 0, () => {
      cartRepository.addToCart(product1)
      cartRepository.addToCart(product2)
      cartRepository.clear()
      expect(cartRepository.items.length).assertEqual(0)
    })

    it('getItemCount_should_return_total_quantity', 0, () => {
      cartRepository.addToCart(product1)
      cartRepository.addToCart(product1)
      cartRepository.addToCart(product2)
      expect(cartRepository.getItemCount()).assertEqual(3)
    })
  })
}
