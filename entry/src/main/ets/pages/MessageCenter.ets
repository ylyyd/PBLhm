import { messageViewModel } from '../viewmodel/MessageViewModel'
import { Message } from '../data/model/MessageModel'
import { AppRouter } from '../common/AppRouter'
import { AppColor, AppRadius } from '../common/StyleConstants'
import { EmptyView, LoadingView } from '../components/StatusViews'
import { HeaderComponent } from '../components/HeaderComponent'

@Entry
@Component
struct MessageCenter {
  @State messages: Message[] = []
  @State selectedMsg: Message | null = null
  @State showDetail: boolean = false
  @State isLoading: boolean = true

  async loadMessages(): Promise<void> {
    this.isLoading = true
    await messageViewModel.load()
    this.messages = messageViewModel.messages
    this.isLoading = false
  }

  async aboutToAppear(): Promise<void> {
    await this.loadMessages()
  }

  async onPageShow(): Promise<void> {
    await this.loadMessages()
  }

  build() {
    Stack() {
      Column() {
        HeaderComponent({
          title: '消息中心',
          rightAction: this.messages.some(m => !m.isRead) ? '全部已读' : '',
          rightActionColor: AppColor.PRIMARY,
          onRightAction: async () => {
            await messageViewModel.markAllRead()
            this.messages = messageViewModel.messages
          }
        })

        if (this.isLoading) {
          LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
        } else if (this.messages.length === 0) {
          EmptyView({ message: '暂无消息', icon: $rawfile('ic_message.svg') })
        } else {
          List({ space: 10 }) {
            ForEach(this.messages, (msg: Message) => {
              ListItem() {
                Column() {
                  Row() {
                    Stack() {
                      Circle().width(40).height(40).fill(msg.isRead ? AppColor.tabInactive() : AppColor.primaryBg())
                      Image($rawfile('ic_message.svg')).width(20).height(20)
                    }
                    Column({ space: 4 }) {
                      Row({ space: 8 }) {
                        Text(msg.title)
                          .fontSize(15).fontWeight(msg.isRead ? FontWeight.Normal : FontWeight.Bold)
                          .fontColor(AppColor.textPrimary()).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        if (!msg.isRead) {
                          Circle().width(8).height(8).fill(AppColor.CANCEL)
                        }
                      }
                      .width('100%')
                      Text(msg.content).fontSize(13).fontColor(AppColor.textTertiary())
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                    }
                    .layoutWeight(1).margin({ left: 12 })
                    Text(this.formatTime(msg.createdAt))
                      .fontSize(11).fontColor(AppColor.textDisabledLight()).margin({ left: 4 })
                  }
                  .width('100%')
                }
                .width('100%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
                .transition(TransitionEffect.opacity(0).animation({ duration: 300, curve: Curve.EaseOut }))
              }
              .onClick(async () => {
                if (!msg.isRead) {
                  await messageViewModel.markRead(msg.id)
                }
                this.selectedMsg = msg
                this.showDetail = true
              })
              .swipeAction({ end: () => { this.deleteSwipeButton(msg) } })
            }, (msg: Message) => msg.id.toString())
          }
          .width('92%').layoutWeight(1).scrollBar(BarState.Off)
        }
      }
      .width('100%').height('100%').backgroundColor(AppColor.bg())
      .alignItems(HorizontalAlign.Center)

      if (this.showDetail && this.selectedMsg) {
        Column() {
          HeaderComponent({
            title: '消息详情',
            showBack: true,
            onBack: () => { this.showDetail = false; this.loadMessages() }
          })

          Scroll() {
            Column({ space: 16 }) {
              Text(this.selectedMsg.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary())
                .width('100%')

              Text(this.formatTime(this.selectedMsg.createdAt))
                .fontSize(13).fontColor(AppColor.textTertiary()).width('100%')

              if (this.selectedMsg.orderNumber) {
                Row() {
                  Text('订单号：' + this.selectedMsg.orderNumber).fontSize(14).fontColor(AppColor.PRIMARY)
                  Blank()
                  Text('查看订单').fontSize(13).fontColor(AppColor.PRIMARY)
                }
                .width('100%').padding(12).backgroundColor(AppColor.primaryBg()).borderRadius(AppRadius.MD)
                .onClick(() => {
                  this.showDetail = false
                  AppRouter.goToOrderDetail(this.selectedMsg!.orderNumber)
                })
                .hoverEffect(HoverEffect.Scale)
              }

              Text(this.selectedMsg.content).fontSize(15).fontColor(AppColor.textSecondary())
                .width('100%').lineHeight(24)
            }
            .width('92%').padding({ top: 12 })
          }
          .layoutWeight(1).width('100%').align(Alignment.Top)
        }
        .width('100%').height('100%').backgroundColor(AppColor.bg())
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%').height('100%')
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn }).opacity(0)
    PageTransitionExit({ duration: 250, curve: Curve.FastOutLinearIn }).opacity(0)
  }

  formatTime(iso: string): string {
    if (!iso) return ''
    try {
      let d = new Date(iso)
      let now = new Date()
      let diff = now.getTime() - d.getTime()
      if (diff < 60000) return '刚刚'
      if (diff < 3600000) return Math.floor(diff / 60000) + '分钟前'
      if (diff < 86400000) return Math.floor(diff / 3600000) + '小时前'
      if (diff < 604800000) return Math.floor(diff / 86400000) + '天前'
      return d.getMonth() + 1 + '/' + d.getDate()
    } catch (e) {
      return iso
    }
  }

  @Builder
  deleteSwipeButton(msg: Message) {
    Button('删除')
      .width(70).height('100%').backgroundColor(AppColor.CANCEL).fontColor(AppColor.WHITE).fontSize(14)
      .borderRadius(0)
      .onClick(async () => {
        await messageViewModel.deleteMessage(msg.id)
        this.messages = messageViewModel.messages
      })
  }
}
