@Component
export struct EmptyState {
  title: string = '暂无内容';
  hint: string = '';
  actionText: string = '';
  onAction: () => void = () => {};

  build() {
    Column({ space: 10 }) {
      Column()
        .width(72)
        .height(72)
        .borderRadius(36)
        .backgroundColor($r('app.color.bg_card'))
        .border({ width: 1, color: $r('app.color.divider') })
      Text(this.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      if (this.hint !== '') {
        Text(this.hint)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
      }
      if (this.actionText !== '') {
        Button(this.actionText)
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_weak'))
          .height(34)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding({ top: 40, bottom: 40, left: 24, right: 24 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
