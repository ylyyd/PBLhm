import { PasswordUtils } from '../../model/PasswordUtils'

import { AppColor, isDarkMode } from '../../common/StyleConstants'

@Observed
export class User {
  @Track username: string = ''
  @Track passwordHash: string = ''
  @Track address: string = ''
  @Track avatarColor: string = ''
  @Track avatarPath: string = ''
  @Track nickname: string = ''
  @Track phone: string = ''
  @Track points: number = 0
  @Track memberLevel: number = 0
  @Track gender: string = '保密'
  @Track age: number = 0
  @Track registrationDate: string = ''
  @Track paymentPassword: string = ''
  @Track isAdmin: boolean = false

  get memberLevelName(): string {
    return ['普通会员', '铜牌会员', '银牌会员', '金牌会员', '钻石会员'][this.memberLevel] || '普通会员'
  }

  get avatarColorIndex(): number {
    let colors = User.getAvatarColors()
    let idx = colors.indexOf(this.avatarColor)
    return idx >= 0 ? idx : 0
  }

  static getAvatarColors(): string[] {
    if (isDarkMode()) {
      return ['#FF7043', '#66BB6A', '#64B5F6', '#F06292',
              '#FFB74D', '#4DD0E1', '#CE93D8', '#90A4AE']
    }
    return ['#FF5722', '#4CAF50', '#2196F3', '#E91E63',
            '#FF9800', '#00BCD4', '#9C27B0', '#607D8B']
  }

  static getAvatarColorByIndex(index: number): string {
    let colors = User.getAvatarColors()
    return colors[index] || colors[0]
  }

  static async hashPassword(password: string): Promise<string> {
    return PasswordUtils.hash(password)
  }

  static async verifyPassword(password: string, hash: string): Promise<boolean> {
    return PasswordUtils.verify(password, hash)
  }
}
