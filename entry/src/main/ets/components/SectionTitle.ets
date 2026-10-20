@Component
export struct SectionTitle {
  title: string = '';
  actionText: string = '';
  onAction: () => void = () => {};

  build() {
    Row() {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      if (this.actionText !== '') {
        Text(this.actionText)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.onAction();
          })
          .padding({ left: 4, right: 2, top: 4, bottom: 4 })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
