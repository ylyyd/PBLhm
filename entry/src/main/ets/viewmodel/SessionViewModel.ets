import { User } from '../data/model/UserModel'
import { Address } from '../data/model/AddressModel'
import { userRepository } from '../data/repository/UserRepository'
import { searchHistoryRepository } from '../data/repository/SearchHistoryRepository'
import { HttpClient, HttpError } from '../data/HttpClient'
import { preferences } from '@kit.ArkData'
import { Logger } from '../common/Logger'
import { PasswordUtils } from '../model/PasswordUtils'
import { setThemeMode } from '../common/StyleConstants'

export class BrowseHistoryItem {
  productId: number = 0
  productName: string = ''
  productImage: string = ''
  productPrice: number = 0
  browseTime: string = ''
}

const KEY_TOKEN: string = 'auth_token'
const KEY_USERNAME: string = 'logged_in_username'
const KEY_ADDRESS: string = 'user_address'
const KEY_AVATAR_COLOR: string = 'user_avatar_color'
const KEY_AVATAR_PATH: string = 'user_avatar_path'
const KEY_GENDER: string = 'user_gender'
const KEY_AGE: string = 'user_age'
const KEY_NICKNAME: string = 'user_nickname'
const KEY_PHONE: string = 'user_phone'
const KEY_POINTS: string = 'user_points'
const KEY_MEMBER_LEVEL: string = 'user_member_level'
const KEY_REG_DATE: string = 'user_reg_date'
const KEY_PAYMENT_PASSWORD: string = 'user_payment_password'
const KEY_THEME_MODE: string = 'theme_mode'
const KEY_SEARCH_HISTORY: string = 'search_history'
const KEY_LAST_ADDR_ID: string = 'last_selected_address_id'
const KEY_LAST_ADDR_DETAIL: string = 'last_selected_address_detail'
const KEY_IS_ADMIN: string = 'user_is_admin'

export class SessionViewModel {
  currentUser: User | null = null
  private pref: preferences.Preferences | null = null

  async init(pref: preferences.Preferences): Promise<void> {
    this.pref = pref
    await this.restoreSession()
    await this.restoreTheme()
  }

  private async restoreTheme(): Promise<void> {
    if (!this.pref) return
    try {
      let mode = await this.pref.get(KEY_THEME_MODE, 0) as number
      setThemeMode(mode)
    } catch (err) {
      Logger.error('restoreTheme failed: {0}', err)
    }
  }

  async setThemeMode(mode: number): Promise<void> {
    setThemeMode(mode)
    if (this.pref) {
      try {
        await this.pref.put(KEY_THEME_MODE, mode)
        await this.pref.flush()
      } catch (err) {
        Logger.error('setThemeMode failed: {0}', err)
      }
    }
  }

  async getThemeMode(): Promise<number> {
    if (!this.pref) return 0
    try {
      return await this.pref.get(KEY_THEME_MODE, 0) as number
    } catch (err) {
      Logger.error('getThemeMode failed: {0}', err)
      return 0
    }
  }

  async getSearchHistory(): Promise<string[]> {
    try {
      await searchHistoryRepository.load()
      let remote = searchHistoryRepository.getAll()
      if (remote.length > 0) {
        // Sync remote to local prefs as cache
        if (this.pref) {
          await this.pref.put(KEY_SEARCH_HISTORY, remote.join(','))
          await this.pref.flush()
        }
        return remote
      }
    } catch (err) {
      Logger.error('getSearchHistory remote failed: {0}, falling back to local', err instanceof Error ? err.message : '')
    }
    if (!this.pref) return []
    try {
      let raw = await this.pref.get(KEY_SEARCH_HISTORY, '') as string
      return raw ? raw.split(',') : []
    } catch (err) {
      Logger.error('getSearchHistory local fallback failed: {0}', err)
      return []
    }
  }

  async saveSearchHistory(history: string[]): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.put(KEY_SEARCH_HISTORY, history.join(','))
      await this.pref.flush()
      // Sync latest keyword to backend
      if (history.length > 0) {
        let keyword = history[0]
        try {
          await searchHistoryRepository.add(keyword)
        } catch (_e) {
          Logger.error('saveSearchHistory backend sync failed')
        }
      }
    } catch (err) {
      Logger.error('saveSearchHistory failed: {0}', err)
    }
  }

  async clearSearchHistory(): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.put(KEY_SEARCH_HISTORY, '')
      await this.pref.flush()
      try {
        await searchHistoryRepository.clear()
      } catch (_e) {
        Logger.error('clearSearchHistory backend sync failed')
      }
    } catch (err) {
      Logger.error('clearSearchHistory failed: {0}', err)
    }
  }

  private async restoreSession(): Promise<void> {
    if (!this.pref) return
    try {
      let token = await this.pref.get(KEY_TOKEN, '') as string
      let username = await this.pref.get(KEY_USERNAME, '') as string
      if (token && username) {
        HttpClient.setToken(token)
        this.currentUser = new User()
        this.currentUser.username = username
        this.currentUser.address = await this.pref.get(KEY_ADDRESS, '') as string
        let avatarColor = await this.pref.get(KEY_AVATAR_COLOR, '') as string
        if (avatarColor) this.currentUser.avatarColor = avatarColor
        this.currentUser.avatarPath = await this.pref.get(KEY_AVATAR_PATH, '') as string
        this.currentUser.nickname = await this.pref.get(KEY_NICKNAME, '') as string
        this.currentUser.phone = await this.pref.get(KEY_PHONE, '') as string
        this.currentUser.points = await this.pref.get(KEY_POINTS, 0) as number
        this.currentUser.memberLevel = await this.pref.get(KEY_MEMBER_LEVEL, 0) as number
        this.currentUser.gender = await this.pref.get(KEY_GENDER, '保密') as string
        this.currentUser.age = await this.pref.get(KEY_AGE, 0) as number
        this.currentUser.registrationDate = await this.pref.get(KEY_REG_DATE, '') as string
        this.currentUser.paymentPassword = await this.pref.get(KEY_PAYMENT_PASSWORD, '') as string
        this.currentUser.isAdmin = (await this.pref.get(KEY_IS_ADMIN, 0) as number) === 1
        try {
          let profile = await userRepository.getProfile()
          if (profile) {
            this.currentUser.address = profile.address || this.currentUser.address
            this.currentUser.nickname = profile.nickname || this.currentUser.nickname
            this.currentUser.phone = profile.phone || this.currentUser.phone
            this.currentUser.points = profile.points || this.currentUser.points
            this.currentUser.memberLevel = profile.memberLevel || this.currentUser.memberLevel
            this.currentUser.gender = profile.gender || this.currentUser.gender
            this.currentUser.age = profile.age || this.currentUser.age
            if (profile.createdAt) this.currentUser.registrationDate = profile.createdAt
            this.currentUser.isAdmin = profile.isAdmin === true
            await this.savePrefs(token, username, this.currentUser.address, this.currentUser.avatarColor,
              this.currentUser.avatarPath, this.currentUser.gender, this.currentUser.age,
              this.currentUser.registrationDate, this.currentUser.paymentPassword, this.currentUser.nickname,
              this.currentUser.phone, this.currentUser.points, this.currentUser.memberLevel, this.currentUser.isAdmin)
          }
        } catch (err) {
          if (err instanceof HttpError && err.status === 401) {
            Logger.error('SessionViewModel.restoreSession token expired, clearing session')
            this.currentUser = null
            HttpClient.clearToken()
            await this.clearPrefs()
          } else {
            Logger.error('SessionViewModel.restoreSession profile fetch failed: {0}, keeping cached session', err instanceof Error ? err.message : '')
          }
        }
      }
    } catch (err) {
      Logger.error('SessionViewModel.restoreSession failed: {0}', err)
    }
  }

  private async savePrefs(token: string, username: string, address: string, avatarColor?: string, avatarPath?: string,
    gender?: string, age?: number, regDate?: string, paymentPwd?: string, nickname?: string, phone?: string,
    points?: number, memberLevel?: number, isAdmin?: boolean): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.put(KEY_TOKEN, token)
      await this.pref.put(KEY_USERNAME, username)
      await this.pref.put(KEY_ADDRESS, address)
      if (avatarColor !== undefined) await this.pref.put(KEY_AVATAR_COLOR, avatarColor)
      if (avatarPath !== undefined) await this.pref.put(KEY_AVATAR_PATH, avatarPath)
      if (gender !== undefined) await this.pref.put(KEY_GENDER, gender)
      if (age !== undefined) await this.pref.put(KEY_AGE, age)
      if (regDate !== undefined) await this.pref.put(KEY_REG_DATE, regDate)
      if (paymentPwd !== undefined) await this.pref.put(KEY_PAYMENT_PASSWORD, paymentPwd)
      if (nickname !== undefined) await this.pref.put(KEY_NICKNAME, nickname)
      if (phone !== undefined) await this.pref.put(KEY_PHONE, phone)
      if (points !== undefined) await this.pref.put(KEY_POINTS, points)
      if (memberLevel !== undefined) await this.pref.put(KEY_MEMBER_LEVEL, memberLevel)
      if (isAdmin !== undefined) await this.pref.put(KEY_IS_ADMIN, isAdmin ? 1 : 0)
      await this.pref.flush()
    } catch (err) {
      Logger.error('SessionViewModel.savePrefs failed: {0}', err)
    }
  }

  private async clearPrefs(): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.put(KEY_TOKEN, '')
      await this.pref.put(KEY_USERNAME, '')
      await this.pref.put(KEY_ADDRESS, '')
      await this.pref.put(KEY_AVATAR_COLOR, '')
      await this.pref.put(KEY_AVATAR_PATH, '')
      await this.pref.put(KEY_GENDER, '')
      await this.pref.put(KEY_AGE, 0)
      await this.pref.put(KEY_NICKNAME, '')
      await this.pref.put(KEY_PHONE, '')
      await this.pref.put(KEY_POINTS, 0)
      await this.pref.put(KEY_MEMBER_LEVEL, 0)
      await this.pref.put(KEY_REG_DATE, '')
      await this.pref.put(KEY_PAYMENT_PASSWORD, '')
      await this.pref.put(KEY_LAST_ADDR_ID, 0)
      await this.pref.put(KEY_LAST_ADDR_DETAIL, '')
      await this.pref.put(KEY_IS_ADMIN, 0)
      await this.pref.flush()
    } catch (err) {
      Logger.error('SessionViewModel.clearPrefs failed: {0}', err)
    }
  }

  async login(username: string, password: string): Promise<User | null> {
    try {
      let authResp = await userRepository.login(username, password)
      if (!authResp) return null
      HttpClient.setToken(authResp.token)
      let user = new User()
      user.username = authResp.username
      user.nickname = authResp.nickname || username
      if (authResp.avatar) user.avatarPath = authResp.avatar
      user.points = authResp.points
      user.memberLevel = authResp.memberLevel
      user.isAdmin = authResp.isAdmin === true
      try {
        let profile = await userRepository.getProfile()
        if (profile) {
          user.address = profile.address || ''
          user.nickname = profile.nickname || user.nickname
          user.phone = profile.phone || ''
          user.points = profile.points || user.points
          user.memberLevel = profile.memberLevel || user.memberLevel
          user.gender = profile.gender || '保密'
          user.age = profile.age || 0
          if (profile.createdAt) user.registrationDate = profile.createdAt
          if (profile.avatar) user.avatarPath = profile.avatar
        }
      } catch (err) {
        Logger.error('SessionViewModel.login profile fetch failed: {0}', err)
      }
      this.currentUser = user
      await this.savePrefs(authResp.token, username, user.address, user.avatarColor, user.avatarPath,
        user.gender, user.age, user.registrationDate, user.paymentPassword, user.nickname, user.phone,
        user.points, user.memberLevel, user.isAdmin)
      return user
    } catch (err) {
      Logger.error('SessionViewModel.login failed: {0}', err)
      return null
    }
  }

  async register(username: string, password: string, nickname?: string): Promise<string | null> {
    try {
      let authResp = await userRepository.register(username, password, nickname)
      if (!authResp) return '注册失败'
      HttpClient.setToken(authResp.token)
      let user = new User()
      user.username = username
      user.nickname = authResp.nickname || nickname || username
      user.registrationDate = new Date().toISOString().split('T')[0]
      this.currentUser = user
      await this.savePrefs(authResp.token, username, '', user.avatarColor, user.avatarPath,
        user.gender, user.age, user.registrationDate, user.paymentPassword, user.nickname, '',
        user.points, user.memberLevel, false)
      return null
    } catch (err) {
      if (err instanceof HttpError) {
        return err.message
      }
      return '注册失败，请稍后重试'
    }
  }

  async logout(): Promise<void> {
    this.currentUser = null
    HttpClient.clearToken()
    await this.clearPrefs()
  }

  async updateProfile(params: Record<string, Object>): Promise<boolean> {
    let ok = await userRepository.updateProfile(params)
    if (ok && this.currentUser) {
      if (params['address'] !== undefined) this.currentUser.address = params['address'] as string
      if (params['avatarColor'] !== undefined) this.currentUser.avatarColor = params['avatarColor'] as string
      if (params['avatarPath'] !== undefined) this.currentUser.avatarPath = params['avatarPath'] as string
      if (params['nickname'] !== undefined) this.currentUser.nickname = params['nickname'] as string
      if (params['phone'] !== undefined) this.currentUser.phone = params['phone'] as string
      if (params['gender'] !== undefined) this.currentUser.gender = params['gender'] as string
      if (params['age'] !== undefined) this.currentUser.age = params['age'] as number
      let u = this.currentUser
      await this.savePrefs(HttpClient.getToken(), u.username, u.address, u.avatarColor, u.avatarPath,
        u.gender, u.age, u.registrationDate, u.paymentPassword, u.nickname, u.phone, u.points, u.memberLevel, u.isAdmin)
    }
    return ok
  }

  async saveAvatarPath(path: string): Promise<void> {
    if (!this.currentUser) return
    this.currentUser.avatarPath = path
    await this.savePrefs(HttpClient.getToken(), this.currentUser.username, this.currentUser.address,
      this.currentUser.avatarColor, path, this.currentUser.gender, this.currentUser.age,
      this.currentUser.registrationDate, this.currentUser.paymentPassword, this.currentUser.nickname,
      this.currentUser.phone, this.currentUser.points, this.currentUser.memberLevel, this.currentUser.isAdmin)
  }

  async updatePersonalInfo(username: string, gender: string, age: number, nickname?: string, phone?: string): Promise<void> {
    if (!this.currentUser) return
    this.currentUser.username = username
    this.currentUser.gender = gender
    this.currentUser.age = age
    if (nickname !== undefined) this.currentUser.nickname = nickname
    if (phone !== undefined) this.currentUser.phone = phone
    let u = this.currentUser
    await this.savePrefs(HttpClient.getToken(), username, u.address, u.avatarColor, u.avatarPath,
      gender, age, u.registrationDate, u.paymentPassword, u.nickname, u.phone, u.points, u.memberLevel, u.isAdmin)
    try {
      let profile: Record<string, Object> = {
        'nickname': u.nickname,
        'gender': gender,
        'age': age,
        'address': u.address,
        'phone': u.phone
      }
      await userRepository.updateProfile(profile)
    } catch (err) {
      Logger.error('SessionViewModel.updatePersonalInfo server sync failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async setLastSelectedAddress(addr: Address): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.put(KEY_LAST_ADDR_ID, addr.id)
      await this.pref.put(KEY_LAST_ADDR_DETAIL, addr.detail)
      await this.pref.flush()
    } catch (err) {
      Logger.error('setLastSelectedAddress failed: {0}', err)
    }
  }

  async getLastSelectedAddressId(): Promise<number> {
    if (!this.pref) return 0
    try {
      return await this.pref.get(KEY_LAST_ADDR_ID, 0) as number
    } catch (err) {
      Logger.error('getLastSelectedAddressId failed: {0}', err)
      return 0
    }
  }

  async getLastSelectedAddressDetail(): Promise<string> {
    if (!this.pref) return ''
    try {
      return await this.pref.get(KEY_LAST_ADDR_DETAIL, '') as string
    } catch (err) {
      Logger.error('getLastSelectedAddressDetail failed: {0}', err)
      return ''
    }
  }

  async setPaymentPassword(password: string): Promise<boolean> {
    if (!this.currentUser) return false
    let ok = await userRepository.setPaymentPassword(password)
    if (ok) {
      let hash = await PasswordUtils.hash(password)
      this.currentUser.paymentPassword = hash
      let u = this.currentUser
      await this.savePrefs(HttpClient.getToken(), u.username, u.address, u.avatarColor, u.avatarPath,
        u.gender, u.age, u.registrationDate, hash, u.nickname, u.phone, u.points, u.memberLevel, u.isAdmin)
    }
    return ok
  }

  async verifyPaymentPassword(password: string): Promise<boolean> {
    if (!this.currentUser || !this.currentUser.paymentPassword) return false
    let ok = await userRepository.verifyPaymentPassword(password)
    if (ok) return true
    return await PasswordUtils.verify(password, this.currentUser.paymentPassword)
  }

  async checkPaymentPasswordExists(): Promise<boolean> {
    try {
      let res: Object = await HttpClient.get('/auth/payment-password-status')
      let data = res as Record<string, Object>
      let exists = data.exists === true
      if (exists && this.currentUser && !this.currentUser.paymentPassword) {
        // sync: backend has password but local cache is stale
        this.currentUser.paymentPassword = 'cached'
      }
      return exists
    } catch (err) {
      Logger.error('checkPaymentPasswordExists failed: {0}', err)
      return false
    }
  }

  isLoggedIn(): boolean {
    return this.currentUser !== null
  }
}

export const sessionViewModel = new SessionViewModel()