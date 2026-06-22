import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { DbConstants } from '../common/Constants'
import { Logger } from '../common/Logger'
import { productRepository } from './repository/ProductRepository'
import { cartRepository } from './repository/CartRepository'
import { orderRepository } from './repository/OrderRepository'
import { favoriteRepository } from './repository/FavoriteRepository'
import { sessionViewModel } from '../viewmodel/SessionViewModel'

export class DatabaseHelper {
  private static pref: preferences.Preferences | null = null

  static async init(context: common.Context): Promise<void> {
    try {
      DatabaseHelper.pref = await preferences.getPreferences(context, DbConstants.DB_NAME)
      await DatabaseHelper.loadAllData()
    } catch (err) {
      Logger.error('DatabaseHelper init failed: {0}', err)
    }
  }

  private static async loadAllData(): Promise<void> {
    try {
      let p = DatabaseHelper.pref
      if (p) {
        await sessionViewModel.init(p)
      }
      await productRepository.load()
      if (sessionViewModel.isLoggedIn()) {
        await cartRepository.load()
        await orderRepository.load()
        await favoriteRepository.load()
      }
    } catch (err) {
      Logger.error('DatabaseHelper.loadAllData failed: {0}', err)
    }
  }

  static async loadUserData(): Promise<void> {
    try {
      await cartRepository.load()
      await orderRepository.load()
      await favoriteRepository.load()
    } catch (err) {
      Logger.error('DatabaseHelper.loadUserData failed: {0}', err)
    }
  }
}
