@Component
export struct HeartIcon {
  @Prop filled: boolean = false
  @Prop iconSize: number = 22
  onToggle?: () => void

  build() {
    Image(this.filled ? $rawfile('ic_heart_filled.svg') : $rawfile('ic_heart.svg'))
      .width(this.iconSize)
      .height(this.iconSize)
      .onClick(() => { this.onToggle?.() })
  }
}
