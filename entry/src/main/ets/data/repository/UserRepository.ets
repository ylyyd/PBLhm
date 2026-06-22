import { User } from '../model/UserModel'
import { HttpClient, body } from '../HttpClient'

class AuthResponse {
  token: string = ''
  username: string = ''
  nickname: string = ''
  avatar: string = ''
  points: number = 0
  memberLevel: number = 0
  isAdmin: boolean = false
}

class ProfileResponse {
  username: string = ''
  nickname: string = ''
  avatar: string = ''
  phone: string = ''
  address: string = ''
  points: number = 0
  memberLevel: number = 0
  createdAt: string = ''
  gender: string = '保密'
  age: number = 0
  isAdmin: boolean = false
}

export class UserRepository {
  async register(username: string, password: string, nickname?: string): Promise<AuthResponse | null> {
    let data: Object = await HttpClient.post('/auth/register', body([
      ['username', username],
      ['password', password],
      ['nickname', nickname || username]
    ]))
    return data as AuthResponse
  }

  async login(username: string, password: string): Promise<AuthResponse | null> {
    let data: Object = await HttpClient.post('/auth/login', body([
      ['username', username],
      ['password', password]
    ]))
    return data as AuthResponse
  }

  async getProfile(): Promise<ProfileResponse | null> {
    try {
      let data: Object | null = await HttpClient.getSilent('/auth/profile')
      if (data === null) return null // 401 or network error
      return data as ProfileResponse
    } catch (err) {
      return null
    }
  }

  async updateProfile(params: Record<string, Object>): Promise<boolean> {
    try {
      await HttpClient.put('/auth/profile', body(Object.entries(params) as [string, Object][]))
      return true
    } catch (err) {
      return false
    }
  }

  async setPaymentPassword(password: string): Promise<boolean> {
    try {
      await HttpClient.post('/auth/payment-password', body([['password', password]]))
      return true
    } catch (err) {
      return false
    }
  }

  async verifyPaymentPassword(password: string): Promise<boolean> {
    try {
      let data: Object = await HttpClient.post('/auth/verify-payment-password', body([['password', password]]))
      let resp = data as Record<string, Object>
      return resp.success === true
    } catch (err) {
      return false
    }
  }
}

export const userRepository = new UserRepository()