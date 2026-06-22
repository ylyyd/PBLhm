import { Message } from '../model/MessageModel'
import { HttpClient } from '../HttpClient'
import { Logger } from '../../common/Logger'

class MessageResponse {
  id: number = 0
  username: string = ''
  orderNumber: string = ''
  type: string = 'system'
  title: string = ''
  content: string = ''
  isRead: boolean = false
  createdAt: string = ''
}

export class MessageRepository {
  messages: Message[] = []
  unreadCount: number = 0

  async load(): Promise<void> {
    try {
      let data: Object | null = await HttpClient.getSilent('/messages')
      if (data === null) return // 401 or network error, keep stale data
      let arr: MessageResponse[] = []
      if (Array.isArray(data)) {
        arr = data as MessageResponse[]
      } else {
        let obj = data as Record<string, Object>
        arr = (obj.items ?? obj.messages) as MessageResponse[] || []
      }
      this.messages = arr.map(m => {
        let msg = new Message()
        msg.id = m.id
        msg.username = m.username
        msg.orderNumber = m.orderNumber
        msg.type = m.type
        msg.title = m.title
        msg.content = m.content
        msg.isRead = m.isRead
        msg.createdAt = m.createdAt
        return msg
      })
      this.unreadCount = this.messages.filter(m => !m.isRead).length
    } catch (err) {
      Logger.error('MessageRepository.load failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async loadUnreadCount(): Promise<void> {
    try {
      let data: Object | null = await HttpClient.getSilent('/messages/unread-count')
      if (data === null) return
      let res = data as Record<string, Object>
      this.unreadCount = Number(res.count) || 0
    } catch (err) {
      Logger.error('MessageRepository.loadUnreadCount failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async markRead(id: number): Promise<void> {
    try {
      let empty: Record<string, Object> = {}
      await HttpClient.put('/messages/' + id + '/read', empty)
      let msg = this.messages.find(m => m.id === id)
      if (msg) {
        msg.isRead = true
        this.unreadCount = Math.max(0, this.unreadCount - 1)
      }
    } catch (err) {
      Logger.error('MessageRepository.markRead failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async markAllRead(): Promise<void> {
    try {
      let empty: Record<string, Object> = {}
      await HttpClient.put('/messages/read-all', empty)
      this.messages.forEach(m => m.isRead = true)
      this.unreadCount = 0
    } catch (err) {
      Logger.error('MessageRepository.markAllRead failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  async deleteMessage(id: number): Promise<void> {
    try {
      await HttpClient.delete('/messages/' + id)
      let idx = this.messages.findIndex(m => m.id === id)
      if (idx !== -1) {
        let msg = this.messages[idx]
        this.messages.splice(idx, 1)
        if (!msg.isRead) {
          this.unreadCount = Math.max(0, this.unreadCount - 1)
        }
      }
    } catch (err) {
      Logger.error('MessageRepository.deleteMessage failed: {0}', err instanceof Error ? err.message : '')
    }
  }

  getAll(): Message[] {
    return this.messages
  }

  getUnreadCount(): number {
    return this.unreadCount
  }
}

export const messageRepository = new MessageRepository()
