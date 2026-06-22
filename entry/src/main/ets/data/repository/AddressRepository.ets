import { Address } from '../model/AddressModel'
import { HttpClient, body } from '../HttpClient'
import { Logger } from '../../common/Logger'

class AddressResponse {
  id: number = 0
  label: string = ''
  recipientName: string = ''
  phone: string = ''
  detail: string = ''
  isDefault: boolean = false
}

export class AddressRepository {
  async getAddresses(): Promise<Address[]> {
    try {
      let data: Object | null = await HttpClient.getSilent('/addresses')
      if (data === null) return [] // 401 or network error, return empty
      let arr: AddressResponse[] = []
      if (Array.isArray(data)) {
        arr = data as AddressResponse[]
      } else {
        let obj = data as Record<string, Object>
        arr = obj.addresses as AddressResponse[] || []
      }
      return arr.map(a => {
        let addr = new Address()
        addr.id = a.id
        addr.label = (a.label !== undefined && a.label !== null) ? String(a.label) : ''
        addr.recipientName = (a.recipientName !== undefined && a.recipientName !== null) ? String(a.recipientName) : ''
        addr.phone = (a.phone !== undefined && a.phone !== null) ? String(a.phone) : ''
        addr.detail = (a.detail !== undefined && a.detail !== null) ? String(a.detail) : ''
        addr.isDefault = a.isDefault === true
        return addr
      })
    } catch (err) {
      Logger.error('AddressRepository.getAddresses failed: {0}', err instanceof Error ? err.message : '')
      return []
    }
  }

  async addAddress(addr: Address): Promise<void> {
    await HttpClient.post('/addresses', body([
      ['label', addr.label],
      ['recipientName', addr.recipientName],
      ['phone', addr.phone],
      ['detail', addr.detail],
      ['isDefault', addr.isDefault]
    ]))
  }

  async updateAddress(addr: Address): Promise<void> {
    await HttpClient.put('/addresses/' + addr.id, body([
      ['label', addr.label],
      ['recipientName', addr.recipientName],
      ['phone', addr.phone],
      ['detail', addr.detail],
      ['isDefault', addr.isDefault]
    ]))
  }

  async deleteAddress(id: number): Promise<void> {
    await HttpClient.delete('/addresses/' + id)
  }

  async setDefault(id: number): Promise<void> {
    await HttpClient.put('/addresses/' + id + '/default', body([]))
  }
}

export const addressRepository = new AddressRepository()
