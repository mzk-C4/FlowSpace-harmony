import { appSymbol, IconButton } from './Controls';
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
  @Local actionsOpen: boolean = false;
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
      Row({ space: 8 }) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 12 }) {
            appSymbol($r('sys.symbol.doc_text'), 22, $r('app.color.fs_accent'))
            Column({ space: 4 }) {
              Text(this.summary.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.summary.nodeCount + ' 个节点 · ' + this.updatedLabel()).fontSize(13).fontColor($r('app.color.fs_muted'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%')
        }.layoutWeight(1).height('auto').constraintSize({ minHeight: 48 }).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText('打开导图：' + this.summary.title).onClick(() => this.onOpen(this.summary.documentId))
        IconButton({ icon: $r('sys.symbol.ellipsis_circle'), label: '管理导图：' + this.summary.title,
          onActivate: () => { this.actionsOpen = !this.actionsOpen; this.editing = false; } })
      }.width('100%')
      if (this.editing) {
        TextInput({ text: this.titleDraft, placeholder: '输入导图名称' })
          .height(48).maxLength(200).fontColor($r('app.color.fs_text'))
          .backgroundColor($r('app.color.fs_bg')).accessibilityText('新的导图名称')
          .onChange((value: string) => { this.titleDraft = value; })
        Row({ space: 8 }) {
          Button('取消', { type: ButtonType.Normal }).height(44).layoutWeight(1)
            .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).borderRadius(10)
            .onClick(() => { this.editing = false; })
          Button('保存名称', { type: ButtonType.Normal }).height(44).layoutWeight(1)
            .backgroundColor($r('app.color.fs_accent')).fontColor($r('app.color.fs_on_accent')).borderRadius(10)
            .enabled(this.titleDraft.trim().length > 0 && this.titleDraft.trim() !== this.summary.title)
            .onClick(() => {
              this.onRename(this.summary.documentId, this.titleDraft.trim());
              this.editing = false;
            })
        }.width('100%')
      } else if (this.actionsOpen) {
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
  @Local connectionOpen: boolean = false;
  @Local aboutOpen: boolean = false;
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
        this.connectionOpen = true;
        this.settingsError = '请输入 HTTP 或 HTTPS 服务地址，不含账号、查询参数或片段。';
        return;
      }
    } catch {
      this.connectionOpen = true;
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
  sectionTitle(title: string) {
    Text(title).fontSize(21).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).width('100%')
      .padding({ top: 12, bottom: 2 })
  }

  @Builder
  themeButton(label: string, mode: string) {
    Button(label, { type: ButtonType.Normal }).layoutWeight(1).height(44).borderRadius(10)
      .fontSize(14).fontWeight(this.themeDraft === mode ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.themeDraft === mode ? $r('app.color.fs_text') : $r('app.color.fs_muted'))
      .backgroundColor(this.themeDraft === mode ? $r('app.color.fs_surface') : Color.Transparent)
      .accessibilityText(label + (this.themeDraft === mode ? '，已选择' : ''))
      .onClick(() => { this.themeDraft = mode; })
  }

  @Builder
  settingsRow(title: string, icon: Resource, trailing: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        appSymbol(icon, 20, $r('app.color.fs_accent'))
        Text(title).fontSize(16).fontColor($r('app.color.fs_text')).layoutWeight(1)
        if (trailing) { Text(trailing).fontSize(14).fontColor($r('app.color.fs_muted')) }
        appSymbol($r('sys.symbol.chevron_right'), 13, $r('app.color.fs_muted'))
      }.width('100%')
    }.width('100%').height('auto').constraintSize({ minHeight: 52 }).padding({ left: 16, right: 16 })
      .backgroundColor(Color.Transparent).onClick(action)
  }

  @Builder
  connectionForm() {
    Column({ space: 10 }) {
      Text('后端地址').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
      TextInput({ text: this.backendDraft, placeholder: 'http://192.168.1.10:8787' }).height(48)
        .fontSize(16).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
        .maxLength(2048).accessibilityText('后端地址').id('profile-backend')
        .onChange((value: string) => { this.backendDraft = value; this.settingsError = ''; })
      Text('同一 Wi-Fi 下填写电脑的局域网地址。使用 USB 端口映射时可填 127.0.0.1。')
        .fontSize(13).lineHeight(20).fontColor($r('app.color.fs_muted'))
      if (this.settingsError) { Text(this.settingsError).fontSize(14).fontColor($r('app.color.fs_danger')) }
      Button('测试连接', { type: ButtonType.Normal }).height(44).width('100%').borderRadius(12)
        .backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
        .enabled(!this.settingsDirty()).onClick(() => this.onCheckConnection())
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 16 })
  }

  build() {
    List({ space: 10 }) {
      ListItem() {
        Column({ space: 12 }) {
          Text('个人').fontSize(33).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
          Search({ value: this.searchText, placeholder: '搜索本地导图' }).height(46).borderRadius(13)
            .fontColor($r('app.color.fs_text')).placeholderColor($r('app.color.fs_muted')).backgroundColor($r('app.color.fs_group'))
            .accessibilityText('搜索本地导图').maxLength(200)
            .onChange((value: string) => { this.searchText = value; this.filterDocuments(); })
          Row() {
            Text('本地导图').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).layoutWeight(1)
            Text(this.resultCount + ' 份').fontSize(14).fontColor($r('app.color.fs_muted'))
          }.width('100%').padding({ top: 8 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 24 })
      }
      if (this.resultCount === 0) {
        ListItem() {
          Text(this.documents.length === 0 ? '暂无本地导图，可在首页创建或从备份恢复。' : '没有匹配的导图，试试其他关键词。')
            .fontSize(15).lineHeight(23).fontColor($r('app.color.fs_muted')).width('100%')
            .padding(16).borderRadius(16).backgroundColor($r('app.color.fs_surface'))
        }
      }
      LazyForEach(this.source, (summary: DocumentSummary) => {
        ListItem() {
          ProfileDocumentRow({ summary: summary,
            onOpen: (id: string) => this.onOpenDocument(id),
            onRename: (id: string, title: string) => this.onRenameDocument(id, title),
            onDelete: (doc: DocumentSummary) => this.confirmDelete(doc) })
        }
      }, (summary: DocumentSummary): string => summary.documentId + ':' + summary.updatedAt + ':' + summary.title + ':' + summary.nodeCount)
      ListItem() {
        Column({ space: 10 }) {
          this.sectionTitle('备份与恢复')
          Column() {
            this.settingsRow('从 JSON 备份恢复', $r('sys.symbol.square_and_arrow_down'), '', () => this.onImport())
            Text('恢复后会创建副本。可在编辑器中导出导图。').fontSize(13).lineHeight(20)
              .fontColor($r('app.color.fs_muted')).width('100%').padding({ left: 16, right: 16, bottom: 12 })
          }.width('100%').borderRadius(16).backgroundColor($r('app.color.fs_surface'))
          this.sectionTitle('偏好设置')
          Column({ space: 10 }) {
            Text('外观').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            Row({ space: 2 }) {
              this.themeButton('跟随系统', 'system')
              this.themeButton('浅色', 'light')
              this.themeButton('深色', 'dark')
            }.width('100%').padding(3).borderRadius(13).backgroundColor($r('app.color.fs_group'))
            Divider().color($r('app.color.fs_border'))
            Row() {
              Text('减少动效').fontSize(16).fontColor($r('app.color.fs_text')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.motionDraft }).height(44).width(54)
                .selectedColor($r('app.color.fs_accent')).accessibilityText('减少动效')
                .onChange((value: boolean) => { this.motionDraft = value; })
            }.width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).borderRadius(16).backgroundColor($r('app.color.fs_surface'))
          Column() {
            this.settingsRow('AI 服务', $r('sys.symbol.connection'), this.connectionOpen ? '收起' : '连接设置',
              () => { this.connectionOpen = !this.connectionOpen; })
            if (this.connectionOpen) { this.connectionForm() }
            Divider().color($r('app.color.fs_border')).margin({ left: 48 })
            this.settingsRow('关于 FlowSpace', $r('sys.symbol.book'), this.aboutOpen ? '收起' : '2.0.1', () => { this.aboutOpen = !this.aboutOpen; })
            if (this.aboutOpen) {
              Text('导图、原文和对话保存在本机。使用 AI 时，输入和相关导图会发往你配置的后端和模型。卸载前可导出 JSON 备份。')
                .fontSize(14).lineHeight(22).fontColor($r('app.color.fs_muted'))
                .padding({ left: 16, right: 16, bottom: 16 }).width('100%')
            }
          }.width('100%').borderRadius(16).clip(true).backgroundColor($r('app.color.fs_surface'))
          if (this.settingsDirty()) {
            Button('保存更改', { type: ButtonType.Normal }).height(48).width('100%').borderRadius(14)
              .fontColor($r('app.color.fs_on_accent')).backgroundColor($r('app.color.fs_accent')).onClick(() => this.saveSettings())
          }
          if (this.connectionMessage) {
            Text(this.connectionMessage).fontSize(14).lineHeight(22).fontColor($r('app.color.fs_text')).width('100%')
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
      }
    }.width('100%').height('100%').padding({ left: 20, right: 20 })
      .cachedCount(6).scrollBar(BarState.Auto).backgroundColor($r('app.color.fs_bg'))
  }
}
