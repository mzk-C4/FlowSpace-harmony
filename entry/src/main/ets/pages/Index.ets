import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { MindMapDocument, DocumentSummary, AppSettings, GenerationRequest, GenerationCandidate, ChatMessage,
  HealthStatus, EditorAction, LearningResource, createDocument, defaultSettings, cloneDocument, newId } from '../domain/MindMap';
import { DocumentSession, validateDocument } from '../domain/DocumentSession';
import { buildGenerationRequest } from '../domain/GenerationRequestBuilder';
import { documentRepository } from '../storage/DocumentRepository';
import { exportService } from '../storage/ExportService';
import { generationClient } from '../services/GenerationClient';
import { HomePage } from '../ui/HomePage';
import { DIYPage } from '../ui/DIYPage';
import { LibraryPage } from '../ui/LibraryPage';
import { ProfilePage } from '../ui/ProfilePage';

@Entry
@ComponentV2
struct Index {
  @Local currentTab: number = 0;
  @Local document: MindMapDocument = createDocument();
  @Local documents: DocumentSummary[] = [];
  @Local settings: AppSettings = defaultSettings();
  @Local selectedNodeId: string = '';
  @Local candidate: GenerationCandidate | null = null;
  @Local busy: boolean = false;
  @Local creating: boolean = false;
  @Local homeDraft: string = '';
  @Local homeError: string = '';
  @Local revisionScope: string = '';
  @Local progress: string = '';
  @Local saveStatus: string = '尚未保存';
  @Local message: string = '';
  @Local connectionMessage: string = '';
  @Local resourceOpenError: string = '';
  @Local failedResourceId: string = '';
  @Local ready: boolean = false;
  @Local loading: boolean = true;
  @Local canUndo: boolean = false;
  @Local canRedo: boolean = false;
  @Local generatedFit: number = 0;
  @Local changingDocument: boolean = false;
  private session: DocumentSession = new DocumentSession(this.document);
  private pathStack: NavPathStack = new NavPathStack();
  private saveToken: number = 0;
  private creationRequest: GenerationRequest | null = null;
  private createdDocumentId: string = '';
  private cancelRequested: boolean = false;

  aboutToAppear(): void { this.initialize(); }
  aboutToDisappear(): void { this.cancelGeneration(); }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async initialize(): Promise<void> {
    this.loading = true;
    try {
      await documentRepository.initialize(this.context());
      this.settings = await documentRepository.loadSettings();
      this.applyTheme();
      this.documents = await documentRepository.list();
      if (this.documents.length > 0) {
        const recent: MindMapDocument | null = await documentRepository.get(this.documents[0].documentId);
        if (recent !== null) { this.useDocument(recent); this.saveStatus = '已保存'; }
      }
      this.ready = true;
      this.message = '';
    } catch (error) { this.message = '本地存储初始化失败：' + (error as Error).message; }
    finally { this.loading = false; }
  }

  private applyTheme(): void {
    let mode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (this.settings.themeMode === 'light') mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    if (this.settings.themeMode === 'dark') mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    try { this.context().getApplicationContext().setColorMode(mode); } catch (_) {}
  }

  private useDocument(doc: MindMapDocument): void {
    this.session = new DocumentSession(doc);
    this.document = cloneDocument(this.session.document);
    this.selectedNodeId = '';
    this.candidate = null;
    this.canUndo = false;
    this.canRedo = false;
  }

  private sync(): void {
    this.document = cloneDocument(this.session.document);
    this.canUndo = this.session.canUndo();
    this.canRedo = this.session.canRedo();
    if (this.selectedNodeId && !this.document.nodes.some((node) => node.id === this.selectedNodeId)) this.selectedNodeId = '';
  }

  private async persist(): Promise<boolean> {
    if (!this.ready) return false;
    const token: number = ++this.saveToken;
    const snapshot: MindMapDocument = cloneDocument(this.session.document);
    this.saveStatus = '正在保存…';
    try {
      await documentRepository.save(snapshot);
      this.documents = await documentRepository.list();
      if (token === this.saveToken && snapshot.documentId === this.document.documentId) this.saveStatus = '已保存';
      return true;
    } catch (error) {
      if (token === this.saveToken) {
        this.saveStatus = '未保存，点击上方重试';
        this.message = '保存失败，当前编辑仍保留：' + (error as Error).message;
      }
      return false;
    }
  }

  private async flushCurrent(): Promise<boolean> {
    if (this.saveStatus === '尚未保存' || this.saveStatus === '已保存') return true;
    return await this.persist();
  }

  private showPendingCandidate(): boolean {
    if (this.candidate === null) return false;
    this.currentTab = 1;
    this.message = '请先应用或放弃正在预览的修改。';
    return true;
  }

  private async openDocument(id: string): Promise<void> {
    if (this.showPendingCandidate()) return;
    if (this.busy || this.changingDocument) { this.message = '请等待保存完成或取消生成，再切换导图'; return; }
    this.changingDocument = true;
    try {
      if (!await this.flushCurrent()) return;
      const doc: MindMapDocument | null = await documentRepository.get(id);
      if (doc === null) throw new Error('导图已被删除，请刷新列表');
      this.useDocument(doc); this.saveStatus = '已保存'; this.message = ''; this.currentTab = 1;
    } catch (error) { this.message = (error as Error).message; }
    finally { this.changingDocument = false; }
  }

  private async newMap(): Promise<void> {
    if (this.showPendingCandidate()) return;
    if (!this.ready || this.busy || this.changingDocument) { this.message = '请等待初始化、保存完成或取消当前生成'; return; }
    this.changingDocument = true;
    try {
      if (!await this.flushCurrent()) return;
      this.useDocument(createDocument()); this.currentTab = 1; this.message = ''; await this.persist();
    } finally { this.changingDocument = false; }
  }

  private action(action: EditorAction): boolean {
    if (!this.ready || this.changingDocument) return false;
    if (this.candidate !== null) { this.message = '请先应用或放弃当前候选'; return false; }
    try {
      if (action.kind === 'addChild') this.selectedNodeId = this.session.addNode(action.nodeId, action.text);
      else if (action.kind === 'addSibling') this.selectedNodeId = this.session.addSibling(action.nodeId, action.text);
      else if (action.kind === 'edit') this.session.editNode(action.nodeId, action.text, action.note);
      else if (action.kind === 'remove') this.session.removeNode(action.nodeId);
      else if (action.kind === 'move') this.session.moveNode(action.nodeId, action.parentId);
      else if (action.kind === 'toggle') this.session.toggleCollapsed(action.nodeId);
      else if (action.kind === 'undo') this.session.undo();
      else if (action.kind === 'redo') this.session.redo();
      else if (action.kind === 'layout') this.session.setLayout(action.text);
      else if (action.kind === 'rename') this.session.rename(action.text);
      else throw new Error('不支持的编辑操作');
      this.message = ''; this.sync(); this.persist();
      return true;
    } catch (error) { this.message = (error as Error).message; return false; }
  }

  private chatMessage(role: string, content: string): ChatMessage {
    return { id: newId('message'), role: role, content: content.slice(0, 20000), createdAt: new Date().toISOString() };
  }

  private appendMessage(role: string, content: string): void {
    this.session.document.messages.push(this.chatMessage(role, content));
    if (this.session.document.messages.length > 1000) this.session.document.messages.shift();
    this.sync();
  }

  private cancelGeneration(): void {
    if (!this.busy || this.changingDocument) return;
    this.cancelRequested = true;
    generationClient.cancel();
  }

  private async requestCandidate(request: GenerationRequest): Promise<GenerationCandidate> {
    if (this.cancelRequested) throw new Error('已取消生成，输入和已有导图已保留');
    this.progress = '正在连接模型服务…';
    const result: GenerationCandidate = await generationClient.generate(this.settings.backendUrl, request,
      (value: string) => { this.progress = value; });
    if (this.cancelRequested) throw new Error('已取消生成，输入和已有导图已保留');
    validateDocument(result.document);
    if (result.requestId !== request.requestId || result.baseRevision !== request.baseRevision ||
      result.document.revision !== request.baseRevision || result.document.rootId !== request.document.rootId ||
      result.document.documentId !== request.documentId) throw new Error('服务返回了不匹配的候选，原图已保留');
    return result;
  }

  private async createFromText(text: string): Promise<void> {
    this.homeError = '';
    if (this.creationRequest?.instruction === text && this.createdDocumentId &&
      this.documents.some((entry) => entry.documentId === this.createdDocumentId)) {
      await this.openDocument(this.createdDocumentId);
      if (this.document.documentId === this.createdDocumentId) this.homeDraft = '';
      return;
    }
    if (this.creationRequest === null || this.creationRequest.instruction !== text || this.createdDocumentId) {
      const draft: MindMapDocument = createDocument(text.split('\n')[0].slice(0, 40));
      draft.sourceText = text;
      this.creationRequest = buildGenerationRequest(draft, text, true, '');
      this.createdDocumentId = '';
    }
    const request: GenerationRequest = this.creationRequest;
    this.busy = true; this.creating = true; this.cancelRequested = false; this.progress = '正在准备生成…';
    try {
      if (!await this.flushCurrent()) throw new Error('请先保存当前导图，再重试生成。');
      const result: GenerationCandidate = await this.requestCandidate(request);
      this.changingDocument = true;
      this.progress = '正在保存导图…';
      if (!await this.flushCurrent()) throw new Error('请先保存当前导图，再重试生成。');
      const next: MindMapDocument = cloneDocument(result.document);
      next.revision = request.baseRevision + 1;
      next.updatedAt = new Date().toISOString();
      next.messages = [this.chatMessage('user', text), this.chatMessage('assistant', result.summary)];
      await documentRepository.save(next);
      this.useDocument(next); this.saveStatus = '已保存'; this.generatedFit++;
      this.createdDocumentId = next.documentId;
      this.homeDraft = ''; this.message = ''; this.currentTab = 1;
      this.documents = await documentRepository.list();
    } catch (error) {
      if (this.createdDocumentId) this.message = '导图已保存，文库暂时无法刷新。';
      else this.homeError = (error as Error).message;
    } finally {
      this.creating = false; this.changingDocument = false; this.busy = false; this.progress = '';
    }
  }

  private async generate(instruction: string, create: boolean = false): Promise<void> {
    const text: string = instruction.trim();
    if (!this.ready || this.busy || this.changingDocument || this.showPendingCandidate()) return;
    if (create) {
      this.homeDraft = instruction;
      if (!text || instruction.length > 20000) { this.homeError = '请输入 1 至 20,000 个字符'; return; }
      await this.createFromText(text);
      return;
    }
    if (!text || instruction.length > 20000) { this.message = '请输入 1 至 20,000 个字符'; return; }
    const history: ChatMessage[] = this.session.document.messages;
    const lastMessage: ChatMessage | undefined = history[history.length - 1];
    if (lastMessage?.role !== 'user' || lastMessage.content !== text) {
      this.appendMessage('user', text);
      this.persist();
    }
    const request: GenerationRequest = buildGenerationRequest(this.session.document, text, false, this.selectedNodeId);
    const branch = request.document.nodes.find((node) => node.id === request.scopeNodeId);
    this.revisionScope = request.scopeNodeId === request.document.rootId ? '整张导图' : '选中分支 · ' + (branch?.text ?? '');
    this.busy = true; this.cancelRequested = false; this.message = '';
    try {
      const result: GenerationCandidate = await this.requestCandidate(request);
      this.candidate = result;
      if (this.session.document.revision !== result.baseRevision) this.message = '导图已修改，这份候选已过期。请放弃后重新生成。';
    } catch (error) { this.message = (error as Error).message; }
    finally { this.busy = false; this.progress = ''; }
  }

  private applyCandidate(): void {
    if (this.candidate === null || this.changingDocument) return;
    try {
      const summary: string = this.candidate.summary;
      this.session.applyCandidate(this.candidate);
      this.candidate = null;
      this.appendMessage('assistant', summary || '已应用导图修改。');
      this.message = ''; this.sync(); this.persist();
    } catch (error) { this.message = (error as Error).message; }
  }

  private discardCandidate(): void {
    if (this.changingDocument) return;
    this.candidate = null; this.message = ''; this.progress = '';
    this.appendMessage('assistant', '已放弃候选，导图未改变。'); this.persist();
  }

  private async renameDocument(id: string, title: string): Promise<void> {
    if (this.changingDocument) return;
    this.changingDocument = true;
    try {
      if (!await this.flushCurrent()) return;
      if (id === this.document.documentId) {
        this.session.rename(title); this.sync(); await this.persist();
      } else {
        const doc: MindMapDocument | null = await documentRepository.get(id);
        if (doc === null) throw new Error('导图不存在');
        const session: DocumentSession = new DocumentSession(doc);
        session.rename(title); await documentRepository.save(session.document);
        this.documents = await documentRepository.list();
      }
    } catch (error) { this.message = (error as Error).message; }
    finally { this.changingDocument = false; }
  }

  private async deleteDocument(id: string): Promise<void> {
    if (this.changingDocument) return;
    if (id === this.document.documentId && this.showPendingCandidate()) return;
    if (this.busy && id === this.document.documentId) { this.message = '请先取消生成'; return; }
    this.changingDocument = true;
    try {
      if (!await this.flushCurrent()) return;
      await documentRepository.delete(id);
      if (id === this.document.documentId) { this.useDocument(createDocument()); this.saveStatus = '尚未保存'; }
      this.documents = await documentRepository.list();
    } catch (error) { this.message = (error as Error).message; }
    finally { this.changingDocument = false; }
  }

  private async saveSettings(settings: AppSettings): Promise<void> {
    try { await documentRepository.saveSettings(settings); this.settings = settings; this.applyTheme(); this.connectionMessage = '设置已保存'; }
    catch (error) { this.connectionMessage = '设置保存失败：' + (error as Error).message; }
  }

  private async checkConnection(): Promise<void> {
    this.connectionMessage = '正在检测…';
    try {
      const status: HealthStatus = await generationClient.health(this.settings.backendUrl);
      this.connectionMessage = status.configured ? '网关可达 · ' + status.model + ' 已配置，实际调用将在生成时验证' : '服务可达，但尚未配置模型';
    } catch (error) { this.connectionMessage = '连接失败：' + (error as Error).message; }
  }

  private async importDocument(example: boolean = false): Promise<void> {
    if (this.showPendingCandidate()) return;
    if (this.busy || this.changingDocument) { this.message = '请等待保存完成或取消当前生成'; return; }
    this.changingDocument = true;
    try {
      if (!await this.flushCurrent()) return;
      const existing: MindMapDocument | null = example ? await documentRepository.get(exportService.exampleId) : null;
      const doc: MindMapDocument = existing || (example ? exportService.loadExample() : await exportService.importDocument(this.context()));
      if (existing === null) { await documentRepository.save(doc); }
      this.useDocument(doc); this.saveStatus = '已保存';
      this.documents = await documentRepository.list(); this.currentTab = 1; this.message = '';
    } catch (error) { this.message = (error as Error).message; }
    finally { this.changingDocument = false; }
  }

  private async exportDocument(format: string): Promise<void> {
    try { await exportService.exportDocument(this.context(), this.session.document, format); }
    catch (error) { this.message = (error as Error).message; }
  }

  private async openResource(resource: LearningResource): Promise<void> {
    if (this.message === this.resourceOpenError) this.message = '';
    this.resourceOpenError = '';
    this.failedResourceId = '';
    try {
      if (!resource.url.startsWith('https://')) throw new Error('资源地址无效');
      await this.context().startAbility({ action: 'ohos.want.action.viewData', uri: resource.url });
    } catch (error) {
      this.failedResourceId = resource.id;
      this.resourceOpenError = '无法打开原站：' + (error as Error).message;
      this.message = this.resourceOpenError;
    }
  }

  @Builder
  tabLabel(label: string, glyph: Resource, index: number) {
    Column({ space: 3 }) {
      SymbolGlyph(glyph).fontSize(22)
        .fontColor([this.currentTab === index ? $r('app.color.fs_accent') : $r('app.color.fs_muted')])
        .accessibilityLevel('no')
      Text(label).fontSize(12).fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTab === index ? $r('app.color.fs_accent') : $r('app.color.fs_muted'))
    }.height('100%').width('100%').justifyContent(FlexAlign.Center)
      .accessibilityText(label + (this.currentTab === index ? '，当前页面' : ''))
      .id('tab-' + index)
  }

  build() {
    Navigation(this.pathStack) {
      Column() {
        if (this.loading) { LoadingProgress().width(36).height(36) }
        if (this.message && this.currentTab !== 1) {
          Row({ space: 8 }) {
            Text(this.message).fontSize(12).fontColor($r('app.color.fs_danger')).layoutWeight(1)
            Button(this.ready ? '关闭' : '重试').height(44).onClick(() => {
              if (!this.ready) this.initialize(); else this.message = '';
            })
          }.padding(12).backgroundColor($r('app.color.fs_soft'))
        }
        if (this.saveStatus.startsWith('未保存')) {
          Button('重试保存当前导图').height(44).onClick(() => { this.persist(); })
        }
        if (this.ready) {
          Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
            TabContent() {
              HomePage({ documents: this.documents, busy: this.busy || this.changingDocument,
                draft: this.homeDraft, onDraftChange: (text: string) => { this.homeDraft = text; this.homeError = ''; },
                generating: this.creating, generationProgress: this.progress, generationError: this.homeError,
                canCancel: !this.changingDocument, onCancel: () => { this.cancelGeneration(); },
                onConnectionSettings: () => { this.currentTab = 3; },
                onDismissGenerationFeedback: () => { this.homeError = ''; },
                onOpenExample: () => { this.importDocument(true); },
                onGenerate: (text: string) => { this.generate(text, true); },
                onOpenDocument: (id: string) => { this.openDocument(id); }, onNewMap: () => { this.newMap(); },
                onOpenResource: (resource: LearningResource) => { this.openResource(resource); } })
            }.tabBar(this.tabLabel('首页', $r('sys.symbol.house'), 0))
            TabContent() {
              DIYPage({ document: this.candidate !== null && this.candidate.baseRevision === this.document.revision ?
                this.candidate.document : this.document,
                selectedNodeId: this.selectedNodeId, canUndo: this.canUndo, canRedo: this.canRedo,
                busy: this.busy, progress: this.progress, saveStatus: this.saveStatus,
                candidateSummary: this.candidate !== null ? (this.candidate.summary || '预览生成结果，确认后应用') : '',
                canApply: this.candidate !== null && this.candidate.baseRevision === this.document.revision,
                revisionScope: this.revisionScope,
                appearance: this.settings.themeMode, generatedFit: this.generatedFit, errorMessage: this.message, reduceMotion: this.settings.reduceMotion,
                onSelect: (id: string) => { this.selectedNodeId = id; }, onAction: (action: EditorAction) => { return this.action(action); },
                onGenerate: (text: string) => { this.generate(text); }, onCancel: () => { this.cancelGeneration(); },
                onApplyCandidate: () => { this.applyCandidate(); }, onDiscardCandidate: () => { this.discardCandidate(); },
                onExport: (format: string) => { this.exportDocument(format); } })
            }.tabBar(this.tabLabel('DIY 导图', $r('sys.symbol.rectangle_3_group'), 1))
            TabContent() {
              LibraryPage({ externalOpenError: this.resourceOpenError, failedResourceId: this.failedResourceId,
                onOpenResource: (resource: LearningResource) => { this.openResource(resource); },
                onUseTopic: (text: string) => {
                  if (!this.busy) { this.homeDraft = text; this.homeError = ''; this.currentTab = 0; }
                } })
            }.tabBar(this.tabLabel('资料库', $r('sys.symbol.book_pages'), 2))
            TabContent() {
              ProfilePage({ settings: this.settings, documents: this.documents, connectionMessage: this.connectionMessage,
                onSaveSettings: (settings: AppSettings) => { this.saveSettings(settings); },
                onCheckConnection: () => { this.checkConnection(); }, onOpenDocument: (id: string) => { this.openDocument(id); },
                onRenameDocument: (id: string, title: string) => { this.renameDocument(id, title); },
                onDeleteDocument: (id: string) => { this.deleteDocument(id); }, onImport: () => { this.importDocument(); } })
            }.tabBar(this.tabLabel('个人', $r('sys.symbol.person'), 3))
          }.barMode(BarMode.Fixed).barHeight(60).barBackgroundColor($r('app.color.fs_surface'))
            .divider({ strokeWidth: 0.5, color: $r('app.color.fs_border') })
            .animationDuration(this.settings.reduceMotion ? 0 : 120).scrollable(false).layoutWeight(1)
            .backgroundColor($r('app.color.fs_bg')).onChange((index: number) => { this.currentTab = index; })
        }
      }.width('100%').height('100%').backgroundColor($r('app.color.fs_bg'))
    }.mode(NavigationMode.Stack).hideTitleBar(true)
  }
}
