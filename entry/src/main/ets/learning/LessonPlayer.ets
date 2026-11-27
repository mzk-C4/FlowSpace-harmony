import { VisualLesson, LessonStep } from './LessonScript';
import { visualLesson } from './LessonCatalog';

@ComponentV2
export struct LessonPlayer {
  @Param lesson: VisualLesson = visualLesson('ring');
  @Param reduceMotion: boolean = false;
  @Local step: number = 0;
  @Local playing: boolean = false;
  private timer: number = -1;

  aboutToDisappear(): void { this.pause(); }
  @Monitor('lesson')
  lessonChanged(): void { this.pause(); this.step = 0; }
  @Monitor('reduceMotion')
  motionChanged(): void { if (this.reduceMotion) this.pause(); }
  private frame(): LessonStep { return this.lesson.steps[Math.min(this.step, this.lesson.steps.length - 1)]; }
  private pause(): void { if (this.timer >= 0) clearTimeout(this.timer); this.timer = -1; this.playing = false; }
  private advance(delta: number): void { this.pause(); this.step = Math.max(0, Math.min(this.lesson.steps.length - 1, this.step + delta)); }
  private tick(): void {
    this.timer = setTimeout(() => {
      if (!this.playing) return;
      if (this.step >= this.lesson.steps.length - 1) { this.pause(); return; }
      this.step++;
      if (this.step >= this.lesson.steps.length - 1) this.pause(); else this.tick();
    }, 2200);
  }
  private toggle(): void {
    if (this.playing) { this.pause(); return; }
    if (this.reduceMotion) return;
    if (this.step === this.lesson.steps.length - 1) this.step = 0;
    this.playing = true; this.tick();
  }
  private indices(): number[] {
    const values: number[] = this.frame().cells.map((_value: string, index: number): number => index);
    return this.lesson.kind === 'stack' ? values.reverse() : values;
  }
  private compactArray(): boolean { return this.lesson.kind === 'array' && this.frame().cells.every((value: string) => value.length <= 3); }
  private pointerColor(index: number): ResourceColor {
    return this.frame().start === index ? $r('app.color.fs_study_start') : this.frame().end === index ? $r('app.color.fs_study_end') : $r('app.color.fs_accent');
  }
  private pointer(index: number): string {
    if (this.lesson.kind === 'stack') return this.frame().start === index ? 'top' : '';
    if (this.frame().start === index && this.frame().end === index) return 'start / end';
    return this.frame().start === index ? 'start' : this.frame().end === index ? 'end' : '';
  }
  @Builder
  cell(index: number) {
    Column({ space: 7 }) {
      if (this.lesson.kind === 'array') {
        Text(index.toString()).fontSize(11).fontFamily('monospace').fontColor($r('app.color.fs_muted'))
      }
      Text(this.frame().cells[index]).fontSize(this.lesson.kind === 'array' || this.lesson.kind === 'stack' ? 19 : 15)
        .fontWeight(this.frame().active === index ? FontWeight.Bold : FontWeight.Medium)
        .fontFamily(this.lesson.kind === 'array' || this.lesson.kind === 'stack' ? 'monospace' : 'sans-serif')
        .fontColor(this.frame().active === index ? $r('app.color.fs_accent') : $r('app.color.fs_text'))
        .textAlign(TextAlign.Center).padding(this.compactArray() ? 6 : 12)
        .constraintSize({ minWidth: this.compactArray() ? 38 : 58, minHeight: 44 })
        .width(this.lesson.kind === 'array' ? (this.compactArray() ? 38 : 110) : this.lesson.kind === 'stack' ? 80 : '100%')
        .backgroundColor(this.frame().active === index ? $r('app.color.fs_soft') : $r('app.color.fs_bg'))
        .border({ width: this.frame().active === index ? 2 : 1,
          color: this.frame().active === index ? $r('app.color.fs_accent') : $r('app.color.fs_border') }).borderRadius(10)
        .animation({ duration: this.reduceMotion ? 0 : 160, curve: Curve.EaseOut })
        .accessibilityText('元素 ' + index + '，' + this.frame().cells[index] +
          (this.frame().active === index ? '，当前高亮' : '') + '，' + this.pointer(index))
      if (this.lesson.kind === 'array' || this.lesson.kind === 'stack') {
        Text(this.pointer(index) || ' ').fontSize(10).fontFamily('monospace').fontColor(this.pointerColor(index))
      }
    }.alignItems(HorizontalAlign.Center)
      .width(this.lesson.kind === 'array' ? (this.compactArray() ? 38 : 110) : this.lesson.kind === 'stack' ? 80 : '100%')
  }
  @Builder
  diagram() {
    if (this.frame().cells.length === 0) {
      Text('空结构 · 暂无元素').fontSize(15).fontColor($r('app.color.fs_muted')).width('100%').padding(30)
    } else if (this.lesson.kind === 'array') {
      Scroll() {
        Row({ space: 6 }) { ForEach(this.indices(), (index: number) => { this.cell(index) }, (index: number) => index.toString()) }
          .padding({ top: 12, bottom: 12, left: 2, right: 2 })
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Auto)
    } else if (this.lesson.kind === 'compare') {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.indices(), (index: number) => {
          Column() { this.cell(index) }.width('48%').padding(5)
        }, (index: number) => index.toString())
      }.width('100%')
    } else {
      Column({ space: 8 }) {
        ForEach(this.indices(), (index: number) => {
          this.cell(index)
          if (this.lesson.kind === 'flow' && index < this.frame().cells.length - 1) {
            Text('↓').fontSize(20).fontColor($r('app.color.fs_muted')).accessibilityLevel('no')
          }
        }, (index: number) => index.toString())
      }.width('100%').padding({ top: 12, bottom: 12 })
    }
  }
  build() {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        Text(this.lesson.title).fontSize(21).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).layoutWeight(1)
        Text((this.step + 1) + '/' + this.lesson.steps.length).fontSize(14).fontFamily('monospace').fontColor($r('app.color.fs_muted'))
      }.width('100%')
      Progress({ value: this.step + 1, total: this.lesson.steps.length, type: ProgressType.Linear })
        .width('100%').color($r('app.color.fs_accent')).backgroundColor($r('app.color.fs_border'))
      Text(this.lesson.summary).fontSize(14).lineHeight(23).fontColor($r('app.color.fs_muted')).width('100%')
      Column({ space: 12 }) {
        Text(this.frame().title).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text')).width('100%')
        this.diagram()
        Text(this.frame().operation).fontFamily('monospace').fontSize(14).lineHeight(23)
          .fontColor($r('app.color.fs_accent')).width('100%')
        Text(this.frame().explanation).fontSize(15).lineHeight(24).fontColor($r('app.color.fs_text')).width('100%')
      }.padding(16).width('100%').borderRadius(16).border({ width: 1, color: $r('app.color.fs_border') })
      Row({ space: 8 }) {
        Button('上一步').height(44).layoutWeight(1).fontSize(13).enabled(this.step > 0)
          .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).onClick(() => this.advance(-1))
        Button(this.playing ? '暂停' : this.step === this.lesson.steps.length - 1 ? '重播' : '播放').height(44).layoutWeight(1)
          .fontSize(13).backgroundColor($r('app.color.fs_accent')).fontColor($r('app.color.fs_on_accent'))
          .enabled(!this.reduceMotion).onClick(() => this.toggle())
        Button('下一步').height(44).layoutWeight(1).fontSize(13).enabled(this.step < this.lesson.steps.length - 1)
          .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).onClick(() => this.advance(1))
      }.width('100%')
      if (this.reduceMotion) {
        Text('减少动效已开启，请用上一步 / 下一步手动阅读。').fontSize(12).fontColor($r('app.color.fs_muted')).width('100%')
      }
      Text('关键规律 / 注意事项').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text')).width('100%')
      Text(this.lesson.invariant).fontSize(14).lineHeight(23).fontColor($r('app.color.fs_muted')).width('100%')
      if (this.lesson.code.length > 0) {
        Text('逐行代码 · 与步骤对应').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text')).width('100%')
        Column({ space: 2 }) {
          ForEach(this.lesson.code, (line: string, index: number) => {
            Text((index + 1) + '  ' + line).fontFamily('monospace').fontSize(12).lineHeight(21).padding(7)
              .width('100%').wordBreak(WordBreak.BREAK_ALL).copyOption(CopyOptions.LocalDevice)
              .fontColor(this.frame().codeLine === index ? $r('app.color.fs_accent') : $r('app.color.fs_text'))
              .backgroundColor(this.frame().codeLine === index ? $r('app.color.fs_soft') : Color.Transparent)
          }, (_line: string, index: number) => index.toString())
        }.width('100%').padding(8).backgroundColor($r('app.color.fs_bg')).borderRadius(12)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
