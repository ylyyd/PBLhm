import { HttpClient } from '../HttpClient'
import { Logger } from '../../common/Logger'

export class SearchHistoryRepository {
  private cached: string[] = []

  async load(): Promise<void> {
    try {
      let data: Object | null = await HttpClient.getSilent('/search-history')
      if (data === null) return
      if (Array.isArray(data)) {
        this.cached = data as string[]
      } else {
        let obj = data as Record<string, Object>
        this.cached = obj.items as string[] || []
      }
    } catch (err) {
      Logger.error('SearchHistoryRepository.load failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  getAll(): string[] {
    return [...this.cached]
  }

  async add(keyword: string): Promise<void> {
    try {
      await HttpClient.post('/search-history', { 'keyword': keyword } as Record<string, Object>)
      let idx = this.cached.indexOf(keyword)
      if (idx !== -1) this.cached.splice(idx, 1)
      this.cached.unshift(keyword)
      if (this.cached.length > 20) this.cached = this.cached.slice(0, 20)
    } catch (err) {
      Logger.error('SearchHistoryRepository.add failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async remove(keyword: string): Promise<void> {
    try {
      let idx = this.cached.indexOf(keyword)
      if (idx !== -1) {
        this.cached.splice(idx, 1)
      }
    } catch (err) {
      Logger.error('SearchHistoryRepository.remove failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async clear(): Promise<void> {
    try {
      await HttpClient.delete('/search-history')
      this.cached = []
    } catch (err) {
      Logger.error('SearchHistoryRepository.clear failed: {0}', err instanceof Error ? err.message : '')
    }
  }
}

export const searchHistoryRepository = new SearchHistoryRepository()
