import { CartItem, Order } from '../model/ProductModel'
import { HttpClient, body } from '../HttpClient'
import { OrderStatusValue } from '../../common/Constants'
import { cartRepository } from './CartRepository'
import { sessionViewModel } from '../../viewmodel/SessionViewModel'
import { Logger } from '../../common/Logger'

class OrderItemResponse {
  productId: number = 0
  productName: string = ''
  productPrice: number = 0
  productImage: string = ''
  quantity: number = 0
  subtotal: number = 0
  skuId: string = ''
  skuDesc: string = ''
}

class OrderResponse {
  orderNumber: string = ''
  username: string = ''
  totalPrice: number = 0
  createTime: string = ''
  status: string = ''
  address: string = ''
  cancelReason: string = ''
  payMethod: string = ''
  payTime: string = ''
  trackingNumber: string = ''
  expressCompany: string = ''
  estimatedDelivery: string = ''
  shipTime: string = ''
  receiveTime: string = ''
  paymentDeadline: string = ''
  items: OrderItemResponse[] = []
}

class CreateOrderResponse {
  orderNumber: string = ''
  totalPrice: number = 0
  originalTotal: number = 0
  shippingFee: number = 0
  discountAmount: number = 0
  createTime: string = ''
  status: string = ''
  address: string = ''
  paymentDeadline: string = ''
}

export class OrderRepository {
  orders: Order[] = []

  async load(status?: string): Promise<void> {
    try {
      let path = '/orders'
      if (status) {
        path = path + '?status=' + encodeURIComponent(status)
      }
      let data: Object | null = await HttpClient.getSilent(path)
      if (data === null) return // 401 or network error, keep stale data
      let arr: OrderResponse[] = []
      if (Array.isArray(data)) {
        arr = data as OrderResponse[]
      } else {
        let obj = data as Record<string, Object>
        arr = obj.items as OrderResponse[] || []
      }
      this.orders = arr.map(o => this.mapOrder(o))
    } catch (err) {
      Logger.error('OrderRepository.load failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async createOrder(address: string, selectedItems?: CartItem[]): Promise<Order> {
    let params: [string, Object][] = [['address', address]]
    if (selectedItems && selectedItems.length > 0) {
      let itemsArr: Object[] = []
      for (let i = 0; i < selectedItems.length; i++) {
        let si = selectedItems[i]
        let itemObj: Record<string, Object> = {
          'product_id': si.productId,
          'quantity': si.quantity,
          'sku_id': si.skuInfo.skuId || '',
          'sku_desc': si.skuInfo.skuDesc || ''
        }
        itemsArr.push(itemObj)
      }
      params.push(['items', itemsArr])
    }
    let data: Object = await HttpClient.post('/orders', body(params))
    let resp = data as CreateOrderResponse
    let order = new Order()
    order.orderNumber = resp.orderNumber
    order.totalPrice = resp.totalPrice
    order.createTime = resp.createTime
    order.status = resp.status
    order.address = resp.address
    order.paymentDeadline = resp.paymentDeadline
    order.username = sessionViewModel.currentUser?.username || ''
    order.items = selectedItems ? [...selectedItems] : []
    this.orders.unshift(order)
    // Only clear locally the items that were actually ordered
    if (selectedItems && selectedItems.length > 0) {
      for (const si of selectedItems) {
        let idx = cartRepository.items.findIndex(ci => ci.productId === si.productId && ci.skuInfo.skuId === si.skuInfo.skuId)
        if (idx !== -1) {
          cartRepository.items.splice(idx, 1)
        }
      }
    } else {
      cartRepository.items = []
    }
    return order
  }

  async cancelOrder(orderNumber: string, reason: string = ''): Promise<void> {
    await HttpClient.put('/orders/' + orderNumber + '/cancel', body([['reason', reason]]))
    let order = this.orders.find(o => o.orderNumber === orderNumber)
    if (order) {
      order.status = OrderStatusValue.CANCELLED
      order.cancelReason = reason
    }
  }

  async payOrder(orderNumber: string, payMethod: string = '余额支付', paymentPassword?: string): Promise<void> {
    let params: [string, Object][] = [['payMethod', payMethod]]
    if (paymentPassword) {
      params.push(['paymentPassword', paymentPassword])
    }
    let data: Object = await HttpClient.post('/payment/direct/' + orderNumber, body(params))
    let resp = data as Record<string, Object>
    let order = this.orders.find(o => o.orderNumber === orderNumber)
    if (order) {
      order.status = OrderStatusValue.PENDING_SHIP
      order.payMethod = payMethod
      order.payTime = new Date().toISOString()
    }
  }

  async confirmReceive(orderNumber: string): Promise<void> {
    await HttpClient.put('/orders/' + orderNumber + '/receive', body([]))
    let order = this.orders.find(o => o.orderNumber === orderNumber)
    if (order) {
      order.status = OrderStatusValue.COMPLETED
      order.receiveTime = new Date().toISOString()
    }
  }

  async requestRefund(orderNumber: string, reason: string): Promise<void> {
    await HttpClient.put('/orders/' + orderNumber + '/refund', body([['reason', reason]]))
    let order = this.orders.find(o => o.orderNumber === orderNumber)
    if (order) {
      order.status = OrderStatusValue.REFUNDING
      order.cancelReason = reason
    }
  }

  async deleteOrder(orderNumber: string): Promise<void> {
    await HttpClient.delete('/orders/' + orderNumber)
    let idx = this.orders.findIndex(o => o.orderNumber === orderNumber)
    if (idx >= 0) this.orders.splice(idx, 1)
  }

  getByNumber(orderNumber: string): Order | undefined {
    return this.orders.find(o => o.orderNumber === orderNumber)
  }

  async fetchOrder(orderNumber: string): Promise<Order | null> {
    try {
      const data: Object = await HttpClient.get('/orders/' + orderNumber)
      const resp = data as OrderResponse
      if (!resp || !resp.orderNumber) return null
      const order = this.mapOrder(resp)
      const existing = this.orders.findIndex(o => o.orderNumber === orderNumber)
      if (existing >= 0) {
        this.orders[existing] = order
      } else {
        this.orders.unshift(order)
      }
      return order
    } catch (err) {
      return null
    }
  }

  getAll(): Order[] {
    return this.orders
  }

  private mapOrder(o: OrderResponse): Order {
    let order = new Order()
    order.orderNumber = o.orderNumber
    order.username = o.username
    order.totalPrice = o.totalPrice
    order.createTime = o.createTime
    order.status = o.status
    order.address = o.address
    order.cancelReason = o.cancelReason || ''
    order.payMethod = o.payMethod || ''
    order.payTime = o.payTime || ''
    order.trackingNumber = o.trackingNumber || ''
    order.expressCompany = o.expressCompany || ''
    order.estimatedDelivery = o.estimatedDelivery || ''
    order.shipTime = o.shipTime || ''
    order.receiveTime = o.receiveTime || ''
    order.paymentDeadline = o.paymentDeadline || ''
    order.items = (o.items || []).map((i: OrderItemResponse) => {
      let ci = new CartItem()
      ci.productId = i.productId
      ci.productName = i.productName
      ci.productPrice = i.productPrice
      ci.productImage = i.productImage
      ci.quantity = i.quantity
      ci.skuInfo.skuId = i.skuId
      ci.skuInfo.skuDesc = i.skuDesc
      return ci
    })
    return order
  }
}

export const orderRepository = new OrderRepository()
