import { HttpClient, body } from '../HttpClient'
import { Logger } from '../../common/Logger'
import { Product, ProductSpec, SKU } from '../model/ProductModel'

class DashboardResponse {
  productCount: number = 0
  orderCount: number = 0
  userCount: number = 0
  revenue: number = 0
  ordersByStatus: Record<string, Object>[] = []
  recentOrders: Record<string, Object>[] = []
}

export class AdminOrderItem {
  id: number = 0
  order_number: string = ''
  product_id: number = 0
  product_name: string = ''
  product_price: number = 0
  product_image: string = ''
  quantity: number = 0
  sku_id: string = ''
  sku_desc: string = ''
}

export class AdminOrder {
  order_number: string = ''
  username: string = ''
  total_price: number = 0
  create_time: string = ''
  status: string = ''
  address: string = ''
  tracking_number: string = ''
  express_company: string = ''
  items: AdminOrderItem[] = []
}

export class AdminRepository {
  async getDashboard(): Promise<DashboardResponse> {
    try {
      let data: Object = await HttpClient.get('/admin/dashboard')
      let resp = data as Record<string, Object>
      let result = new DashboardResponse()
      result.productCount = (resp.totalProducts as number) || 0
      result.orderCount = (resp.orderCount as number) || (resp.totalOrders as number) || 0
      result.userCount = (resp.totalUsers as number) || 0
      result.revenue = (resp.totalRevenue as number) || 0
      result.ordersByStatus = Array.isArray(resp.orderStatusBreakdown) ? resp.orderStatusBreakdown as Record<string, Object>[] : []
      result.recentOrders = Array.isArray(resp.recentOrders) ? resp.recentOrders as Record<string, Object>[] : []
      return result
    } catch (err) {
      Logger.error('AdminRepository.getDashboard failed: {0}', err instanceof Error ? err.message : '')
      let empty: DashboardResponse = new DashboardResponse()
      return empty
    }
  }

  async getOrders(): Promise<AdminOrder[]> {
    try {
      let data: Object = await HttpClient.get('/admin/orders')
      if (Array.isArray(data)) {
        return data as AdminOrder[]
      }
      let obj = data as Record<string, Object>
      return obj.items as AdminOrder[] || []
    } catch (err) {
      Logger.error('AdminRepository.getOrders failed: {0}', err instanceof Error ? err.message : '')
      return []
    }
  }

  async shipOrder(orderNumber: string, trackingNumber: string, expressCompany: string): Promise<boolean> {
    try {
      await HttpClient.put('/admin/orders/' + orderNumber + '/ship', body([
        ['tracking_number', trackingNumber],
        ['express_company', expressCompany]
      ]))
      return true
    } catch (err) {
      Logger.error('AdminRepository.shipOrder failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }

  async getProducts(): Promise<Product[]> {
    try {
      let data: Object = await HttpClient.get('/admin/products')
      let raw: Record<string, Object>[]
      if (Array.isArray(data)) {
        raw = data as Record<string, Object>[]
      } else {
        let obj = data as Record<string, Object>
        raw = obj.items as Record<string, Object>[] || []
      }
      return raw.map(item => {
        let p = new Product()
        p.id = item.id as number || 0
        p.name = item.name as string || ''
        p.price = item.price as number || 0
        p.image = item.image as string || ''
        p.images = item.images as string[] || []
        p.description = item.description as string || ''
        p.detailHtml = (item.detail_html as string) || ''
        p.category = item.category as string || ''
        p.specs = item.specs as ProductSpec[] || []
        p.skus = item.skus as SKU[] || []
        p.shopId = (item.shop_id as number) || 0
        p.shopName = (item.shop_name as string) || ''
        return p
      })
    } catch (err) {
      Logger.error('AdminRepository.getProducts failed: {0}', err instanceof Error ? err.message : '')
      return []
    }
  }

  async addProduct(product: Product): Promise<number | undefined> {
    try {
      let params: [string, Object][] = [
        ['name', product.name as string],
        ['price', product.price as number],
        ['image', product.image as string || ''],
        ['description', product.description as string || ''],
        ['category', product.category as string || ''],
        ['images', product.images as Object[] || []],
        ['specs', product.specs as Object[] || []],
        ['skus', product.skus as Object[] || []]
      ]
      let data: Object = await HttpClient.post('/admin/products', body(params))
      let resp = data as Record<string, Object>
      return resp.id as number
    } catch (err) {
      Logger.error('AdminRepository.addProduct failed: {0}', err instanceof Error ? err.message : '')
      return undefined
    }
  }

  async updateProduct(id: number, product: Product): Promise<boolean> {
    try {
      let params: [string, Object][] = [
        ['name', product.name as string],
        ['price', product.price as number],
        ['image', product.image as string || ''],
        ['description', product.description as string || ''],
        ['category', product.category as string || ''],
        ['images', product.images as Object[] || []],
        ['specs', product.specs as Object[] || []],
        ['skus', product.skus as Object[] || []]
      ]
      await HttpClient.put('/admin/products/' + id, body(params))
      return true
    } catch (err) {
      Logger.error('AdminRepository.updateProduct failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }

  async deleteProduct(id: number): Promise<boolean> {
    try {
      await HttpClient.delete('/admin/products/' + id)
      return true
    } catch (err) {
      Logger.error('AdminRepository.deleteProduct failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }

  // ── Category CRUD ──

  async getCategories(): Promise<Record<string, Object>> {
    try {
      let data: Object = await HttpClient.get('/admin/categories')
      let resp = data as Record<string, Object>
      return resp
    } catch (err) {
      Logger.error('AdminRepository.getCategories failed: {0}', err instanceof Error ? err.message : '')
      return {}
    }
  }

  async addCategory(name: string, parentId?: number, icon?: string): Promise<boolean> {
    try {
      let params: [string, Object][] = [['name', name]]
      if (parentId !== undefined) params.push(['parentId', parentId])
      if (icon) params.push(['icon', icon])
      await HttpClient.post('/admin/categories', body(params))
      return true
    } catch (err) {
      Logger.error('AdminRepository.addCategory failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }

  async updateCategory(id: number, fields: Record<string, Object>): Promise<boolean> {
    try {
      let params: [string, Object][] = []
      if (fields.name !== undefined) params.push(['name', fields.name as string])
      if (fields.icon !== undefined) params.push(['icon', fields.icon as string])
      if (fields.sortOrder !== undefined) params.push(['sortOrder', fields.sortOrder as number])
      await HttpClient.put('/admin/categories/' + id, body(params))
      return true
    } catch (err) {
      Logger.error('AdminRepository.updateCategory failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }

  async deleteCategory(id: number): Promise<boolean> {
    try {
      await HttpClient.delete('/admin/categories/' + id)
      return true
    } catch (err) {
      Logger.error('AdminRepository.deleteCategory failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }

  async sortCategories(items: Record<string, Object>[]): Promise<boolean> {
    try {
      await HttpClient.put('/admin/categories/sort', body([['items', items]]))
      return true
    } catch (err) {
      Logger.error('AdminRepository.sortCategories failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }
}

export const adminRepository = new AdminRepository()
