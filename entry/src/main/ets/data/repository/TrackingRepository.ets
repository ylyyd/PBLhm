import { HttpClient } from '../HttpClient'
import { Logger } from '../../common/Logger'

export class TrackingPoint {
  time: string = ''
  desc: string = ''
  location: string = ''
}

export class TrackingInfo {
  expressCompany: string = ''
  trackingNumber: string = ''
  tracking: TrackingPoint[] = []
}

export class TrackingRepository {
  async getTracking(orderNumber: string): Promise<TrackingInfo> {
    try {
      let data: Object | null = await HttpClient.getSilent('/tracking/' + orderNumber)
      if (data === null) return new TrackingInfo()
      let resp = data as Record<string, Object>
      let info = new TrackingInfo()
      info.expressCompany = resp.expressCompany as string || ''
      info.trackingNumber = resp.trackingNumber as string || ''
      let rawPoints: Object[] = Array.isArray(resp.tracking) ? resp.tracking as Object[] : []
      info.tracking = rawPoints.map((p: Object) => {
        let point = p as Record<string, Object>
        let tp = new TrackingPoint()
        tp.time = point.time as string || ''
        tp.desc = point.desc as string || ''
        tp.location = point.location as string || ''
        return tp
      })
      return info
    } catch (err) {
      Logger.error('TrackingRepository.getTracking failed: {0}', err instanceof Error ? err.message : '')
      return new TrackingInfo()
    }
  }
}

export const trackingRepository = new TrackingRepository()
