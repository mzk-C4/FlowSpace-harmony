import { promptAction } from '@kit.ArkUI';
import { appSymbol } from './Controls';
import { LearningResource } from '../domain/MindMap';
import { OPEN_RESOURCES, RESOURCE_CATEGORIES, RESOURCE_LICENSE_URLS, RESOURCE_VERIFICATION, findOpenResources, resourceTopic } from '../data/ResourceCatalog';

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
  @Param externalOpenError: string = '';
  @Param failedResourceId: string = '';
  @Event onOpenLesson: (id: string) => void = () => {};
  @Event onUseTopic: (text: string) => void = () => {};
  @Local query: string = '';
  @Local category: string = '全部';
  @Local resultCount: number = OPEN_RESOURCES.length;
  @Local showingDetails: boolean = false;
  @Local selectedResource: LearningResource = OPEN_RESOURCES[0];
  @Local pendingTopic: string = '';
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
    this.pendingTopic = '';
    this.showingDetails = true;
  }

  private openLicense(code: boolean = false): void {
    const resource: LearningResource = this.selectedResource;
    const evidence: LearningResource = {
      id: resource.id + '-license', title: resource.title + ' · 许可依据', category: resource.category,
      description: resource.license, url: code ? RESOURCE_VERIFICATION[resource.id].codeLicenseUrl : RESOURCE_LICENSE_URLS[resource.id], source: resource.source,
      license: resource.license, language: resource.language, kind: '官方许可依据'
    };
    this.onOpenResource(evidence);
  }

  private async chooseLicense(): Promise<void> {
    if (RESOURCE_VERIFICATION[this.selectedResource.id].codeLicenseUrl.length === 0) {
      this.openLicense();
      return;
    }
    try {
      const result: promptAction.ActionMenuSuccessResponse = await this.getUIContext().getPromptAction().showActionMenu({
        title: '内容与代码分别授权，请选择许可依据',
        buttons: [{ text: '教材 / 内容许可', color: $r('app.color.fs_accent') },
          { text: '配套代码许可', color: $r('app.color.fs_accent') }]
      });
      if (result.index === 0 || result.index === 1) this.openLicense(result.index === 1);
    } catch (_) { /* 系统取消菜单不打开链接，也不改变当前详情。 */ }
  }

  private useTopic(): void {
    if (this.pendingTopic.length > 0) return;
    const resource: LearningResource = this.selectedResource;
    this.pendingTopic = resourceTopic(resource);
    this.showingDetails = false;
  }

  private detailClosed(): void {
    this.showingDetails = false;
    const topic: string = this.pendingTopic;
    this.pendingTopic = '';
    if (topic.length > 0) this.onUseTopic(topic);
  }

  @Builder
  resourceRow(resource: LearningResource) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Row() { appSymbol($r('sys.symbol.book'), 23, $r('app.color.fs_muted')) }
          .width(28).height(44).justifyContent(FlexAlign.Center)
        Column({ space: 5 }) {
          Text(resource.title).fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.fs_text')).width('100%').textAlign(TextAlign.Start)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(resource.description).fontSize(13).lineHeight(20).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('app.color.fs_muted'))
            .width('100%').textAlign(TextAlign.Start)
          Text(resource.category + ' · ' + resource.language).fontSize(11)
            .fontColor($r('app.color.fs_muted')).width('100%').textAlign(TextAlign.Start)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        appSymbol($r('sys.symbol.chevron_right'), 13, $r('app.color.fs_muted'))
      }.width('100%').padding({ left: 15, right: 15, top: 16, bottom: 16 })
        .alignItems(VerticalAlign.Center)
    }.width('100%').height('auto').constraintSize({ minHeight: 44 }).padding(0)
      .backgroundColor($r('app.color.fs_surface')).borderRadius(0)
      .accessibilityText(resource.title + '，' + resource.kind + '，查看详情')
      .onClick(() => { this.openDetails(resource); })
  }

  @Builder
  catalogue() {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Text('资料库').fontSize(34).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
        Text('工科开放资料与开源项目').fontSize(14).fontColor($r('app.color.fs_muted'))
      }.alignItems(HorizontalAlign.Start).width('100%').padding({ bottom: 7 })
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          appSymbol($r('sys.symbol.play_circle'), 22, $r('app.color.fs_accent'))
          Column({ space: 3 }) {
            Text('知识动态讲解').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Text('节点可附链接与代码，由 AI 编排分步可视化').fontSize(11).fontColor($r('app.color.fs_muted'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          appSymbol($r('sys.symbol.chevron_right'), 12, $r('app.color.fs_muted'))
        }.width('100%').padding(12)
      }.width('100%').height('auto').constraintSize({ minHeight: 58 }).padding(0).borderRadius(13)
        .backgroundColor($r('app.color.fs_soft')).onClick(() => this.onOpenLesson('ring'))
      Search({ value: this.query, placeholder: '搜索主题、来源或许可' })
        .height(48).textFont({ size: 16 }).placeholderFont({ size: 16 }).fontColor($r('app.color.fs_text'))
        .backgroundColor($r('app.color.fs_surface')).borderRadius(13)
        .accessibilityText('搜索资料，支持标题、主题、来源和许可')
        .onChange((value: string) => { this.query = value; this.filterResources(); })
      Row({ space: 4 }) {
      Scroll() {
        Row({ space: 3 }) {
          ForEach(RESOURCE_CATEGORIES, (category: string) => {
            Button(category, { type: ButtonType.Normal }).height(44).padding({ left: 14, right: 14 })
              .fontSize(13).fontWeight(this.category === category ? FontWeight.Medium : FontWeight.Normal)
              .borderRadius(10)
              .backgroundColor(this.category === category ? $r('app.color.fs_surface') : Color.Transparent)
              .fontColor(this.category === category ? $r('app.color.fs_text') : $r('app.color.fs_muted'))
              .accessibilityText(category + (this.category === category ? '，已选中' : '，筛选分类'))
              .onClick(() => { this.category = category; this.filterResources(); })
          }, (category: string) => category)
        }.padding(4)
      }.layoutWeight(1).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      appSymbol($r('sys.symbol.chevron_right'), 12, $r('app.color.fs_muted'))
      }.width('100%').padding({ right: 8 }).backgroundColor($r('app.color.fs_group')).borderRadius(14)
        .accessibilityDescription('学科与资料分类，可左右滑动查看全部选项')
      Row() {
        Text(this.resultCount + ' 项资料').fontSize(13).fontColor($r('app.color.fs_muted')).layoutWeight(1)
        if (this.query.length > 0 || this.category !== '全部') {
          Button('重置', { type: ButtonType.Normal }).height(44).fontSize(13).padding({ left: 12, right: 0 })
            .backgroundColor(Color.Transparent).fontColor($r('app.color.fs_accent'))
            .onClick(() => { this.query = ''; this.category = '全部'; this.filterResources(); })
        }
      }.width('100%').height(44)
      if (this.resultCount === 0) {
        Column({ space: 12 }) {
          appSymbol($r('sys.symbol.book'), 30, $r('app.color.fs_muted'))
          Text('没有匹配的资料').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
          Text('试试其他关键词，或重置筛选。').fontSize(14)
            .fontColor($r('app.color.fs_muted')).textAlign(TextAlign.Center)
        }.padding(24).width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0, scroller: this.listScroller }) {
          LazyForEach(this.dataSource, (resource: LearningResource) => {
            ListItem() { this.resourceRow(resource) }
          }, (resource: LearningResource) => resource.id)
        }.width('100%').layoutWeight(1).cachedCount(4).scrollBar(BarState.Auto)
          .backgroundColor($r('app.color.fs_surface')).borderRadius(18).clip(true)
          .divider({ strokeWidth: 0.5, color: $r('app.color.fs_border'), startMargin: 55, endMargin: 15 })
      }
      Text('公开阅读不等于开源。详情中可查看来源与许可。')
        .fontSize(11).lineHeight(17).fontColor($r('app.color.fs_muted')).width('100%')
        .padding({ top: 2, bottom: 14 })
    }.padding({ left: 20, right: 20, top: 16 }).width('100%').height('100%')
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  detail() {
    Column({ space: 12 }) {
      Row() {
        Text('资料详情').fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.fs_text')).layoutWeight(1)
        Button('完成', { type: ButtonType.Normal }).height(44).constraintSize({ minWidth: 44 })
          .fontSize(15).fontColor($r('app.color.fs_accent')).backgroundColor(Color.Transparent)
          .onClick(() => { this.showingDetails = false; })
      }.width('100%')
      Scroll() {
        Column({ space: 18 }) {
          Column({ space: 8 }) {
            Text(this.selectedResource.category + ' · ' + this.selectedResource.language)
              .fontSize(12).fontColor($r('app.color.fs_muted')).width('100%')
            Text(this.selectedResource.title).fontSize(25).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.fs_text')).width('100%')
            Text(this.selectedResource.kind + ' · 核验 ' + RESOURCE_VERIFICATION[this.selectedResource.id].verifiedAt).fontSize(13).fontColor($r('app.color.fs_muted')).width('100%')
            Text(this.selectedResource.description).fontSize(15).lineHeight(24)
              .fontColor($r('app.color.fs_text')).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 10 }) {
            Text('来源').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Text(this.selectedResource.source).fontSize(14).lineHeight(22).fontColor($r('app.color.fs_text'))
            Text(this.selectedResource.url).fontSize(12).lineHeight(19).wordBreak(WordBreak.BREAK_ALL)
              .fontColor($r('app.color.fs_accent')).copyOption(CopyOptions.LocalDevice)
            Button('打开原站', { type: ButtonType.Normal }).width('100%').height(46).fontSize(14)
              .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).borderRadius(11)
              .onClick(() => { this.onOpenResource(this.selectedResource); })
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor($r('app.color.fs_surface')).borderRadius(16)
          Column({ space: 10 }) {
            Text('内容与代码许可').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Text(this.selectedResource.license).fontSize(14).lineHeight(23)
              .fontColor($r('app.color.fs_text')).copyOption(CopyOptions.LocalDevice).width('100%')
            Text('以原站条款为准；非商业、署名与共享要求分别适用。')
              .fontSize(12).lineHeight(19).fontColor($r('app.color.fs_muted'))
            Button('查看许可依据', { type: ButtonType.Normal }).width('100%').height(46).fontSize(14)
              .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).borderRadius(11)
              .onClick(() => { this.chooseLicense(); })
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor($r('app.color.fs_surface')).borderRadius(16)
          if (this.externalOpenError.length > 0 &&
            (this.failedResourceId === this.selectedResource.id || this.failedResourceId === this.selectedResource.id + '-license')) {
            Column({ space: 8 }) {
              Text(this.externalOpenError).fontSize(13).lineHeight(21).fontColor($r('app.color.fs_danger'))
              Text('请检查系统浏览器与网络，再点击上方入口重试。也可长按来源链接复制到浏览器。')
                .fontSize(12).lineHeight(19).fontColor($r('app.color.fs_muted'))
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 3, bottom: 16 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
      Button('用作导图主题', { type: ButtonType.Normal }).width('100%').height(50)
        .fontSize(16).fontWeight(FontWeight.Medium).borderRadius(13)
        .backgroundColor($r('app.color.fs_accent')).fontColor($r('app.color.fs_on_accent'))
        .enabled(this.pendingTopic.length === 0).onClick(() => { this.useTopic(); })
      Text('仅使用标题与简介，不会读取原站全文。').fontSize(11)
        .fontColor($r('app.color.fs_muted')).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 12, bottom: 20 })
      .backgroundColor($r('app.color.fs_bg'))
  }

  build() {
    Column() { this.catalogue() }
      .width('100%').height('100%').backgroundColor($r('app.color.fs_bg'))
      .bindSheet(this.showingDetails, this.detail(), {
        height: SheetSize.LARGE, showClose: false, backgroundColor: $r('app.color.fs_bg'),
        onDisappear: () => { this.detailClosed(); }
      })
  }
}
