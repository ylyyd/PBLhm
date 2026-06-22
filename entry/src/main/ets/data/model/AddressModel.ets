@Observed
export class Address {
  @Track id: number = 0
  @Track label: string = ''
  @Track recipientName: string = ''
  @Track phone: string = ''
  @Track detail: string = ''
  @Track isDefault: boolean = false
}
