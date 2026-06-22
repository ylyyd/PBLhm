import { HttpClient, body } from '../HttpClient'
import { Logger } from '../../common/Logger'

class ToggleResponse {
  favorited: boolean = false
}

export class FavoriteRepository {
  private cachedIds: Set<number> = new Set()

  async load(): Promise<void> {
    try {
      let data: Object | null = await HttpClient.getSilent('/favorites')
      if (data === null) return // 401 or network error, keep stale data
      let ids: number[] = []
      if (Array.isArray(data)) {
        ids = data as number[]
      } else {
        let obj = data as Record<string, Object>
        ids = obj.favorites as number[] || []
      }
      this.cachedIds = new Set(ids)
    } catch (err) {
      Logger.error('FavoriteRepository.load failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async toggle(id: number): Promise<boolean> {
    let data: Object = await HttpClient.post('/favorites/' + id, body([]))
    let resp = data as ToggleResponse
    if (resp.favorited) {
      this.cachedIds.add(id)
    } else {
      this.cachedIds.delete(id)
    }
    return resp.favorited
  }

  isFavorited(id: number): boolean {
    return this.cachedIds.has(id)
  }

  getAll(): number[] {
    let arr: number[] = []
    this.cachedIds.forEach(id => arr.push(id))
    return arr
  }

  async clearAll(): Promise<void> {
    await HttpClient.delete('/favorites/clear')
    this.cachedIds.clear()
  }
}

export const favoriteRepository = new FavoriteRepository()
