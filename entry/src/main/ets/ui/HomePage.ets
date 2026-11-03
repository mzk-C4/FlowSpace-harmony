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
    Column({ space: 18 }) {
      Row({ space: 10 }) {
        Text('F').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_accent'))
          .width(40).height(40).textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.fs_soft')).borderRadius(13)
        Text('FlowSpace').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
        Blank()
        Text('学习 · 有迹可循').fontSize(11).fontColor($r('app.color.fs_muted'))
      }.width('100%')
      Column({ space: 8 }) {
        Text('让想法，\n慢慢清晰起来。').fontSize(32).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.fs_text')).lineHeight(43).width('100%')
        Text('从一句话、一段笔记，开始你的知识地图。').fontSize(14)
          .fontColor($r('app.color.fs_muted')).lineHeight(22).width('100%')
      }.alignItems(HorizontalAlign.Start).width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 12, bottom: 8 })
  }

  @Builder
  private composer() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button('描述想法', { type: ButtonType.Normal })
          .fontSize(14).fontColor(this.longText ? $r('app.color.fs_muted') : $r('app.color.fs_accent'))
          .backgroundColor(this.longText ? $r('app.color.fs_surface') : $r('app.color.fs_soft'))
          .height(44).borderRadius(12).layoutWeight(1)
          .enabled(!this.busy).onClick(() => { this.longText = false; })
        Button('粘贴长文', { type: ButtonType.Normal })
          .fontSize(14).fontColor(this.longText ? $r('app.color.fs_accent') : $r('app.color.fs_muted'))
          .backgroundColor(this.longText ? $r('app.color.fs_soft') : $r('app.color.fs_surface'))
          .height(44).borderRadius(12).layoutWeight(1)
          .enabled(!this.busy).onClick(() => { this.longText = true; })
      }.width('100%')
      TextArea({ text: this.draft, placeholder: this.longText ?
        '粘贴课堂笔记、课程摘要或文章，AI 将帮你提炼层级与要点…' :
        '例如：整理电路分析的知识框架，包含基本定律、分析方法与典型电路…' })
        .fontSize(16).fontColor($r('app.color.fs_text')).placeholderColor($r('app.color.fs_muted'))
        .backgroundColor($r('app.color.fs_bg')).borderRadius(14)
        .height(this.longText ? 220 : 156).width('100%').padding(14)
        .enabled(!this.busy)
        .onChange((value: string) => { this.draft = value; })
        .accessibilityText('输入思维导图主题或长文，最多两万字')
      Row() {
        Text(this.draft.length.toString() + ' / 20,000 字').fontSize(12)
          .fontColor($r('app.color.fs_muted'))
        Blank()
        Button('清空', { type: ButtonType.Normal }).height(44).fontSize(13)
          .fontColor($r('app.color.fs_muted')).backgroundColor($r('app.color.fs_surface'))
          .enabled(!this.busy && this.draft.length > 0).onClick(() => { this.draft = ''; })
      }.width('100%')
      if (this.draft.length > 20000) {
        Text('输入超过20,000字，请缩短后再生成；原文已保留。').fontSize(13).fontColor($r('app.color.fs_danger'))
      }
      Button(this.busy ? '正在整理思路…' : '生成思维导图  ↗', { type: ButtonType.Normal })
        .width('100%').constraintSize({ minHeight: 50 }).padding(14).borderRadius(14)
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.White)
        .backgroundColor($r('app.color.fs_accent'))
        .enabled(!this.busy && this.draft.trim().length > 0 && this.draft.length <= 20000)
        .onClick(() => { this.generate(); })
      Text('AI 将提取结构与要点，生成后仍可对话修改或手动编辑。')
        .fontSize(12).fontColor($r('app.color.fs_muted')).lineHeight(18).width('100%')
    }.width('100%').padding(16).borderRadius(22).backgroundColor($r('app.color.fs_surface'))
    .border({ width: 1, color: $r('app.color.fs_border') })
  }

  @Builder
  private examples() {
    Column({ space: 10 }) {
      Text('试试这些灵感').fontSize(13).fontColor($r('app.color.fs_muted'))
      Row({ space: 8 }) {
        ForEach(HOME_EXAMPLES, (example: HomeExample) => {
          Button(example.title, { type: ButtonType.Normal }).layoutWeight(1)
            .constraintSize({ minHeight: 44 }).fontSize(13).borderRadius(12)
            .fontColor($r('app.color.fs_accent')).backgroundColor($r('app.color.fs_soft'))
            .enabled(!this.busy).onClick(() => { this.draft = example.instruction; this.longText = false; })
        }, (example: HomeExample) => example.title)
      }.width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  private recent() {
    Column({ space: 10 }) {
      Row() {
        Text('继续上次的思考').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
        Blank()
        Button('＋ 新建', { type: ButtonType.Normal }).height(44).fontSize(13).borderRadius(12)
          .fontColor($r('app.color.fs_accent')).backgroundColor($r('app.color.fs_soft'))
          .enabled(!this.busy).onClick(() => { this.onNewMap(); })
      }.width('100%')
      if (this.documents.length === 0) {
        Column({ space: 6 }) {
          Text('第一张知识地图，从这里开始').fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.fs_text')).width('100%')
          Text('生成一张导图，或点“新建”亲手搭建。保存后会出现在这里。')
            .fontSize(13).lineHeight(20).fontColor($r('app.color.fs_muted')).width('100%')
        }.padding(16).width('100%').backgroundColor($r('app.color.fs_surface')).borderRadius(16)
      } else {
        ForEach(this.recentDocuments(), (doc: DocumentSummary) => {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 12 }) {
              Text('◇').fontSize(25).fontColor($r('app.color.fs_accent'))
                .width(42).height(42).textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.fs_soft')).borderRadius(12)
              Column({ space: 5 }) {
                Text(doc.title).fontSize(15).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.fs_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text(doc.nodeCount.toString() + ' 个节点 · ' + this.dateLabel(doc.updatedAt))
                  .fontSize(12).fontColor($r('app.color.fs_muted')).width('100%')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text('›').fontSize(24).fontColor($r('app.color.fs_muted'))
            }.width('100%')
          }.width('100%').padding(14).borderRadius(16).backgroundColor($r('app.color.fs_surface'))
          .enabled(!this.busy).onClick(() => { this.onOpenDocument(doc.documentId); })
        }, (doc: DocumentSummary) => doc.documentId + ':' + doc.updatedAt)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private videoHeader() {
    Column({ space: 10 }) {
      Row() {
        Text('给知识一点新连接').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
        Blank()
        Text('8 门视频课程').fontSize(12).fontColor($r('app.color.fs_muted'))
      }.width('100%')
      Text('工科学习精选 · 官方课程入口').fontSize(13).fontColor($r('app.color.fs_muted'))
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.categories, (item: string) => {
            Button(item, { type: ButtonType.Normal }).height(44).fontSize(13).borderRadius(12)
              .fontColor(this.category === item ? Color.White : $r('app.color.fs_muted'))
              .backgroundColor(this.category === item ? $r('app.color.fs_accent') : $r('app.color.fs_surface'))
              .onClick(() => { this.category = item; this.expandedVideoId = ''; this.videoSource.filter(item); })
          }, (item: string) => item)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  private videoCard(resource: LearningResource) {
    Column({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        Column({ space: 8 }) {
          Row() {
            Text('▷  ' + resource.category).fontSize(12).fontColor($r('app.color.fs_accent'))
            Blank()
            Text(resource.language + ' · 视频课程').fontSize(11).fontColor($r('app.color.fs_muted'))
          }.width('100%')
          Text(resource.title).fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.fs_text')).width('100%')
          Text(resource.description).fontSize(13).lineHeight(21).fontColor($r('app.color.fs_muted'))
            .width('100%')
          Row() {
            Text(resource.source).fontSize(11).fontColor($r('app.color.fs_muted')).layoutWeight(1)
            Text(this.expandedVideoId === resource.id ? '收起 ∧' : '详情 ∨')
              .fontSize(12).fontColor($r('app.color.fs_accent'))
          }.width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').padding(0).backgroundColor($r('app.color.fs_surface'))
      .onClick(() => { this.expandedVideoId = this.expandedVideoId === resource.id ? '' : resource.id; })
      if (this.expandedVideoId === resource.id) {
        Divider().color($r('app.color.fs_border'))
        Text(resource.license).fontSize(12).lineHeight(20).fontColor($r('app.color.fs_muted')).width('100%')
        Text('公开视频不等于开源；请遵守原站许可与第三方材料声明。')
          .fontSize(12).lineHeight(20).fontColor($r('app.color.fs_muted')).width('100%')
        Button('前往官方课程  ↗', { type: ButtonType.Normal }).width('100%')
          .constraintSize({ minHeight: 44 }).padding(10).fontSize(14).borderRadius(12)
          .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
          .onClick(() => { this.onOpenResource(resource); })
      }
    }.padding(16).width('100%').borderRadius(18).backgroundColor($r('app.color.fs_surface'))
    .border({ width: 1, color: $r('app.color.fs_border') })
  }

  build() {
    List({ space: 18, scroller: this.pageScroller }) {
      ListItem() { this.header() }
      ListItem() { this.composer() }
      ListItem() { this.examples() }
      ListItem() { this.recent() }
      ListItem() { this.videoHeader() }
      LazyForEach(this.videoSource, (resource: LearningResource) => {
        ListItem() { this.videoCard(resource) }
      }, (resource: LearningResource) => resource.id)
      ListItem() {
        Text('把零散的知识，连接成自己的理解。').fontSize(12)
          .fontColor($r('app.color.fs_muted')).width('100%').textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 24 })
      }
    }.width('100%').height('100%').padding({ left: 20, right: 20 })
    .cachedCount(3).scrollBar(BarState.Off).backgroundColor($r('app.color.fs_bg'))
  }
}
