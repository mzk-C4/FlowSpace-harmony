// PillTag.ets
// FlowSpace · 语义小标签（用于模块内的强调色标签，如 后进先出 / 先进先出 / 示例练习 等）
@Component
export struct PillTag {
  text: string = '';
  bg: string = '#EDEFF2';
  fg: string = '#5C6670';

  build() {
    Text(this.text)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.fg)
      .backgroundColor(this.bg)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(10)
  }
}
