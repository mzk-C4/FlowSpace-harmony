@Component
export struct StatusTag {
  label: string = '';
  kind: string = 'gray';

  private bgColor(): Resource {
    switch (this.kind) {
      case 'blue':
        return $r('app.color.tag_blue_bg');
      case 'green':
        return $r('app.color.tag_green_bg');
      case 'orange':
        return $r('app.color.tag_orange_bg');
      case 'gray':
      default:
        return $r('app.color.tag_gray_bg');
    }
  }

  private textColor(): Resource {
    switch (this.kind) {
      case 'blue':
        return $r('app.color.tag_blue_text');
      case 'green':
        return $r('app.color.tag_green_text');
      case 'orange':
        return $r('app.color.tag_orange_text');
      case 'gray':
      default:
        return $r('app.color.tag_gray_text');
    }
  }

  build() {
    Text(this.label)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.textColor())
      .backgroundColor(this.bgColor())
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(10)
  }
}
