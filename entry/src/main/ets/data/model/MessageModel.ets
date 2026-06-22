@Observed
export class Message {
  @Track id: number = 0
  @Track username: string = ''
  @Track orderNumber: string = ''
  @Track type: string = 'system'
  @Track title: string = ''
  @Track content: string = ''
  @Track isRead: boolean = false
  @Track createdAt: string = ''
}
