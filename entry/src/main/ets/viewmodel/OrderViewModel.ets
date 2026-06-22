import { CartItem, Order } from '../data/model/ProductModel'
import { orderRepository } from '../data/repository/OrderRepository'

export class OrderViewModel {
  get orders(): Order[] {
    return orderRepository.getAll()
  }

  async refresh(status?: string): Promise<void> {
    await orderRepository.load(status)
  }

  async placeOrder(address: string, selectedItems?: CartItem[]): Promise<string> {
    let order = await orderRepository.createOrder(address, selectedItems)
    return order.orderNumber
  }

  async cancelOrder(orderNumber: string, reason: string = ''): Promise<void> {
    await orderRepository.cancelOrder(orderNumber, reason)
  }

  async payOrder(orderNumber: string, payMethod: string = '余额支付', paymentPassword?: string): Promise<void> {
    await orderRepository.payOrder(orderNumber, payMethod, paymentPassword)
  }

  async confirmReceive(orderNumber: string): Promise<void> {
    await orderRepository.confirmReceive(orderNumber)
  }

  async requestRefund(orderNumber: string, reason: string): Promise<void> {
    await orderRepository.requestRefund(orderNumber, reason)
  }

  async deleteOrder(orderNumber: string): Promise<void> {
    await orderRepository.deleteOrder(orderNumber)
  }

  getByNumber(orderNumber: string): Order | undefined {
    return orderRepository.getByNumber(orderNumber)
  }

  async fetchOrder(orderNumber: string): Promise<Order | null> {
    return orderRepository.fetchOrder(orderNumber)
  }

  isEmpty(): boolean {
    return orderRepository.getAll().length === 0
  }
}

export const orderViewModel = new OrderViewModel()
