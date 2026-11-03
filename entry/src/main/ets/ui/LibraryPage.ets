import { LearningResource } from '../domain/MindMap';
import { OPEN_RESOURCES, RESOURCE_CATEGORIES, RESOURCE_LICENSE_URLS, findOpenResources } from '../data/ResourceCatalog';

// API 24: LazyForEach 按需创建列表行；筛选后通过 SDK 的数据变更协议刷新。
class ResourceDataSource implements IDataSource {
  private resources: LearningResource[] = OPEN_RESOURCES.slice();
  private listeners: DataChangeListener[] = [];

  totalCount(): number { return this.resources.length; }
  getData(index: number): LearningResource { return this.resources[index]; }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) { this.listeners.splice(index, 1); }
  }
  replace(resources: LearningResource[]): void {
    this.resources = resources;
    this.listeners.forEach((listener: DataChangeListener) => { listener.onDataReloaded(); });
  }
}

@ComponentV2
export struct LibraryPage {
  @Event onOpenResource: (resource: LearningResource) => void = () => {};
  @Event onUseTopic: (text: string) => void = () => {};
  @Local query: string = '';
  @Local category: string = '全部';
  @Local resultCount: number = OPEN_RESOURCES.length;
  @Local showingDetails: boolean = false;
  @Local selectedResource: LearningResource = OPEN_RESOURCES[0];
  private dataSource: ResourceDataSource = new ResourceDataSource();
  private listScroller: Scroller = new Scroller();

  private filterResources(): void {
    const resources: LearningResource[] = findOpenResources(this.query, this.category);
    this.resultCount = resources.length;
    this.dataSource.replace(resources);
    this.listScroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private openDetails(resource: LearningResource): void {
    this.getUIContext().getFocusController().clearFocus();
    this.selectedResource = resource;
    this.showingDetails = true;
  }

  private openLicense(): void {
    const resource: LearningResource = this.selectedResource;
    const evidence: LearningResource = {
      id: resource.id + '-license', title: resource.title + ' · 许可依据', category: resource.category,
      description: resource.license, url: RESOURCE_LICENSE_URLS[resource.id], source: resource.source,
      license: resource.license, language: resource.language, kind: '官方许可依据'
    };
    this.onOpenResource(evidence);
  }

  private useTopic(): void {
    const resource: LearningResource = this.selectedResource;
    this.onUseTopic('请围绕“' + resource.title + '”的学习主题，生成一份工科知识思维导图，包含前置知识、' +
      '核心概念、概念关系、练习建议和学习顺序。参考主题介绍：' + resource.description +
      '\n这里只提供主题与简短介绍，没有读取原站全文；不要声称已阅读、总结或引用原站具体章节。' +
      '请按通用知识组织，并提示用户对照官方资料核实。');
  }

  @Builder
  resourceCard(resource: LearningResource) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text(resource.category).fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.fs_accent')).padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.fs_soft')).borderRadius(6)
          Text(resource.language).fontSize(12).fontColor($r('app.color.fs_muted')).layoutWeight(1)
          Text('详情 ›').fontSize(13).fontColor($r('app.color.fs_accent'))
        }.width('100%')
        Text(resource.title).fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.fs_text')).width('100%').textAlign(TextAlign.Start)
        Text(resource.description).fontSize(14).lineHeight(21).maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('app.color.fs_muted'))
          .width('100%').textAlign(TextAlign.Start)
        Text(resource.kind).fontSize(12).fontColor($r('app.color.fs_muted'))
          .width('100%').textAlign(TextAlign.Start)
      }.alignItems(HorizontalAlign.Start).padding(18).width('100%')
    }.width('100%').height('auto').constraintSize({ minHeight: 44 })
      .backgroundColor($r('app.color.fs_surface')).borderRadius(16)
      .border({ width: 1, color: $r('app.color.fs_border') })
      .accessibilityText(resource.title + '，' + resource.kind + '，查看详情')
      .onClick(() => { this.openDetails(resource); })
  }

  @Builder
  catalogue() {
    Column({ space: 16 }) {
      Column({ space: 7 }) {
        Text('03 / LIBRARY').fontSize(12).letterSpacing(2).fontColor($r('app.color.fs_accent'))
        Text('给知识，找个起点。').fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
        Text('开放资料精选 · ' + OPEN_RESOURCES.length + ' 项工科资源')
          .fontSize(14).fontColor($r('app.color.fs_muted'))
      }.alignItems(HorizontalAlign.Start).width('100%')
      Search({ value: this.query, placeholder: '搜索主题、来源或许可' })
        .height(48).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_surface'))
        .border({ width: 1, color: $r('app.color.fs_border') }).borderRadius(12)
        .accessibilityText('搜索资料，支持标题、主题、来源和许可')
        .onChange((value: string) => { this.query = value; this.filterResources(); })
      Scroll() {
        Row({ space: 8 }) {
          ForEach(RESOURCE_CATEGORIES, (category: string) => {
            Button(category, { type: ButtonType.Normal }).height(44).padding({ left: 15, right: 15 })
              .fontSize(14).borderRadius(22)
              .backgroundColor(this.category === category ? $r('app.color.fs_accent') : $r('app.color.fs_surface'))
              .fontColor(this.category === category ? Color.White : $r('app.color.fs_text'))
              .accessibilityText(category + (this.category === category ? '，已选中' : '，筛选分类'))
              .onClick(() => { this.category = category; this.filterResources(); })
          }, (category: string) => category)
        }
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      Row() {
        Text(this.category + ' · ' + this.resultCount + ' 项').fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.fs_text')).layoutWeight(1)
        if (this.query.length > 0 || this.category !== '全部') {
          Button('重置筛选', { type: ButtonType.Normal }).height(44).fontSize(13)
            .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).borderRadius(10)
            .onClick(() => { this.query = ''; this.category = '全部'; this.filterResources(); })
        }
      }.width('100%').constraintSize({ minHeight: 44 })
      if (this.resultCount === 0) {
        Column({ space: 12 }) {
          Text('暂时没有匹配的资料').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
          Text('试试“算法”“Python”或“MIT”，也可以重置分类与搜索。')
            .fontSize(14).lineHeight(22).fontColor($r('app.color.fs_muted')).textAlign(TextAlign.Center)
        }.padding(24).width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12, scroller: this.listScroller }) {
          ListItem() {
            Text('免费阅读 ≠ 开源。详情中分别说明内容与代码许可；生成导图只使用主题。')
              .fontSize(13).lineHeight(20).fontColor($r('app.color.fs_muted')).padding({ bottom: 4 })
          }
          LazyForEach(this.dataSource, (resource: LearningResource) => {
            ListItem() { this.resourceCard(resource) }
          }, (resource: LearningResource) => resource.id)
          ListItem() {
            Text('官方来源核验于 2026-11-03 · 再利用前请核对最新条款')
              .fontSize(12).lineHeight(18).fontColor($r('app.color.fs_muted')).padding({ top: 6, bottom: 16 })
          }
        }.width('100%').layoutWeight(1).cachedCount(4).scrollBar(BarState.Auto)
      }
    }.padding({ left: 20, right: 20, top: 20 }).width('100%').height('100%')
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  detail() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Button('‹ 返回', { type: ButtonType.Normal }).height(44).fontSize(15)
          .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).borderRadius(10)
          .onClick(() => { this.showingDetails = false; })
        Text('资料详情').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
      }.width('100%')
      Scroll() {
        Column({ space: 20 }) {
          Text(this.selectedResource.category + ' / ' + this.selectedResource.language)
            .fontSize(13).fontColor($r('app.color.fs_accent')).width('100%')
          Text(this.selectedResource.title).fontSize(28).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.fs_text')).width('100%')
          Text(this.selectedResource.kind).fontSize(14).fontColor($r('app.color.fs_muted')).width('100%')
          Text(this.selectedResource.description).fontSize(16).lineHeight(26)
            .fontColor($r('app.color.fs_text')).width('100%')
          Column({ space: 10 }) {
            Text('来源与访问').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Text(this.selectedResource.source).fontSize(14).lineHeight(22).fontColor($r('app.color.fs_text'))
            Text(this.selectedResource.url).fontSize(13).lineHeight(20).wordBreak(WordBreak.BREAK_ALL)
              .fontColor($r('app.color.fs_accent')).copyOption(CopyOptions.LocalDevice)
            Button('访问官方原站 ↗', { type: ButtonType.Normal }).width('100%')
              .constraintSize({ minHeight: 48 }).fontSize(15).borderRadius(10)
              .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
              .onClick(() => { this.onOpenResource(this.selectedResource); })
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
            .backgroundColor($r('app.color.fs_surface')).borderRadius(14)
          Column({ space: 10 }) {
            Text('内容与代码许可').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Text(this.selectedResource.license).fontSize(14).lineHeight(23).fontColor($r('app.color.fs_text'))
            Text('链接可公开访问不代表可以自由再分发。NC 表示非商业，SA 表示相同方式共享。')
              .fontSize(13).lineHeight(21).fontColor($r('app.color.fs_muted'))
            Button('查看官方许可依据 ↗', { type: ButtonType.Normal }).width('100%')
              .constraintSize({ minHeight: 48 }).fontSize(15).borderRadius(10)
              .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
              .onClick(() => { this.openLicense(); })
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
            .backgroundColor($r('app.color.fs_surface')).borderRadius(14)
          Column({ space: 12 }) {
            Text('把主题变成学习路线').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Text('仅根据标题与简介生成通用知识导图。应用没有抓取或读取原站全文，生成内容请对照官方资料核实。')
              .fontSize(14).lineHeight(23).fontColor($r('app.color.fs_muted'))
            Button('基于此主题生成导图', { type: ButtonType.Normal }).width('100%')
              .constraintSize({ minHeight: 50 }).fontSize(16).fontWeight(FontWeight.Medium).borderRadius(12)
              .backgroundColor($r('app.color.fs_accent')).fontColor(Color.White)
              .onClick(() => { this.useTopic(); })
          }.width('100%').alignItems(HorizontalAlign.Start)
          Text('来源核验：2026-11-03').fontSize(12).fontColor($r('app.color.fs_muted')).width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 28 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 16 })
  }

  build() {
    Column() {
      if (this.showingDetails) { this.detail() } else { this.catalogue() }
    }.width('100%').height('100%').backgroundColor($r('app.color.fs_bg'))
  }
}
