import { Review } from '../model/ProductModel'
import { HttpClient, body, HttpError } from '../HttpClient'
import { Logger } from '../../common/Logger'

class ReviewResponse {
  productId: number = 0
  username: string = ''
  rating: number = 0
  date: string = ''
  comment: string = ''
  orderNumber: string = ''
}

class ReviewKeyResponse {
  productId: number = 0
  orderNumber: string = ''
}

export class ReviewRepository {
  async getReviews(productId: number): Promise<Review[]> {
    try {
      let data: Object = await HttpClient.get('/reviews/product/' + productId)
      let arr: ReviewResponse[] = []
      if (Array.isArray(data)) {
        arr = data as ReviewResponse[]
      } else {
        let obj = data as Record<string, Object>
        arr = obj.items as ReviewResponse[] || []
      }
      return arr.map(r => this.mapReview(r))
    } catch (err) {
      Logger.error('ReviewRepository.getReviews failed: {0}', err instanceof Error ? err.message : '')
      return []
    }
  }

  async getUserReviews(username: string): Promise<Review[]> {
    try {
      let data: Object = await HttpClient.get('/reviews/user/' + username)
      let arr: ReviewResponse[] = []
      if (Array.isArray(data)) {
        arr = data as ReviewResponse[]
      } else {
        let obj = data as Record<string, Object>
        arr = obj.items as ReviewResponse[] || []
      }
      return arr.map(r => this.mapReview(r))
    } catch (err) {
      Logger.error('ReviewRepository.getUserReviews failed: {0}', err instanceof Error ? err.message : '')
      return []
    }
  }

  async getReviewHistory(username: string): Promise<string[]> {
    try {
      let data: Object = await HttpClient.get('/reviews/user/' + username + '/history')
      let arr: ReviewKeyResponse[] = []
      if (Array.isArray(data)) {
        arr = data as ReviewKeyResponse[]
      } else {
        let obj = data as Record<string, Object>
        arr = obj.keys as ReviewKeyResponse[] || []
      }
      return arr.map(r => r.orderNumber + '_' + r.productId.toString())
    } catch (err) {
      Logger.error('ReviewRepository.getReviewHistory failed: {0}', err instanceof Error ? err.message : '')
      return []
    }
  }

  async deleteReview(productId: number, orderNumber: string = ''): Promise<boolean> {
    try {
      let path = '/reviews/product/' + productId
      if (orderNumber) {
        path = path + '?orderNumber=' + encodeURIComponent(orderNumber)
      }
      await HttpClient.delete(path)
      return true
    } catch (err) {
      Logger.error('ReviewRepository.deleteReview failed: {0}', err instanceof Error ? err.message : '')
      return false
    }
  }

  async addReview(review: Review): Promise<string> {
    try {
      let params: [string, Object][] = [
        ['rating', review.rating],
        ['comment', review.comment]
      ]
      if (review.orderNumber) {
        params.push(['orderNumber', review.orderNumber])
      }
      await HttpClient.post('/reviews/product/' + review.productId, body(params))
      return ''
    } catch (err) {
      let msg = err instanceof HttpError ? err.message : '提交评价失败，请稍后重试'
      Logger.error('ReviewRepository.addReview failed: {0}', msg)
      return msg
    }
  }

  async getAverageRating(productId: number): Promise<number> {
    try {
      let data: Object = await HttpClient.get('/reviews/product/' + productId + '/average')
      let obj = data as Record<string, Object>
      return obj.average as number
    } catch (err) {
      Logger.error('ReviewRepository.getAverageRating failed: {0}', err instanceof Error ? err.message : '')
      return 0
    }
  }

  private mapReview(r: ReviewResponse): Review {
    let review = new Review()
    review.productId = r.productId
    review.username = r.username
    review.rating = r.rating
    review.date = r.date
    review.comment = r.comment
    review.orderNumber = r.orderNumber || ''
    return review
  }
}

export const reviewRepository = new ReviewRepository()
