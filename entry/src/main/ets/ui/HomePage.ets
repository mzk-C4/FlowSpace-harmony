import { appSymbol, brandMark } from './Controls';
import { DocumentSummary, LearningResource } from '../domain/MindMap';
import { VIDEO_RESOURCES } from '../data/VideoCatalog';

interface HomeExample {
  title: string;
  instruction: string;
}

const HOME_EXAMPLES: HomeExample[] = [
  { title: '期末复习', instruction: '帮我整理信号与系统期末复习思维导图，分为信号分类、线性时不变系统、卷积、傅里叶变换、拉普拉斯变换和采样。每部分列出核心概念、关键公式与常见易错点。' },
  { title: '算法梳理', instruction: '为算法与数据结构建立思维导图，包含数组与链表、树与图、排序、搜索、贪心和动态规划。对每类给出适用场景、时间复杂度与一个典型例题。' },
  { title: '项目拆解', instruction: '把智能温控系统课程设计拆解成思维导图，包含需求分析、温度传感器、信号采集、PID控制、执行器、软件模块、测试与答辩材料。' }
];

class HomeVideoSource implements IDataSource {
  private items: LearningResource[] = VIDEO_RESOURCES.slice();
  private listeners: DataChangeListener[] = [];

  totalCount(): number { return this.items.length; }
  getData(index: number): LearningResource { return this.items[index]; }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) { this.listeners.splice(index, 1); }
  }
  filter(category: string): void {
    this.items = category === '全部' ? VIDEO_RESOURCES.slice() :
      VIDEO_RESOURCES.filter((item: LearningResource) => item.category === category);
    this.listeners.forEach((listener: DataChangeListener) => listener.onDataReloaded());
  }
}

// API 24. All application actions are delegated to the shared shell.
@ComponentV2
export struct HomePage {
  @Param documents: DocumentSummary[] = [];
  @Param busy: boolean = false;
  @Event onGenerate: (text: string) => void = (_text: string): void => {};
  @Event onOpenDocument: (id: string) => void = (_id: string): void => {};
  @Event onNewMap: () => void = (): void => {};
  @Event onOpenResource: (resource: LearningResource) => void = (_resource: LearningResource): void => {};
  @Event onOpenExample: () => void = () => {};
  @Local draft: string = '';
  @Local longText: boolean = false;
  @Local category: string = '全部';
  @Local expandedVideoId: string = '';
  private videoSource: HomeVideoSource = new HomeVideoSource();
  private pageScroller: Scroller = new Scroller();
  private categories: string[] = ['全部', '数学基础', '算法', '电路', '信号', '控制'];

  private recentDocuments(): DocumentSummary[] {
    return this.documents.slice().sort((left: DocumentSummary, right: DocumentSummary) =>
      right.updatedAt.localeCompare(left.updatedAt)).slice(0, 3);
  }

  private dateLabel(value: string): string {
    const date: Date = new Date(value);
    if (Number.isNaN(date.getTime())) { return '最近更新'; }
    return (date.getMonth() + 1).toString() + '月' + date.getDate().toString() + '日更新';
  }

  private generate(): void {
    const text: string = this.draft.trim();
    if (this.busy || text.length === 0 || text.length > 20000) { return; }
    this.getUIContext().getFocusController().clearFocus();
    this.onGenerate(text);
  }

  @Builder
  private header() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        brandMark()
        Text('FlowSpace').fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
        Blank()
        Button({ type: ButtonType.Normal }) {
          Row({ space: 5 }) {
            appSymbol($r('sys.symbol.square_and_pencil'), 16, $r('app.color.fs_accent'))
            Text('手动创建').fontSize(14).fontColor($r('app.color.fs_accent'))
          }
        }.height(44).padding({ left: 8, right: 2 }).backgroundColor(Color.Transparent)
          .enabled(!this.busy).onClick(() => this.onNewMap()).id('home-new')
      }.width('100%')
      Text('新建思维导图').fontSize(33).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 12 })
  }

  @Builder
  private inputMode(label: string, longText: boolean) {
    Button(label, { type: ButtonType.Normal }).height(44).layoutWeight(1).borderRadius(10)
      .fontSize(15).fontWeight(this.longText === longText ? FontWeight.Medium : FontWeight.Regular)
      .backgroundColor(this.longText === longText ? $r('app.color.fs_surface') : Color.Transparent)
      .fontColor(this.longText === longText ? $r('app.color.fs_text') : $r('app.color.fs_muted'))
      .accessibilityText(label + (this.longText === longText ? '，已选中' : ''))
      .enabled(!this.busy).onClick(() => { this.longText = longText; })
  }

  @Builder
  private composer() {
    Column({ space: 12 }) {
      Row({ space: 3 }) {
        this.inputMode('主题', false)
        this.inputMode('长文', true)
      }.width('100%').padding(3).borderRadius(13).backgroundColor($r('app.color.fs_group'))
      TextArea({ text: this.draft, placeholder: this.longText ? '粘贴课堂笔记、文章或会议记录…' : '想整理什么？例如，信号与系统的复习提纲。' })
        .width('100%').height(this.longText ? 170 : 98).padding({ top: 12, left: 6, right: 6, bottom: 6 })
        .fontSize(17).fontColor($r('app.color.fs_text')).placeholderColor($r('app.color.fs_muted'))
        .backgroundColor($r('app.color.fs_surface')).enabled(!this.busy)
        .accessibilityText('输入主题或长文，最多两万字').id('home-input')
        .onChange((value: string) => { this.draft = value; })
      if (this.draft.length > 0) {
        Row() {
          Text(this.draft.length + ' / 20,000').fontSize(13)
            .fontColor(this.draft.length > 20000 ? $r('app.color.fs_danger') : $r('app.color.fs_muted'))
          Blank()
          Button('清空', { type: ButtonType.Normal }).height(44).fontSize(14).backgroundColor(Color.Transparent)
            .fontColor($r('app.color.fs_muted')).enabled(!this.busy).onClick(() => { this.draft = ''; })
        }.width('100%')
      }
      if (this.draft.length > 20000) {
        Text('请将输入缩短至20,000字以内。').fontSize(14).fontColor($r('app.color.fs_danger')).width('100%')
      }
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          appSymbol($r('sys.symbol.wand_and_stars'), 18, $r('app.color.fs_on_accent'))
          Text(this.busy ? '生成中…' : '生成导图').fontColor($r('app.color.fs_on_accent')).fontSize(17).fontWeight(FontWeight.Medium)
        }
      }.width('100%').constraintSize({ minHeight: 50 }).borderRadius(14).padding(12)
        .backgroundColor($r('app.color.fs_accent')).accessibilityText('生成思维导图').id('home-generate')
        .enabled(!this.busy && this.draft.trim().length > 0 && this.draft.length <= 20000).onClick(() => this.generate())
    }.width('100%').padding(16).borderRadius(20).backgroundColor($r('app.color.fs_surface'))
  }

  @Builder
  private examples() {
    Column({ space: 6 }) {
      Text('示例主题').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_muted'))
      Row({ space: 8 }) {
        ForEach(HOME_EXAMPLES, (example: HomeExample) => {
          Button(example.title, { type: ButtonType.Normal }).layoutWeight(1).constraintSize({ minHeight: 44 })
            .fontSize(14).borderRadius(13).fontColor($r('app.color.fs_accent')).backgroundColor($r('app.color.fs_soft'))
            .enabled(!this.busy).onClick(() => { this.draft = example.instruction; this.longText = false; })
        }, (example: HomeExample) => example.title)
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private recent() {
    Column({ space: 8 }) {
      Row() {
        Text('最近导图').fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).layoutWeight(1)
        Button('打开示例', { type: ButtonType.Normal }).height(44).padding({ left: 12, right: 2 })
          .fontSize(15).fontColor($r('app.color.fs_accent')).backgroundColor(Color.Transparent)
          .enabled(!this.busy).accessibilityText('打开可编辑的本地示例导图').id('home-example').onClick(() => this.onOpenExample())
      }.width('100%')
      Column() {
        if (this.documents.length === 0) {
          Text('暂无最近导图。打开示例即可试用编辑、撤销和导出。')
            .fontSize(15).lineHeight(23).fontColor($r('app.color.fs_muted')).width('100%').padding(16)
        } else {
          ForEach(this.recentDocuments(), (doc: DocumentSummary, index: number) => {
            if (index > 0) { Divider().color($r('app.color.fs_border')).margin({ left: 64 }) }
            Button({ type: ButtonType.Normal }) {
              Row({ space: 12 }) {
                Stack() { appSymbol($r('sys.symbol.rectangle_3_group'), 20, $r('app.color.fs_accent')) }
                  .width(38).height(38).borderRadius(11).backgroundColor($r('app.color.fs_soft'))
                Column({ space: 4 }) {
                  Text(doc.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(doc.nodeCount + ' 个节点 · ' + this.dateLabel(doc.updatedAt)).fontSize(13).fontColor($r('app.color.fs_muted'))
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                appSymbol($r('sys.symbol.chevron_right'), 14, $r('app.color.fs_muted'))
              }.width('100%')
            }.width('100%').height('auto').padding(14).backgroundColor(Color.Transparent)
              .enabled(!this.busy).onClick(() => this.onOpenDocument(doc.documentId))
          }, (doc: DocumentSummary) => doc.documentId + ':' + doc.updatedAt)
        }
      }.width('100%').borderRadius(16).clip(true).backgroundColor($r('app.color.fs_surface'))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private videoHeader() {
    Column({ space: 8 }) {
      Row() {
        Text('工科视频').fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).layoutWeight(1)
        Text(VIDEO_RESOURCES.length + ' 门课程').fontSize(14).fontColor($r('app.color.fs_muted'))
      }.width('100%')
      Scroll() {
        Row({ space: 6 }) {
          ForEach(this.categories, (item: string) => {
            Button(item, { type: ButtonType.Normal }).height(44).padding({ left: 13, right: 13 }).borderRadius(12).fontSize(14)
              .fontColor(this.category === item ? $r('app.color.fs_on_accent') : $r('app.color.fs_text'))
              .backgroundColor(this.category === item ? $r('app.color.fs_accent') : $r('app.color.fs_surface'))
              .onClick(() => { this.category = item; this.expandedVideoId = ''; this.videoSource.filter(item); })
          }, (item: string) => item)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  private videoCard(resource: LearningResource) {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          appSymbol($r('sys.symbol.play_circle'), 26, $r('app.color.fs_accent'))
          Column({ space: 5 }) {
            Text(resource.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text')).width('100%')
            Text(resource.category + ' · ' + resource.language + ' · ' + resource.source)
              .fontSize(13).fontColor($r('app.color.fs_muted')).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          appSymbol(this.expandedVideoId === resource.id ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'), 14, $r('app.color.fs_muted'))
        }.width('100%')
      }.width('100%').height('auto').constraintSize({ minHeight: 48 }).padding(0).backgroundColor(Color.Transparent)
        .accessibilityText(resource.title + '，课程详情')
        .onClick(() => { this.expandedVideoId = this.expandedVideoId === resource.id ? '' : resource.id; })
      if (this.expandedVideoId === resource.id) {
        Divider().color($r('app.color.fs_border'))
        Text(resource.description).fontSize(15).lineHeight(23).fontColor($r('app.color.fs_text')).width('100%')
        Text(resource.license).fontSize(13).lineHeight(20).fontColor($r('app.color.fs_muted')).width('100%')
        Button('前往课程原站', { type: ButtonType.Normal }).height(44).width('100%').borderRadius(12)
          .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
          .onClick(() => this.onOpenResource(resource))
      }
    }.padding(16).width('100%').alignItems(HorizontalAlign.Start).borderRadius(16).backgroundColor($r('app.color.fs_surface'))
  }

  build() {
    List({ space: 16, scroller: this.pageScroller }) {
      ListItem() { this.header() }
      ListItem() { this.composer() }
      ListItem() { this.examples() }
      ListItem() { this.recent() }
      ListItem() { this.videoHeader() }
      LazyForEach(this.videoSource, (resource: LearningResource) => {
        ListItem() { this.videoCard(resource) }
      }, (resource: LearningResource) => resource.id)
    }.width('100%').height('100%').padding({ left: 20, right: 20, bottom: 12 })
      .cachedCount(3).scrollBar(BarState.Off).backgroundColor($r('app.color.fs_bg'))
  }
}
