import { AppColor, AppRadius } from '../common/StyleConstants'

@Component
export struct LoadingSkeleton {
  build() {
    Column() {
      Column().width('100%').height(360)
        .backgroundColor(AppColor.textDisabledLight()).borderRadius(AppRadius.MD)
      Column({ space: 10 }) {
        Column({ space: 6 }) {
          Column().width('70%').height(22)
            .backgroundColor(AppColor.textDisabledLight()).borderRadius(AppRadius.SM)
          Row({ space: 8 }) {
            Column().width(120).height(32)
              .backgroundColor(AppColor.textDisabledLight()).borderRadius(AppRadius.SM)
            Blank()
            Column().width(80).height(28)
              .backgroundColor(AppColor.textDisabledLight()).borderRadius(AppRadius.SM)
          }.width('100%')
        }
        Column({ space: 6 }) {
          ForEach([1, 2, 3], (i: number) => {
            Column()
              .width(i === 2 ? '90%' : i === 3 ? '60%' : '100%').height(16)
              .backgroundColor(AppColor.textDisabledLight()).borderRadius(AppRadius.SM)
          }, (i: number) => i.toString())
        }
        Row({ space: 8 }) {
          ForEach([1, 2, 3, 4], (i: number) => {
            Column().layoutWeight(1).height(36)
              .backgroundColor(AppColor.textDisabledLight()).borderRadius(AppRadius.PILL)
          }, (i: number) => i.toString())
        }.width('100%')
      }
      .padding(20).width('100%').alignItems(HorizontalAlign.Start)
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }
}
