// Shared native controls for the four phone screens.
@Builder
export function appSymbol(icon: Resource, size: number, tint: ResourceColor) {
  SymbolGlyph(icon).fontSize(size).fontColor([tint]).accessibilityLevel('no')
}

@Builder
export function brandMark() {
  Row({ space: -2 }) {
    Circle().width(22).height(22).fill(Color.Transparent).stroke($r('app.color.fs_accent')).strokeWidth(4.5)
    Circle().width(14).height(14).fill(Color.Transparent).stroke($r('app.color.fs_accent')).strokeWidth(3.5)
  }.alignItems(VerticalAlign.Bottom).accessibilityLevel('no')
}

@ComponentV2
export struct IconButton {
  @Param icon: Resource = $r('sys.symbol.plus');
  @Param label: string = '';
  @Param available: boolean = true;
  @Event onActivate: () => void = () => {};

  build() {
    Button({ type: ButtonType.Circle }) {
      appSymbol(this.icon, 20, $r('app.color.fs_accent'))
    }.width(44).height(44).padding(0).backgroundColor(Color.Transparent)
      .enabled(this.available).opacity(this.available ? 1 : 0.36)
      .accessibilityText(this.label).onClick(() => this.onActivate())
  }
}
