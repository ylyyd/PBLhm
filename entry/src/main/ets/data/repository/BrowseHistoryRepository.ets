import { HttpClient } from '../HttpClient'
import { Logger } from '../../common/Logger'

export class BrowseHistoryItem {
  productId: number = 0
  name: string = ''
  price: number = 0
  image: string = ''
  category: string = ''
  lastViewed: string = ''
}

export class BrowseHistoryRepository {
  private cached: BrowseHistoryItem[] = []

  async load(): Promise<void> {
    try {
      let data: Object | null = await HttpClient.getSilent('/browsing-history')
      if (data === null) return
      if (Array.isArray(data)) {
        this.cached = data as BrowseHistoryItem[]
      } else {
        let obj = data as Record<string, Object>
        this.cached = obj.items as BrowseHistoryItem[] || []
      }
    } catch (err) {
      Logger.error('BrowseHistoryRepository.load failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  getAll(): BrowseHistoryItem[] {
    return this.cached
  }

  async add(productId: number): Promise<void> {
    try {
      await HttpClient.post('/browsing-history', { 'productId': productId } as Record<string, Object>)
    } catch (err) {
      Logger.error('BrowseHistoryRepository.add failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async clear(): Promise<void> {
    try {
      await HttpClient.delete('/browsing-history')
      this.cached = []
    } catch (err) {
      Logger.error('BrowseHistoryRepository.clear failed: {0}', err instanceof Error ? err.message : '')
    }
  }
}

export const browseHistoryRepository = new BrowseHistoryRepository()