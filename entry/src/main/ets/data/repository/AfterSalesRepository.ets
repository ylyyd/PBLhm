import { HttpClient, body, HttpError } from '../HttpClient'
import { Logger } from '../../common/Logger'

export class AfterSalesItem {
  id: number = 0
  orderNumber: string = ''
  username: string = ''
  productId: number = 0
  type: string = 'refund'
  reason: string = ''
  imageEvidence: string = ''
  status: string = 'pending'
  applyTime: string = ''
  processTime: string = ''
  processNote: string = ''
  returnTracking: string = ''
  refundAmount: number = 0
  orderStatus: string = ''
  currentOrderStatus: string = ''  // 来自 LEFT JOIN orders.status，实时订单状态
}

export class AfterSalesRepository {
  async create(orderNumber: string, productId: number, type: string, reason: string, refundAmount: number): Promise<boolean> {
    try {
      await HttpClient.post('/aftersales', body([
        ['orderNumber', orderNumber],
        ['productId', productId],
        ['type', type],
        ['reason', reason],
        ['refundAmount', refundAmount]
      ]))
      return true
    } catch (err) {
      Logger.error('AfterSalesRepository.create failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }

  private mapItem(raw: Record<string, Object>): AfterSalesItem {
    let item = new AfterSalesItem()
    item.id = raw.id as number || 0
    item.orderNumber = (raw.orderNumber || raw.order_number) as string || ''
    item.username = raw.username as string || ''
    item.productId = (raw.productId || raw.product_id) as number || 0
    item.type = raw.type as string || 'refund'
    item.reason = raw.reason as string || ''
    item.imageEvidence = (raw.imageEvidence || raw.image_evidence) as string || ''
    item.status = raw.status as string || 'pending'
    item.applyTime = (raw.applyTime || raw.apply_time) as string || ''
    item.processTime = (raw.processTime || raw.process_time) as string || ''
    item.processNote = (raw.processNote || raw.process_note) as string || ''
    item.returnTracking = (raw.returnTracking || raw.return_tracking) as string || ''
    item.refundAmount = (raw.refundAmount || raw.refund_amount) as number || 0
    item.orderStatus = (raw.orderStatus || raw.order_status) as string || ''
    item.currentOrderStatus = (raw.currentOrderStatus || raw.current_order_status) as string || ''
    return item
  }

  async getByOrder(orderNumber: string): Promise<AfterSalesItem | null> {
    try {
      let data: Object = await HttpClient.get('/aftersales/' + orderNumber)
      return this.mapItem(data as Record<string, Object>)
    } catch (err) {
      if (err instanceof HttpError && err.status === 404) return null
      Logger.error('AfterSalesRepository.getByOrder failed: {0}', err instanceof Error ? err.message : '')
      return null
    }
  }

  async getAll(): Promise<AfterSalesItem[]> {
    try {
      let data: Object | null = await HttpClient.getSilent('/aftersales')
      if (data === null) return []
      if (Array.isArray(data)) {
        return (data as Record<string, Object>[]).map(r => this.mapItem(r))
      }
      let obj = data as Record<string, Object>
      return (obj.items as Record<string, Object>[] || []).map(r => this.mapItem(r))
    } catch (err) {
      Logger.error('AfterSalesRepository.getAll failed: {0}', err instanceof Error ? err.message : '')
      return []
    }
  }

  async deleteRecord(id: number): Promise<boolean> {
    try {
      await HttpClient.delete('/aftersales/' + id)
      return true
    } catch (err) {
      Logger.error('AfterSalesRepository.cancel failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }
}

export const afterSalesRepository = new AfterSalesRepository()