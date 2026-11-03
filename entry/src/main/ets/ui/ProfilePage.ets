import { url } from '@kit.ArkTS';
import { AppSettings, DocumentSummary, defaultSettings } from '../domain/MindMap';

// API 24. The parent owns persistence; this page emits commands only.
class ProfileDocumentSource implements IDataSource {
  private items: DocumentSummary[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number { return this.items.length; }
  getData(index: number): DocumentSummary { return this.items[index]; }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) { this.listeners.splice(index, 1); }
  }
  replace(items: DocumentSummary[]): void {
    this.items = items;
    this.listeners.forEach((listener: DataChangeListener) => { listener.onDataReloaded(); });
  }
}

@ComponentV2
struct ProfileDocumentRow {
  @Param summary: DocumentSummary = { documentId: '', title: '', nodeCount: 0, updatedAt: '' };
  @Event onOpen: (id: string) => void = () => {};
  @Event onRename: (id: string, title: string) => void = () => {};
  @Event onDelete: (summary: DocumentSummary) => void = () => {};
  @Local editing: boolean = false;
  @Local titleDraft: string = '';

  private updatedLabel(): string {
    const date: Date = new Date(this.summary.updatedAt);
    if (Number.isNaN(date.getTime())) { return '更新时间未知'; }
    return date.getFullYear().toString() + '/' + (date.getMonth() + 1).toString() + '/' +
      date.getDate().toString() + ' 更新';
  }

  build() {
    Column({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        Column({ space: 6 }) {
          Text(this.summary.title).fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.fs_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.summary.nodeCount.toString() + ' 个节点 · ' + this.updatedLabel())
            .fontSize(12).fontColor($r('app.color.fs_muted'))
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').constraintSize({ minHeight: 60 }).padding(0)
        .backgroundColor(Color.Transparent).borderRadius(8)
        .accessibilityText('打开导图：' + this.summary.title)
        .onClick(() => { this.onOpen(this.summary.documentId); })
      if (this.editing) {
        TextInput({ text: this.titleDraft, placeholder: '输入导图名称' })
          .height(48).maxLength(100).fontColor($r('app.color.fs_text'))
          .backgroundColor($r('app.color.fs_bg')).accessibilityText('新的导图名称')
          .onChange((value: string) => { this.titleDraft = value; })
        Row({ space: 8 }) {
          Button('取消', { type: ButtonType.Normal }).height(44).layoutWeight(1)
            .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).borderRadius(10)
            .onClick(() => { this.editing = false; })
          Button('保存名称', { type: ButtonType.Normal }).height(44).layoutWeight(1)
            .backgroundColor($r('app.color.fs_accent')).fontColor(Color.White).borderRadius(10)
            .enabled(this.titleDraft.trim().length > 0 && this.titleDraft.trim() !== this.summary.title)
            .onClick(() => {
              this.onRename(this.summary.documentId, this.titleDraft.trim());
              this.editing = false;
            })
        }.width('100%')
      } else {
        Row({ space: 8 }) {
          Button('重命名', { type: ButtonType.Normal }).height(44).layoutWeight(1)
            .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).borderRadius(10)
            .accessibilityText('重命名：' + this.summary.title)
            .onClick(() => { this.titleDraft = this.summary.title; this.editing = true; })
          Button('删除', { type: ButtonType.Normal }).height(44).layoutWeight(1)
            .backgroundColor($r('app.color.fs_bg')).fontColor($r('app.color.fs_danger')).borderRadius(10)
            .accessibilityText('删除：' + this.summary.title)
            .onClick(() => { this.onDelete(this.summary); })
        }.width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .backgroundColor($r('app.color.fs_surface')).borderRadius(16)
      .border({ width: 1, color: $r('app.color.fs_border') })
  }
}

@ComponentV2
export struct ProfilePage {
  @Param settings: AppSettings = defaultSettings();
  @Param documents: DocumentSummary[] = [];
  @Param connectionMessage: string = '';
  @Event onSaveSettings: (settings: AppSettings) => void = () => {};
  @Event onCheckConnection: () => void = () => {};
  @Event onOpenDocument: (id: string) => void = () => {};
  @Event onRenameDocument: (id: string, title: string) => void = () => {};
  @Event onDeleteDocument: (id: string) => void = () => {};
  @Event onImport: () => void = () => {};
  @Local searchText: string = '';
  @Local resultCount: number = 0;
  @Local backendDraft: string = '';
  @Local themeDraft: string = 'system';
  @Local motionDraft: boolean = false;
  @Local settingsError: string = '';
  private source: ProfileDocumentSource = new ProfileDocumentSource();

  aboutToAppear(): void {
    this.syncSettings();
    this.filterDocuments();
  }

  @Monitor('settings')
  settingsChanged(): void { this.syncSettings(); }

  @Monitor('documents')
  documentsChanged(): void { this.filterDocuments(); }

  private syncSettings(): void {
    this.backendDraft = this.settings.backendUrl;
    this.themeDraft = this.settings.themeMode;
    this.motionDraft = this.settings.reduceMotion;
    this.settingsError = '';
  }

  private filterDocuments(): void {
    const query: string = this.searchText.trim().toLowerCase();
    const items: DocumentSummary[] = this.documents.filter((doc: DocumentSummary) => {
      return doc.title.toLowerCase().includes(query);
    });
    this.resultCount = items.length;
    this.source.replace(items);
  }

  private settingsDirty(): boolean {
    return this.backendDraft !== this.settings.backendUrl || this.themeDraft !== this.settings.themeMode ||
      this.motionDraft !== this.settings.reduceMotion;
  }

  private saveSettings(): void {
    const value: string = this.backendDraft.trim().replace(/\/+$/, '');
    try {
      const address: url.URL = new url.URL(value);
      if ((address.protocol !== 'http:' && address.protocol !== 'https:') || address.hostname.length === 0 ||
        address.username.length > 0 || address.password.length > 0 || address.search.length > 0 ||
        address.hash.length > 0 || /\s/.test(value)) {
        this.settingsError = '请输入 HTTP 或 HTTPS 服务地址，不含账号、查询参数或片段。';
        return;
      }
    } catch {
      this.settingsError = '服务地址格式不正确，例如 http://192.168.1.10:8787';
      return;
    }
    this.settingsError = '';
    const next: AppSettings = { backendUrl: value, themeMode: this.themeDraft, reduceMotion: this.motionDraft };
    this.onSaveSettings(next);
  }

  private confirmDelete(summary: DocumentSummary): void {
    this.getUIContext().showAlertDialog({
      title: '删除这份导图？',
      message: '“' + summary.title + '”将从本机删除。此操作不可撤销，建议先在编辑页导出 JSON 备份。',
      autoCancel: true,
      primaryButton: { value: '保留', defaultFocus: true, action: () => {} },
      secondaryButton: {
        value: '删除', fontColor: $r('app.color.fs_danger'),
        action: () => { this.onDeleteDocument(summary.documentId); }
      }
    });
  }

  @Builder
  sectionTitle(title: string, description: string) {
    Column({ space: 5 }) {
      Text(title).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
      Text(description).fontSize(13).fontColor($r('app.color.fs_muted')).lineHeight(20)
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 4 })
  }

  @Builder
  themeButton(label: string, mode: string) {
    Button(label, { type: ButtonType.Normal }).layoutWeight(1).height(46).borderRadius(10)
      .fontSize(14).fontColor(this.themeDraft === mode ? Color.White : $r('app.color.fs_text'))
      .backgroundColor(this.themeDraft === mode ? $r('app.color.fs_accent') : $r('app.color.fs_bg'))
      .accessibilityText(label + (this.themeDraft === mode ? '，已选择' : ''))
      .onClick(() => { this.themeDraft = mode; })
  }

  build() {
    List({ space: 12 }) {
      ListItem() {
        Column({ space: 12 }) {
          Text('04 / 我的空间').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_accent'))
          Text('想法留在这里').fontSize(30).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
          Text('本地文档 · 偏好设置').fontSize(14).fontColor($r('app.color.fs_muted'))
          Row({ space: 12 }) {
            Text('F').fontSize(25).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_accent'))
              .width(52).height(52).textAlign(TextAlign.Center).backgroundColor($r('app.color.fs_soft')).borderRadius(16)
            Column({ space: 4 }) {
              Text('我的 FlowSpace').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
              Text('无需登录，随时整理你的思路').fontSize(12).fontColor($r('app.color.fs_muted'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%').padding(16).backgroundColor($r('app.color.fs_surface')).borderRadius(16)
          this.sectionTitle('本地文档', '搜索已保存的导图，继续上次的思考。')
          TextInput({ text: this.searchText, placeholder: '搜索导图名称' }).height(48)
            .fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_surface'))
            .accessibilityText('搜索本地导图').maxLength(100)
            .onChange((value: string) => { this.searchText = value; this.filterDocuments(); })
          Text(this.searchText.trim().length > 0 ? '找到 ' + this.resultCount.toString() + ' 份导图' :
            '共 ' + this.documents.length.toString() + ' 份已保存导图')
            .fontSize(12).fontColor($r('app.color.fs_muted'))
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12 })
      }
      if (this.resultCount === 0) {
        ListItem() {
          Column({ space: 8 }) {
            Text(this.documents.length === 0 ? '还没有保存的导图' : '没有匹配的导图')
              .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Text(this.documents.length === 0 ? '在 DIY 页面创建并保存，或从下方恢复 JSON 备份。' : '换一个关键词试试。')
              .fontSize(13).fontColor($r('app.color.fs_muted')).lineHeight(20)
          }.width('100%').padding(24).backgroundColor($r('app.color.fs_surface')).borderRadius(16)
        }
      }
      LazyForEach(this.source, (summary: DocumentSummary) => {
        ListItem() {
          ProfileDocumentRow({ summary: summary,
            onOpen: (id: string) => { this.onOpenDocument(id); },
            onRename: (id: string, title: string) => { this.onRenameDocument(id, title); },
            onDelete: (doc: DocumentSummary) => { this.confirmDelete(doc); } })
        }
      }, (summary: DocumentSummary): string => summary.documentId + ':' + summary.updatedAt + ':' +
        summary.title + ':' + summary.nodeCount.toString())
      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('备份与恢复', '让重要的思路多一份备份。')
          Column({ space: 12 }) {
            Text('从 JSON 恢复').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Text('选择 FlowSpace 导出的 JSON 文件。恢复后会创建一份新导图；原有文档会保留。')
              .fontSize(13).fontColor($r('app.color.fs_muted')).lineHeight(21)
            Button('选择 JSON 备份', { type: ButtonType.Normal }).height(48).width('100%').borderRadius(10)
              .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
              .onClick(() => { this.onImport(); })
            Text('导出入口位于 DIY 编辑页，支持 JSON、Markdown 和 PNG。')
              .fontSize(12).fontColor($r('app.color.fs_muted')).lineHeight(20)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor($r('app.color.fs_surface')).borderRadius(16)
          this.sectionTitle('使用偏好', '按你的习惯安排这个空间。')
          Column({ space: 14 }) {
            Text('外观').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Row({ space: 8 }) {
              this.themeButton('跟随系统', 'system')
              this.themeButton('浅色', 'light')
              this.themeButton('深色', 'dark')
            }.width('100%')
            Row({ space: 12 }) {
              Column({ space: 5 }) {
                Text('减少动效').fontSize(16).fontColor($r('app.color.fs_text'))
                Text('减少画布与页面的移动效果').fontSize(12).fontColor($r('app.color.fs_muted'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.motionDraft }).height(48).width(56)
                .selectedColor($r('app.color.fs_accent')).accessibilityText('减少动效')
                .onChange((value: boolean) => { this.motionDraft = value; })
            }.width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor($r('app.color.fs_surface')).borderRadius(16)
          this.sectionTitle('AI 服务', '配置你自己的 FlowSpace 后端。')
          Column({ space: 12 }) {
            Text('后端服务地址').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            TextInput({ text: this.backendDraft, placeholder: 'http://192.168.1.10:8787' }).height(48)
              .fontSize(14).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
              .maxLength(2048).accessibilityText('后端服务地址')
              .onChange((value: string) => { this.backendDraft = value; this.settingsError = ''; })
            Text('手机请填写可访问的电脑局域网地址。127.0.0.1 指向手机本身；API 密钥由后端管理。')
              .fontSize(12).fontColor($r('app.color.fs_muted')).lineHeight(20)
            if (this.settingsError.length > 0) {
              Text(this.settingsError).fontSize(13).fontColor($r('app.color.fs_danger')).lineHeight(20)
            }
            Button('保存偏好与地址', { type: ButtonType.Normal }).height(48).width('100%').borderRadius(10)
              .backgroundColor($r('app.color.fs_accent')).fontColor(Color.White).enabled(this.settingsDirty())
              .onClick(() => { this.saveSettings(); })
            if (this.settingsDirty()) {
              Text('有未保存的设置，保存后可测试连接。').fontSize(12).fontColor($r('app.color.fs_muted'))
            }
            Button('测试已保存地址的连接', { type: ButtonType.Normal }).height(48).width('100%').borderRadius(10)
              .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
              .enabled(!this.settingsDirty()).onClick(() => { this.onCheckConnection(); })
            if (this.connectionMessage.length > 0) {
              Text('最近一次连接检测').fontSize(12).fontColor($r('app.color.fs_muted'))
              Text(this.connectionMessage).fontSize(13).fontColor($r('app.color.fs_text')).lineHeight(21)
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor($r('app.color.fs_surface')).borderRadius(16)
          this.sectionTitle('关于 FlowSpace', '把复杂知识，整理成清晰的思路。')
          Column({ space: 12 }) {
            Text('为工科学习而做的思维导图工具').fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.fs_text'))
            Text('支持自然语言生成、对话修改、手动编辑与文件导出。学习资源会打开来源页面，许可与使用条件以来源说明为准。')
              .fontSize(13).fontColor($r('app.color.fs_muted')).lineHeight(22)
            Text('你的本地数据').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Text('导图、原文、对话记录和偏好保存在本机，不提供账号或云同步。卸载或清除应用数据可能丢失文档，请定期导出 JSON。')
              .fontSize(13).fontColor($r('app.color.fs_muted')).lineHeight(22)
            Text('使用 AI 时，输入内容和相关导图会发送至你配置的后端及其模型服务。请只提交你愿意交由该服务处理的内容。')
              .fontSize(13).fontColor($r('app.color.fs_muted')).lineHeight(22)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor($r('app.color.fs_surface')).borderRadius(16)
          Text('FlowSpace 2.0.0 · AI 思维导图').fontSize(12).fontColor($r('app.color.fs_muted'))
            .width('100%').textAlign(TextAlign.Center).padding({ top: 12, bottom: 28 })
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
    }.width('100%').height('100%').padding({ left: 20, right: 20 })
      .cachedCount(6).scrollBar(BarState.Auto).backgroundColor($r('app.color.fs_bg'))
  }
}
