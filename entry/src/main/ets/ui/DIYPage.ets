import { createDocument, EditorAction, MindMapDocument, MindMapNode, ChatMessage } from '../domain/MindMap';
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
  @Local sourceOpen: boolean = false;
  @Local fitSignal: number = 0;
  @Local zoomSignal: number = 0;
  @Local zoomPercent: number = 100;
  @Local formError: string = '';
  private editingId: string = '';

  private node(): MindMapNode {
    return this.document.nodes.find((node: MindMapNode) => node.id === this.selectedNodeId) ||
      this.document.nodes.find((node: MindMapNode) => node.id === this.document.rootId) || this.document.nodes[0];
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

  private moveTargets(): MindMapNode[] {
    const blocked: Set<string> = new Set<string>();
    blocked.add(this.node().id);
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
  tool(label: string, enabled: boolean, action: () => void) {
    Button(label, { type: ButtonType.Normal })
      .height(44).padding({ left: 15, right: 15 }).borderRadius(12)
      .constraintSize({ minWidth: 44 })
      .fontSize(14).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_surface'))
      .enabled(enabled).opacity(enabled ? 1 : 0.4).onClick(action)
  }

  @Builder
  nodeSheet() {
    Column({ space: 16 }) {
      Text(this.editKind === 'edit' ? '编辑节点' : this.editKind === 'addChild' ? '添加子节点' :
        this.editKind === 'addSibling' ? '添加同级节点' : '重命名导图')
        .fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).width('100%')
      Text(this.editKind === 'rename' ? '为这份想法取个名字。' : '当前分支：' + this.node().text)
        .fontSize(13).fontColor($r('app.color.fs_muted')).width('100%').maxLines(2)
      TextInput({ text: this.nodeText, placeholder: '节点内容' }).height(52).maxLength(this.editKind === 'rename' ? 200 : 500)
        .onChange((value: string) => { this.nodeText = value; this.formError = ''; })
        .backgroundColor($r('app.color.fs_bg')).fontColor($r('app.color.fs_text'))
        .accessibilityText(this.editKind === 'rename' ? '导图名称，最多200字' : '节点标题，最多500字')
      if (this.editKind === 'edit') {
        TextArea({ text: this.nodeNote, placeholder: '补充说明、学习重点或链接（可选）' })
          .height(130).maxLength(10000).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
          .onChange((value: string) => { this.nodeNote = value; })
      }
      if (this.formError) { Text(this.formError).fontColor($r('app.color.fs_danger')).fontSize(13) }
      Button('保存修改').height(48).width('100%').backgroundColor($r('app.color.fs_accent'))
        .enabled(this.editable()).onClick(() => this.submitEditor())
    }.width('100%').padding(20)
  }

  @Builder
  moveSheet() {
    Column({ space: 12 }) {
      Text('移动分支').fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).width('100%')
      Text('选择新的父节点，子树将一起移动。').fontColor($r('app.color.fs_muted')).fontSize(14).width('100%')
      List({ space: 8 }) {
          LazyForEach(new NodeDataSource(this.moveTargets()), (target: MindMapNode) => {
            ListItem() {
            Button(target.text, { type: ButtonType.Normal })
              .width('100%').constraintSize({ minHeight: 48 }).borderRadius(12)
              .fontColor(this.parentId === target.id ? $r('app.color.fs_accent') : $r('app.color.fs_text'))
              .backgroundColor(this.parentId === target.id ? $r('app.color.fs_soft') : $r('app.color.fs_bg'))
              .onClick(() => { this.parentId = target.id; })
            }
          }, (target: MindMapNode) => target.id)
      }.height(260).width('100%').cachedCount(6)
      Button('移到所选节点下').width('100%').height(48).backgroundColor($r('app.color.fs_accent'))
        .enabled(this.editable() && this.parentId.length > 0 && this.parentId !== this.node().parentId)
        .onClick(() => { if (this.send('move', '', '', this.parentId)) this.sheetOpen = false; })
    }.padding(20).width('100%')
  }

  @Builder
  chatSheet() {
    Column({ space: 12 }) {
      Text('让想法继续生长').fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).width('100%')
      Text(this.node().id === this.document.rootId ? '修改范围：整张导图' : '修改范围：选中分支 · ' + this.node().text)
        .fontColor($r('app.color.fs_muted')).fontSize(13).maxLines(2).width('100%')
      if (this.node().id !== this.document.rootId) {
        Button('改为整理整张导图').height(44).onClick(() => { this.onSelect(''); })
      }
      Scroll() {
        Column({ space: 12 }) {
          if (this.document.messages.length === 0) {
            Text('试试“补充实际应用案例”或“整理成复习提纲”。AI 的修改会先在画布中预览，由你确认后保存。')
              .fontSize(15).lineHeight(24).fontColor($r('app.color.fs_muted'))
          }
          ForEach(this.document.messages.slice(-20), (message: ChatMessage) => {
            Column({ space: 5 }) {
              Text(message.role === 'user' ? '你' : 'FlowSpace AI').fontSize(12).fontColor($r('app.color.fs_accent'))
              Text(message.content).fontSize(14).fontColor($r('app.color.fs_text')).width('100%').copyOption(CopyOptions.InApp)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(12).borderRadius(12)
              .backgroundColor($r('app.color.fs_bg'))
          }, (message: ChatMessage) => message.id)
        }.width('100%')
      }.height(190).width('100%')
      if (this.busy) {
        Text(this.progress || '正在生成候选导图…').fontColor($r('app.color.fs_accent')).fontSize(14)
        Button('取消生成').height(44).onClick(() => this.onCancel())
      }
      if (this.errorMessage) { Text(this.errorMessage).fontColor($r('app.color.fs_danger')).fontSize(13) }
      if (this.candidateSummary) {
        Text('候选已显示在画布，关闭面板后可检查并应用。').fontSize(14).fontColor($r('app.color.fs_accent'))
        Button('查看候选画布').height(44).onClick(() => { this.sheetOpen = false; this.fitSignal++; })
      } else {
        TextArea({ text: this.instruction, placeholder: '描述你希望怎样修改这个分支…' })
          .height(100).fontSize(16).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
          .onChange((value: string) => { this.instruction = value; })
        if (this.instruction.length > 20000) {
          Text('输入超过20,000字，请缩短后再发送；原文已保留。').fontSize(13).fontColor($r('app.color.fs_danger'))
        }
        Button('生成修改建议').width('100%').height(48).backgroundColor($r('app.color.fs_accent'))
          .enabled(!this.busy && this.instruction.trim().length > 0 && this.instruction.length <= 20000).onClick(() => this.submitChat())
      }
    }.padding(20).width('100%')
  }

  @Builder
  exportSheet() {
    Column({ space: 16 }) {
      Text('带走你的想法').fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).width('100%')
      Text('选择格式后，在系统文件选择器中保存。').fontSize(14).fontColor($r('app.color.fs_muted')).width('100%')
      this.tool('PNG · 完整导图图片', this.editable(), () => { this.sheetOpen = false; this.onExport('png'); })
      this.tool('Markdown · 层级大纲', this.editable(), () => { this.sheetOpen = false; this.onExport('markdown'); })
      this.tool('JSON · 可恢复的备份', this.editable(), () => { this.sheetOpen = false; this.onExport('json'); })
    }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
  }

  @Builder
  sheetContent() {
    Scroll() {
      Column() {
        if (this.panel === 'node') { this.nodeSheet() }
        else if (this.panel === 'move') { this.moveSheet() }
        else if (this.panel === 'chat') { this.chatSheet() }
        else { this.exportSheet() }
      }.width('100%').padding({ bottom: 24 })
    }.width('100%').height('100%').backgroundColor($r('app.color.fs_surface'))
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Column({ space: 3 }) {
          Text('DIY / 思维导图').fontSize(11).fontColor($r('app.color.fs_muted')).letterSpacing(1)
          Text(this.document.title).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.saveStatus + ' · ' + this.document.nodes.length + ' 个节点')
            .fontSize(12).fontColor($r('app.color.fs_muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        this.tool('导出', this.editable(), () => this.openPanel('export'))
      }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
      Scroll() {
        Row({ space: 8 }) {
          this.tool('撤销', this.editable() && this.canUndo, () => this.send('undo'))
          this.tool('重做', this.editable() && this.canRedo, () => this.send('redo'))
          this.tool(this.document.layout === 'down' ? '布局：向下 ↓' : '布局：向右 →', this.editable(),
            () => this.send('layout', this.document.layout === 'down' ? 'right' : 'down'))
          this.tool('重命名', this.editable(), () => this.openEditor('rename'))
          this.tool(this.sourceOpen ? '收起源文' : '查看源文', true, () => { this.sourceOpen = !this.sourceOpen; })
        }.padding({ left: 16, right: 16 })
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').height(52)
      if (this.sourceOpen) {
        Scroll() {
          Text(this.document.sourceText || '这份导图由手动创建，尚无来源文本。')
            .fontSize(13).lineHeight(21).fontColor($r('app.color.fs_muted')).copyOption(CopyOptions.InApp).padding(16)
        }.height(112).width('100%').backgroundColor($r('app.color.fs_surface'))
      }
      if (this.candidateSummary) {
        Column({ space: 8 }) {
          Text('候选预览 · 尚未保存').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_accent'))
          Text(this.candidateSummary).fontSize(13).fontColor($r('app.color.fs_text')).maxLines(3)
          Row({ space: 10 }) {
            Button('放弃候选').height(44).backgroundColor($r('app.color.fs_surface')).fontColor($r('app.color.fs_text'))
              .onClick(() => this.onDiscardCandidate())
            Button('确认应用').height(44).backgroundColor($r('app.color.fs_accent')).onClick(() => this.onApplyCandidate())
          }
        }.width('100%').padding(12).backgroundColor($r('app.color.fs_soft'))
      }
      if (this.busy) {
        Row({ space: 8 }) {
          LoadingProgress().width(20).height(20).color($r('app.color.fs_accent'))
          Text(this.progress || 'AI 正在整理想法…').fontSize(13).fontColor($r('app.color.fs_accent')).layoutWeight(1).maxLines(2)
          Button('取消').height(44).onClick(() => this.onCancel())
        }.width('100%').padding({ left: 16, right: 16 })
      }
      if (this.errorMessage) {
        Text(this.errorMessage).fontSize(13).fontColor($r('app.color.fs_danger')).padding(12).width('100%')
      }
      Stack({ alignContent: Alignment.BottomEnd }) {
        MindMapCanvas({ document: this.document, selectedNodeId: this.node().id, fitSignal: this.fitSignal,
          zoomSignal: this.zoomSignal, onSelect: (id: string) => { this.onSelect(id); },
          onZoom: (value: number) => { this.zoomPercent = value; } })
        Row({ space: 6 }) {
          this.tool('−', true, () => { this.zoomSignal--; })
          Text(this.zoomPercent === 0 ? '<0.1%' : this.zoomPercent + '%').fontSize(12).fontColor($r('app.color.fs_muted')).width(42).textAlign(TextAlign.Center)
          this.tool('+', true, () => { this.zoomSignal++; })
          this.tool('适应', true, () => { this.fitSignal++; })
        }.padding(8).borderRadius(16).backgroundColor($r('app.color.fs_surface')).margin(12)
      }.width('100%').layoutWeight(1).clip(true).constraintSize({ minHeight: 150 })
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('当前节点').fontSize(11).fontColor($r('app.color.fs_muted'))
          Text(this.node().text).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.fs_text'))
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          this.tool('编辑', this.editable(), () => this.openEditor('edit'))
        }.width('100%')
        Scroll() {
          Row({ space: 8 }) {
            this.tool('+ 子节点', this.editable(), () => this.openEditor('addChild'))
            this.tool('+ 同级', this.editable() && this.node().id !== this.document.rootId, () => this.openEditor('addSibling'))
            this.tool(this.node().collapsed ? '展开分支' : '折叠分支', this.editable() &&
              this.document.nodes.some((node: MindMapNode) => node.parentId === this.node().id), () => this.send('toggle'))
            this.tool('移动分支', this.editable() && this.node().id !== this.document.rootId, () => {
              this.parentId = this.node().parentId; this.openPanel('move');
            })
            this.tool('删除分支', this.editable() && this.node().id !== this.document.rootId, () => this.remove())
          }
        }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).height(46)
        Button('✦  和 AI 一起完善').width('100%').height(46).fontSize(15)
          .backgroundColor($r('app.color.fs_accent')).onClick(() => this.openPanel('chat'))
      }.padding({ left: 16, right: 16, top: 8, bottom: 12 }).backgroundColor($r('app.color.fs_surface')).width('100%')
    }.width('100%').height('100%').backgroundColor($r('app.color.fs_bg'))
      .bindSheet(this.sheetOpen, this.sheetContent(), { height: SheetSize.LARGE, showClose: true,
        onDisappear: () => { this.sheetOpen = false; } })
  }
}
