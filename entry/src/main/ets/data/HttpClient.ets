import http from '@ohos.net.http'
import { Logger } from '../common/Logger'
import { AppConfig } from '../common/Config'

export function body(entries: [string, Object][]): Record<string, Object> {
  let result: Record<string, Object> = {}
  for (let i = 0; i < entries.length; i++) {
    result[entries[i][0]] = entries[i][1]
  }
  return result
}

export class HttpError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

let redirectToLoginHandler: (() => void) | null = null
let isRedirecting: boolean = false

export function setRedirectToLoginHandler(handler: () => void): void {
  redirectToLoginHandler = handler
}

export class HttpClient {
  static BASE_URL: string = AppConfig.API_BASE_URL
  private static token: string = ''

  static setToken(t: string): void {
    HttpClient.token = t
    isRedirecting = false
  }

  static getToken(): string {
    return HttpClient.token
  }

  static clearToken(): void {
    HttpClient.token = ''
  }

  private static async handleUnauthorized(): Promise<void> {
    HttpClient.clearToken()
    if (isRedirecting) return
    isRedirecting = true
    if (redirectToLoginHandler) {
      redirectToLoginHandler()
    }
  }

  private static makeRequest(path: string, method: http.RequestMethod, extraData?: string, silent: boolean = false): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      let httpRequest = http.createHttp()
      let headers: Record<string, string> = {
        'Content-Type': 'application/json'
      }
      if (HttpClient.token) {
        headers['Authorization'] = 'Bearer ' + HttpClient.token
      }
      httpRequest.request(HttpClient.BASE_URL + path, {
        method: method,
        header: headers,
        extraData: extraData,
        connectTimeout: 3000,
        readTimeout: 3000
      }).then((resp: http.HttpResponse) => {
        let result = resp.result as string
        if (resp.responseCode >= 200 && resp.responseCode < 300) {
          resolve(result)
        } else if (resp.responseCode === 401) {
          // 非 silent 请求才触发登录失效弹窗；silent 请求（后台刷新）静默处理
          if (!silent) {
            HttpClient.handleUnauthorized()
          }
          reject(new HttpError('登录已过期，请重新登录', 401))
        } else {
          let msg: string = '请求失败'
          try {
            let parsed: Record<string, Object> = JSON.parse(result)
            if (parsed['error']) {
              msg = parsed['error'] as string
            }
          } catch {} 
          reject(new HttpError(msg, resp.responseCode))
        }
        httpRequest.destroy()
      }).catch((err: Error) => {
        Logger.error('HttpClient request failed: {0}', JSON.stringify(err))
        reject(new HttpError('网络请求失败，请检查网络连接', 0))
        httpRequest.destroy()
      })
    })
  }

  static async get(path: string): Promise<Object> {
    let result = await HttpClient.makeRequest(path, http.RequestMethod.GET)
    if (result) {
      try { return JSON.parse(result) } catch {}
    }
    let empty: Record<string, Object> = {}
    return empty
  }

  static async getSilent(path: string): Promise<Object | null> {
    try {
      let result = await HttpClient.makeRequest(path, http.RequestMethod.GET, undefined, true)
      if (result) {
        try { return JSON.parse(result) } catch {}
      }
    } catch (err) {
      if (err instanceof HttpError && err.status === 401) return null
      Logger.error('HttpClient.getSilent failed: {0}', err instanceof Error ? err.message : '')
      return null
    }
    let empty: Record<string, Object> = {}
    return empty
  }

  static async post(path: string, data: Record<string, Object>): Promise<Object> {
    let result = await HttpClient.makeRequest(path, http.RequestMethod.POST, JSON.stringify(data))
    if (result) {
      try { return JSON.parse(result) } catch {}
    }
    let empty: Record<string, Object> = {}
    return empty
  }

  static async postSilent(path: string, data: Record<string, Object>): Promise<Object | null> {
    try {
      let result = await HttpClient.makeRequest(path, http.RequestMethod.POST, JSON.stringify(data), true)
      if (result) {
        try { return JSON.parse(result) } catch {}
      }
    } catch (err) {
      if (err instanceof HttpError && err.status === 401) return null
      Logger.error('HttpClient.postSilent failed: {0}', err instanceof Error ? err.message : '')
      return null
    }
    let empty: Record<string, Object> = {}
    return empty
  }

  static async put(path: string, data: Record<string, Object>): Promise<Object> {
    let result = await HttpClient.makeRequest(path, http.RequestMethod.PUT, JSON.stringify(data))
    if (result) {
      try { return JSON.parse(result) } catch {}
    }
    let empty: Record<string, Object> = {}
    return empty
  }

  static async putSilent(path: string, data: Record<string, Object>): Promise<Object | null> {
    try {
      let result = await HttpClient.makeRequest(path, http.RequestMethod.PUT, JSON.stringify(data), true)
      if (result) {
        try { return JSON.parse(result) } catch {}
      }
    } catch (err) {
      if (err instanceof HttpError && err.status === 401) return null
      Logger.error('HttpClient.putSilent failed: {0}', err instanceof Error ? err.message : '')
      return null
    }
    let empty: Record<string, Object> = {}
    return empty
  }

  static async delete(path: string): Promise<Object> {
    let result = await HttpClient.makeRequest(path, http.RequestMethod.DELETE)
    if (result) {
      try { return JSON.parse(result) } catch {}
    }
    let empty: Record<string, Object> = {}
    return empty
  }

  static async deleteSilent(path: string): Promise<Object | null> {
    try {
      let result = await HttpClient.makeRequest(path, http.RequestMethod.DELETE, undefined, true)
      if (result) {
        try { return JSON.parse(result) } catch {}
      }
    } catch (err) {
      if (err instanceof HttpError && err.status === 401) return null
      Logger.error('HttpClient.deleteSilent failed: {0}', err instanceof Error ? err.message : '')
      return null
    }
    let empty: Record<string, Object> = {}
    return empty
  }
}
