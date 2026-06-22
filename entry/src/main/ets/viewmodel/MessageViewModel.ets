import { Message } from '../data/model/MessageModel'
import { messageRepository } from '../data/repository/MessageRepository'

export class MessageViewModel {
  get messages(): Message[] {
    return messageRepository.getAll()
  }

  get unreadCount(): number {
    return messageRepository.getUnreadCount()
  }

  async load(): Promise<void> {
    await messageRepository.load()
  }

  async loadUnreadCount(): Promise<void> {
    await messageRepository.loadUnreadCount()
  }

  async markRead(id: number): Promise<void> {
    await messageRepository.markRead(id)
  }

  async markAllRead(): Promise<void> {
    await messageRepository.markAllRead()
  }

  async deleteMessage(id: number): Promise<void> {
    await messageRepository.deleteMessage(id)
  }

  isEmpty(): boolean {
    return messageRepository.getAll().length === 0
  }
}

export const messageViewModel = new MessageViewModel()
