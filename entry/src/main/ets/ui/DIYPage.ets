import { createDocument, EditorAction, MindMapDocument, MindMapNode, ChatMessage } from '../domain/MindMap';
import { appSymbol, IconButton } from './Controls';
import { MindMapCanvas } from '../canvas/MindMapCanvas';

class NodeDataSource implements IDataSource {
  private nodes: MindMapNode[] = [];
  constructor(nodes: MindMapNode[]) { this.nodes = nodes; }
  totalCount(): number { return this.nodes.length; }
  getData(index: number): MindMapNode { return this.nodes[index]; }
  registerDataChangeListener(_listener: DataChangeListener): void {}
  unregisterDataChangeListener(_listener: DataChangeListener): void {}
}

@ComponentV2
export struct DIYPage {
  @Param document: MindMapDocument = createDocument();
  @Param selectedNodeId: string = '';
  @Param canUndo: boolean = false;
  @Param canRedo: boolean = false;
  @Param busy: boolean = false;
  @Param progress: string = '';
  @Param saveStatus: string = '已保存';
  @Param candidateSummary: string = '';
  @Param canApply: boolean = false;
  @Param appearance: string = 'system';
  @Param generatedFit: number = 0;
  @Param errorMessage: string = '';
  @Param reduceMotion: boolean = false;
  @Event onSelect: (id: string) => void = () => {};
  @Event onAction: (action: EditorAction) => boolean = () => false;
  @Event onGenerate: (instruction: string) => void = () => {};
  @Event onCancel: () => void = () => {};
  @Event onApplyCandidate: () => void = () => {};
  @Event onDiscardCandidate: () => void = () => {};
  @Event onExport: (format: string) => void = () => {};
  @Local sheetOpen: boolean = false;
  @Local panel: string = 'node';
  @Local editKind: string = 'edit';
  @Local nodeText: string = '';
  @Local nodeNote: string = '';
  @Local instruction: string = '';
  @Local parentId: string = '';
  @Local fitSignal: number = 0;
  @Local zoomSignal: number = 0;
  @Local zoomPercent: number = 100;
  @Local canvasMode: string = '2d';
  @Local resetViewSignal: number = 0;
  @Local formError: string = '';
  private editingId: string = '';
  private activeDocument: string = '';
  private chatScroll: Scroller = new Scroller();

  aboutToAppear(): void { this.activeDocument = this.document.documentId; }

  @Monitor('document')
  documentChanged(): void {
    if (this.document.documentId === this.activeDocument) { return; }
    this.activeDocument = this.document.documentId;
    this.instruction = ''; this.formError = ''; this.sheetOpen = false;
  }

  @Monitor('candidateSummary')
  candidateChanged(): void {
    if (this.candidateSummary) {
      if (this.panel === 'chat') { this.sheetOpen = false; }
      this.fitSignal++;
    }
  }

  private node(): MindMapNode {
    return this.document.nodes.find((node: MindMapNode) => node.id === this.selectedNodeId) ||
      this.document.nodes.find((node: MindMapNode) => node.id === this.document.rootId) || this.document.nodes[0];
  }

  private wholeMap(): boolean { return this.node().id === this.document.rootId; }

  private scopeLabel(): string {
    return this.wholeMap() ? '整张导图' : '分支 · ' + this.node().text;
  }

  private editable(): boolean { return this.candidateSummary.length === 0; }

  private send(kind: string, text: string = '', note: string = '', parent: string = '', nodeId: string = ''): boolean {
    if (!this.editable()) { return false; }
    const needsNode: boolean = kind !== 'undo' && kind !== 'redo' && kind !== 'layout' && kind !== 'rename';
    const action: EditorAction = { kind: kind, nodeId: needsNode ? (nodeId || this.node().id) : '',
      parentId: parent, text: text, note: note };
    return this.onAction(action);
  }

  private openPanel(panel: string): void {
    this.panel = panel; this.formError = ''; this.sheetOpen = true;
  }

  private openEditor(kind: string): void {
    this.editKind = kind;
    this.editingId = this.node().id;
    this.nodeText = kind === 'edit' ? this.node().text : kind === 'rename' ? this.document.title : '';
    this.nodeNote = kind === 'edit' ? this.node().note : '';
    this.parentId = this.node().parentId;
    this.openPanel('node');
  }

  private submitEditor(): void {
    if (this.nodeText.trim().length === 0) { this.formError = '请先填写内容。'; return; }
    if (this.send(this.editKind, this.nodeText.trim(), this.nodeNote.trim(), '', this.editingId)) this.sheetOpen = false;
    else this.formError = '修改未应用，请检查错误提示后重试。输入已保留。';
  }

  private remove(): void {
    const id: string = this.node().id;
    const documentId: string = this.document.documentId;
    if (id === this.document.rootId || !this.editable()) { return; }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除这个分支？', message: '“' + this.node().text + '”及其所有子节点将被删除，可通过撤销恢复。',
      buttons: [{ text: '取消', color: '#6D7080' }, { text: '删除分支', color: '#C43B4D' }]
    }).then((result) => {
      if (result.index === 1 && documentId === this.document.documentId) { this.send('remove', '', '', '', id); }
    }).catch(() => {});
  }

  private openMove(): void {
    this.editingId = this.node().id;
    this.parentId = this.node().parentId;
    this.openPanel('move');
  }

  private moveTargets(): MindMapNode[] {
    const blocked: Set<string> = new Set<string>();
    blocked.add(this.editingId);
    for (let depth: number = 0; depth < 9; depth++) {
      this.document.nodes.forEach((node: MindMapNode) => { if (blocked.has(node.parentId)) { blocked.add(node.id); } });
    }
    return this.document.nodes.filter((node: MindMapNode) => !blocked.has(node.id));
  }

  private submitChat(): void {
    if (!this.instruction.trim() || this.instruction.length > 20000 || this.busy || this.candidateSummary) { return; }
    this.onGenerate(this.instruction.trim());
    // Keep the submitted draft available for retry and cancellation.
  }

  @Builder
  heading(title: string) {
    Text(title).width('100%').fontSize(24).fontWeight(FontWeight.Bold)
      .padding({ right: 38 }).fontColor($r('app.color.fs_text')).textAlign(TextAlign.Start)
  }

  @Builder
  primary(label: string, enabled: boolean, action: () => void) {
    Button(label, { type: ButtonType.Normal }).height(48).width('100%').borderRadius(14)
      .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_on_accent'))
      .backgroundColor($r('app.color.fs_accent')).enabled(enabled).opacity(enabled ? 1 : 0.45).onClick(action)
  }

  @Builder
  menuRow(icon: Resource, label: string, enabled: boolean, action: () => void, danger: boolean = false) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        appSymbol(icon, 19, danger ? $r('app.color.fs_danger') : $r('app.color.fs_accent'))
        Text(label).layoutWeight(1).fontSize(16).maxLines(2).textAlign(TextAlign.Start)
          .fontColor(danger ? $r('app.color.fs_danger') : $r('app.color.fs_text'))
        appSymbol($r('sys.symbol.chevron_right'), 13, $r('app.color.fs_muted'))
      }.width('100%')
    }.width('100%').height('auto').constraintSize({ minHeight: 48 }).padding({ left: 14, right: 14 })
      .borderRadius(12).backgroundColor($r('app.color.fs_bg')).enabled(enabled).opacity(enabled ? 1 : 0.40)
      .accessibilityText(label).onClick(action)
  }

  @Builder
  nodeSheet() {
    Column({ space: 14 }) {
      this.heading(this.editKind === 'edit' ? '编辑节点' : this.editKind === 'addChild' ? '添加子节点' :
        this.editKind === 'addSibling' ? '添加同级节点' : '重命名导图')
      if (this.editKind !== 'rename') {
        Text('当前节点 · ' + this.node().text).fontSize(14).fontColor($r('app.color.fs_muted')).maxLines(2)
      }
      TextInput({ text: this.nodeText, placeholder: this.editKind === 'rename' ? '导图名称' : '节点文字' })
        .height(52).fontSize(17).maxLength(this.editKind === 'rename' ? 200 : 500)
        .onChange((value: string) => { this.nodeText = value; this.formError = ''; })
        .backgroundColor($r('app.color.fs_bg')).fontColor($r('app.color.fs_text'))
        .accessibilityText(this.editKind === 'rename' ? '导图名称' : '节点文字').id('node-title')
      if (this.editKind === 'edit') {
        TextArea({ text: this.nodeNote, placeholder: '备注（选填）' }).height(96).maxLength(10000)
          .fontSize(16).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
          .onChange((value: string) => { this.nodeNote = value; })
      }
      if (this.formError) { Text(this.formError).fontColor($r('app.color.fs_danger')).fontSize(14) }
      this.primary('保存', this.editable(), () => this.submitEditor())
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  actionsSheet() {
    Column({ space: 6 }) {
      this.heading('导图工具')
      Text(this.node().text).width('100%').fontSize(14).maxLines(2).fontColor($r('app.color.fs_muted'))
        .padding({ top: 6, bottom: 4 })
      this.menuRow($r('sys.symbol.plus_circle'), '添加同级节点', this.editable() && this.node().id !== this.document.rootId,
        () => this.openEditor('addSibling'))
      this.menuRow($r('sys.symbol.chevron_down'), this.node().collapsed ? '展开分支' : '折叠分支',
        this.editable() && this.document.nodes.some((node: MindMapNode) => node.parentId === this.node().id),
        () => { if (this.send('toggle')) { this.sheetOpen = false; } })
      this.menuRow($r('sys.symbol.rectangle_3_group'), '移动分支', this.editable() && this.node().id !== this.document.rootId,
        () => this.openMove())
      this.menuRow($r('sys.symbol.trash'), '删除分支', this.editable() && this.node().id !== this.document.rootId,
        () => { this.sheetOpen = false; this.remove(); }, true)
      Divider().color($r('app.color.fs_border')).margin({ top: 8, bottom: 8 })
      this.menuRow($r('sys.symbol.rectangle_3_group'), this.document.layout === 'down' ? '改为向右布局' : '改为向下布局',
        this.editable(), () => {
          if (this.send('layout', this.document.layout === 'down' ? 'right' : 'down')) {
            this.sheetOpen = false; this.fitSignal++;
          }
        })
      this.menuRow($r('sys.symbol.square_and_pencil'), '重命名导图', this.editable(), () => this.openEditor('rename'))
      this.menuRow($r('sys.symbol.doc_text'), '查看原文', true, () => this.openPanel('source'))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  moveSheet() {
    Column({ space: 12 }) {
      this.heading('移动分支')
      Text('选择新的父节点。下属节点将随分支一起移动。').fontColor($r('app.color.fs_muted')).fontSize(14)
      List({ space: 5 }) {
        LazyForEach(new NodeDataSource(this.moveTargets()), (target: MindMapNode) => {
          ListItem() {
            Button(target.text, { type: ButtonType.Normal }).width('100%').constraintSize({ minHeight: 46 })
              .borderRadius(12).fontColor(this.parentId === target.id ? $r('app.color.fs_accent') : $r('app.color.fs_text'))
              .backgroundColor(this.parentId === target.id ? $r('app.color.fs_soft') : $r('app.color.fs_bg'))
              .onClick(() => { this.parentId = target.id; })
          }
        }, (target: MindMapNode) => target.id)
      }.height(240).width('100%').cachedCount(6)
      this.primary('移到这里', this.editable() && this.parentId.length > 0 && this.parentId !== this.node().parentId,
        () => { if (this.send('move', '', '', this.parentId, this.editingId)) { this.sheetOpen = false; } })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  chatSheet() {
    Column({ space: 8 }) {
      this.heading('继续整理')
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text('修改范围').fontSize(11).fontColor($r('app.color.fs_muted'))
          Text(this.scopeLabel()).fontColor($r('app.color.fs_accent')).fontSize(14).fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (!this.wholeMap()) {
          Button('改为整图', { type: ButtonType.Normal }).height(40).fontSize(13).padding({ left: 12, right: 12 })
            .backgroundColor($r('app.color.fs_surface')).fontColor($r('app.color.fs_accent')).borderRadius(20)
            .onClick(() => { this.onSelect(''); })
        }
      }.width('100%').padding({ left: 12, right: 10, top: 8, bottom: 8 })
        .borderRadius(14).backgroundColor($r('app.color.fs_soft'))
      Scroll(this.chatScroll) {
        Column({ space: 10 }) {
          if (this.document.messages.length === 0) {
            Text('可以试试“为每个分支补充一个例子”。生成后可在画布上确认或放弃修改。')
              .fontSize(14).lineHeight(21).width('100%').fontColor($r('app.color.fs_muted'))
              .padding(12).borderRadius(12).backgroundColor($r('app.color.fs_bg'))
          }
          ForEach(this.document.messages.slice(-20), (message: ChatMessage) => {
            Column({ space: 5 }) {
              Text(message.role === 'user' ? '你' : 'FlowSpace AI').fontSize(13).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.fs_accent'))
              Text(message.content).fontSize(15).fontColor($r('app.color.fs_text')).width('100%').copyOption(CopyOptions.InApp)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(12).borderRadius(12).backgroundColor($r('app.color.fs_bg'))
          }, (message: ChatMessage) => message.id)
          if (this.errorMessage) { Text(this.errorMessage).fontColor($r('app.color.fs_danger')).fontSize(14).width('100%') }
        }.width('100%')
          .onAreaChange(() => { this.chatScroll.scrollEdge(Edge.Bottom); })
      }.layoutWeight(1).width('100%').align(Alignment.TopStart)
      if (this.busy) {
        Row({ space: 10 }) {
          LoadingProgress().width(18).height(18).color($r('app.color.fs_accent'))
          Column({ space: 2 }) {
            Text(this.progress || '正在生成修改建议').fontSize(14).fontColor($r('app.color.fs_text')).maxLines(1)
            Text(this.scopeLabel()).fontSize(11).fontColor($r('app.color.fs_muted')).maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button('取消').height(44).fontSize(14).fontColor($r('app.color.fs_accent'))
            .backgroundColor($r('app.color.fs_soft')).onClick(() => this.onCancel())
        }.width('100%').padding({ left: 12, right: 6, top: 6, bottom: 6 })
          .borderRadius(14).backgroundColor($r('app.color.fs_bg'))
      } else if (this.candidateSummary) {
        this.primary('查看候选', true, () => { this.sheetOpen = false; this.fitSignal++; })
      } else {
        if (this.instruction.length > 20000) {
          Text('超过 20,000 字，请缩短后发送。').fontSize(13).fontColor($r('app.color.fs_danger'))
        }
        Row({ space: 8 }) {
          TextArea({ text: this.instruction, placeholder: '描述你希望怎样修改…' })
            .height(62).layoutWeight(1).fontSize(16).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
            .accessibilityText('整理指令').id('chat-input').onChange((value: string) => { this.instruction = value; })
          Button({ type: ButtonType.Circle }) {
            appSymbol($r('sys.symbol.arrow_up'), 22, $r('app.color.fs_on_accent'))
          }.width(46).height(46).padding(0).backgroundColor($r('app.color.fs_accent'))
            .enabled(this.instruction.trim().length > 0 && this.instruction.length <= 20000)
            .opacity(this.instruction.trim().length > 0 && this.instruction.length <= 20000 ? 1 : 0.42)
            .accessibilityText('发送整理指令').id('chat-send').onClick(() => this.submitChat())
        }.width('100%')
      }
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 18, bottom: 12 })
      .backgroundColor($r('app.color.fs_surface'))
  }

  @Builder
  exportSheet() {
    Column({ space: 8 }) {
      this.heading('导出导图')
      Text('选择格式后可在系统文件选择器中保存。').fontSize(14).fontColor($r('app.color.fs_muted'))
        .padding({ bottom: 8 })
      this.menuRow($r('sys.symbol.rectangle_3_group'), 'PNG · 完整导图', this.editable(), () => {
        this.sheetOpen = false; this.onExport('png');
      })
      this.menuRow($r('sys.symbol.list_bullet'), 'Markdown · 层级大纲', this.editable(), () => {
        this.sheetOpen = false; this.onExport('markdown');
      })
      this.menuRow($r('sys.symbol.doc_text'), 'JSON · 可恢复的备份', this.editable(), () => {
        this.sheetOpen = false; this.onExport('json');
      })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  sheetContent() {
    if (this.panel === 'chat') {
      this.chatSheet()
    } else {
      Scroll() {
        Column({ space: 12 }) {
          if (this.panel === 'node') { this.nodeSheet() }
          else if (this.panel === 'move') { this.moveSheet() }
          else if (this.panel === 'actions') { this.actionsSheet() }
          else if (this.panel === 'source') {
            this.heading('原始输入')
            Text(this.document.sourceText || '手动创建的导图没有原文。').width('100%').fontSize(16).lineHeight(24)
              .fontColor($r('app.color.fs_text')).copyOption(CopyOptions.InApp)
          } else { this.exportSheet() }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
      }.width('100%').height('100%').align(Alignment.TopStart).backgroundColor($r('app.color.fs_surface'))
    }
  }

  @Builder
  feedback() {
    if (this.candidateSummary) {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(this.canApply ? '候选预览' : '候选已过期').fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor(this.canApply ? $r('app.color.fs_accent') : $r('app.color.fs_danger')).layoutWeight(1)
          Text(this.document.nodes.length + ' 个节点').fontSize(12).fontColor($r('app.color.fs_muted'))
        }.width('100%')
        Text('修改范围 · ' + this.scopeLabel()).fontSize(12).fontColor($r('app.color.fs_muted'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(this.canApply ? this.candidateSummary : '导图已有新的编辑，请放弃候选后重新生成。')
          .fontSize(14).fontColor($r('app.color.fs_text')).width('100%').maxLines(2)
        if (this.canApply) {
          Text('应用后可一次撤销，恢复修改前的导图。').fontSize(11).fontColor($r('app.color.fs_muted')).width('100%')
        }
        Row({ space: 8 }) {
          Button('放弃候选').height(44).layoutWeight(1).fontSize(14).backgroundColor($r('app.color.fs_surface'))
            .fontColor($r('app.color.fs_muted')).onClick(() => this.onDiscardCandidate())
          Button('确认应用').height(44).layoutWeight(1.8).fontSize(15).fontWeight(FontWeight.Medium)
            .backgroundColor($r('app.color.fs_accent')).fontColor($r('app.color.fs_on_accent'))
            .enabled(this.canApply).opacity(this.canApply ? 1 : 0.45).onClick(() => this.onApplyCandidate())
        }.width('100%')
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 10 }).backgroundColor($r('app.color.fs_soft'))
    } else if (this.busy) {
      Row({ space: 10 }) {
        LoadingProgress().width(18).height(18).color($r('app.color.fs_accent'))
        Column({ space: 2 }) {
          Text(this.progress || '正在生成导图').fontSize(14).fontColor($r('app.color.fs_text')).maxLines(1)
          Text('范围 · ' + this.scopeLabel()).fontSize(11).fontColor($r('app.color.fs_muted')).maxLines(1)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button('取消').height(44).fontSize(14).backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
          .onClick(() => this.onCancel())
      }.width('100%').padding({ left: 16, right: 10, top: 6, bottom: 6 })
    }
    if (this.errorMessage && !this.candidateSummary) {
      Text(this.errorMessage).fontSize(14).fontColor($r('app.color.fs_danger')).padding(10).width('100%').maxLines(3)
    }
  }

  build() {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text(this.document.title).fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.saveStatus + ' · ' + this.document.nodes.length + ' 个节点').fontSize(13)
            .fontColor(this.saveStatus.startsWith('未保存') ? $r('app.color.fs_danger') : $r('app.color.fs_muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        IconButton({ icon: $r('sys.symbol.arrow_counterclockwise'), label: '撤销', available: this.editable() && this.canUndo,
          onActivate: () => { this.send('undo'); } })
        IconButton({ icon: $r('sys.symbol.arrow_clockwise'), label: '重做', available: this.editable() && this.canRedo,
          onActivate: () => { this.send('redo'); } })
        IconButton({ icon: $r('sys.symbol.share'), label: '导出', available: this.editable(),
          onActivate: () => this.openPanel('export') })
      }.width('100%').padding({ left: 18, right: 8, top: 7, bottom: 7 }).backgroundColor($r('app.color.fs_surface'))
      Divider().color($r('app.color.fs_border')).strokeWidth(0.5)
      this.feedback()
      Stack({ alignContent: Alignment.BottomEnd }) {
        MindMapCanvas({ document: this.document, selectedNodeId: this.node().id, fitSignal: this.fitSignal + this.generatedFit,
          appearance: this.appearance, viewMode: this.canvasMode, zoomSignal: this.zoomSignal,
          resetViewSignal: this.resetViewSignal, onSelect: (id: string) => { this.onSelect(id); },
          onToggle: (id: string) => { this.send('toggle', '', '', '', id); },
          onZoom: (value: number) => { this.zoomPercent = value; } })
        if (this.document.nodes.length === 1 && !this.candidateSummary && !this.busy) {
          Column() {
            Column({ space: 4 }) {
              Text('从根节点开始').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
              Text('点选节点后用下方 ＋ 添加分支，打开“继续整理”让 AI 扩展；右下角切换 2D / 3D，3D 单指旋转、双指平移缩放。')
                .fontSize(13).lineHeight(19).fontColor($r('app.color.fs_muted')).maxLines(2)
            }.alignItems(HorizontalAlign.Start).padding(14).borderRadius(14)
              .backgroundColor($r('app.color.fs_surface')).border({ width: 0.5, color: $r('app.color.fs_border') })
          }.width('100%').height('100%').padding(16).justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
            .hitTestBehavior(HitTestMode.None)
        }
        Row({ space: 0 }) {
          Button(this.canvasMode === '3d' ? '3D' : '2D', { type: ButtonType.Normal })
            .width(44).height(44).padding(0).fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.fs_accent'))
            .backgroundColor(this.canvasMode === '3d' ? $r('app.color.fs_soft') : Color.Transparent)
            .borderRadius(22).accessibilityText('切换二维或三维视图')
            .onClick(() => { this.canvasMode = this.canvasMode === '3d' ? '2d' : '3d'; })
          Divider().vertical(true).height(20).color($r('app.color.fs_border'))
          IconButton({ icon: $r('sys.symbol.minus'), label: '缩小画布', onActivate: () => { this.zoomSignal--; } })
          Text(this.zoomPercent === 0 ? '<0.1%' : this.zoomPercent + '%').fontSize(12).fontColor($r('app.color.fs_muted'))
            .constraintSize({ minWidth: 34 }).textAlign(TextAlign.Center)
          IconButton({ icon: $r('sys.symbol.plus'), label: '放大画布', onActivate: () => { this.zoomSignal++; } })
          Divider().vertical(true).height(20).color($r('app.color.fs_border'))
          IconButton({ icon: $r('sys.symbol.scope'), label: '适应画布', onActivate: () => { this.fitSignal++; } })
          if (this.canvasMode === '3d') {
            Divider().vertical(true).height(20).color($r('app.color.fs_border'))
            Button('复位', { type: ButtonType.Normal }).width(44).height(44).padding(0).fontSize(11)
              .fontColor($r('app.color.fs_accent')).backgroundColor(Color.Transparent).borderRadius(22)
              .accessibilityText('重置三维视角').onClick(() => { this.resetViewSignal++; })
          }
        }.borderRadius(22).backgroundColor($r('app.color.fs_surface'))
          .border({ width: 0.5, color: $r('app.color.fs_border') }).margin(12)
      }.width('100%').layoutWeight(1).clip(true)
      Divider().color($r('app.color.fs_border')).strokeWidth(0.5)
      Row({ space: 2 }) {
        Column({ space: 1 }) {
          Text(this.wholeMap() ? '整张导图' : '当前分支').fontSize(11).fontColor($r('app.color.fs_muted'))
          Text(this.node().text).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        IconButton({ icon: $r('sys.symbol.square_and_pencil'), label: '编辑选中节点', available: this.editable(),
          onActivate: () => this.openEditor('edit') })
        IconButton({ icon: $r('sys.symbol.plus_circle'), label: '添加子节点', available: this.editable(),
          onActivate: () => this.openEditor('addChild') })
        IconButton({ icon: $r('sys.symbol.ellipsis_circle'), label: '更多导图工具', onActivate: () => this.openPanel('actions') })
        Button('继续整理', { type: ButtonType.Normal }).height(40).constraintSize({ minWidth: 80 })
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_accent'))
          .padding({ left: 12, right: 12 }).borderRadius(20).backgroundColor($r('app.color.fs_soft')).id('open-chat')
          .accessibilityText('继续整理，打开对话').onClick(() => this.openPanel('chat'))
      }.padding({ left: 16, right: 8, top: 4, bottom: 6 }).backgroundColor($r('app.color.fs_surface')).width('100%')
    }.width('100%').height('100%').backgroundColor($r('app.color.fs_bg'))
      .bindSheet(this.sheetOpen, this.sheetContent(), { height: SheetSize.LARGE, showClose: true,
        backgroundColor: $r('app.color.fs_surface'), keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
        onDisappear: () => { this.sheetOpen = false; } })
  }
}
