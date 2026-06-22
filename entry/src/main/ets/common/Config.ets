import http from '@ohos.net.http'
import { Logger } from './Logger'

export enum AppEnvironment {
  EMULATOR,
  DEVICE,
  PRODUCTION
}

const CURRENT_ENV: AppEnvironment = AppEnvironment.EMULATOR
const CANDIDATE_IPS: string[] = ['10.0.2.2', '100.100.185.161']
const DEFAULT_IP: string = '10.0.2.2'
const BACKEND_PORT: number = 3000

let _cachedHostIP: string = ''

export class AppConfig {
  /**
   * API base URL. Before init() completes, returns fallback IP.
   * After init() finishes, returns the detected host IP.
   */
  static get API_BASE_URL(): string {
    if (_cachedHostIP) {
      return `http://${_cachedHostIP}:${BACKEND_PORT}/api`
    }
    if (CURRENT_ENV === AppEnvironment.PRODUCTION) {
      return 'https://api.happybuy.example.com/api'
    }
    return `http://${DEFAULT_IP}:${BACKEND_PORT}/api`
  }

  /**
   * Detected host IP, or fallback if detection hasn't run yet.
   */
  static get HOST_IP(): string {
    return _cachedHostIP || DEFAULT_IP
  }

  /**
   * Detect the host machine IP by pinging candidate addresses.
   * Call once at app startup before any API requests.
   */
  static async init(): Promise<void> {
    if (_cachedHostIP) {
      return // already detected
    }
    if (CURRENT_ENV === AppEnvironment.PRODUCTION) {
      _cachedHostIP = DEFAULT_IP
      return
    }

    for (const ip of CANDIDATE_IPS) {
      try {
        const ok: boolean = await pingHost(ip)
        if (ok) {
          _cachedHostIP = ip
          Logger.info(`AppConfig: host detected at ${ip}`)
          return
        }
      } catch (_e) {
        // try next candidate
      }
      await delay(100)
    }

    Logger.warn('AppConfig: no host responded, using fallback')
    _cachedHostIP = DEFAULT_IP
  }

  static get ENV(): AppEnvironment {
    return CURRENT_ENV
  }

  static get IS_DEV(): boolean {
    return CURRENT_ENV !== AppEnvironment.PRODUCTION
  }
}

/**
 * Ping the backend health endpoint on a candidate IP.
 * Returns true if the server responds with 200.
 */
function pingHost(ip: string): Promise<boolean> {
  return new Promise<boolean>((resolve) => {
    let req = http.createHttp()
    req.request(`http://${ip}:${BACKEND_PORT}/health`, {
      method: http.RequestMethod.GET,
      connectTimeout: 2000,
      readTimeout: 2000
    }).then((resp: http.HttpResponse) => {
      req.destroy()
      resolve(resp.responseCode === 200)
    }).catch(() => {
      req.destroy()
      resolve(false)
    })
  })
}

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms)
  })
}
