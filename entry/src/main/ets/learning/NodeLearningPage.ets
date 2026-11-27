import { NodeStudy, StudyLink, StudyNote, emptyStudy, decodeStudyNote, encodeStudyNote, validStudyUrl } from './NodeLearning';
import { VisualLesson } from './LessonScript';
import { visualLesson, VISUAL_LESSONS } from './LessonCatalog';
import { LessonPlayer } from './LessonPlayer';
import { LessonRequest } from './LessonClient';

@ComponentV2
export struct NodeLearningPage {
  @Param title: string = '';
  @Param note: string = '';
  @Param documentId: string = '';
  @Param nodeId: string = '';
  @Param revision: number = 0;
  @Param previewLessonId: string = '';
  @Param reduceMotion: boolean = false;
  @Param closeSignal: number = 0;
  @Param saveStatus: string = '';
  @Param externalError: string = '';
  @Param editable: boolean = true;
  @Event onClose: () => void = () => {};
  @Event onSave: (note: string, baseRevision: number) => boolean = () => false;
  @Event onOpenLink: (link: StudyLink) => void = () => {};
  @Event onGenerate: (request: LessonRequest) => Promise<VisualLesson> = () => Promise.reject(new Error('请先连接模型网关。'));
  @Event onCancelGeneration: () => void = () => {};
  @Local data: NodeStudy = emptyStudy();
  @Local explanation: string = '';
  @Local editing: boolean = false;
  @Local dirty: boolean = false;
  @Local draftText: string = '';
  @Local draftCode: string = '';
  @Local draftLanguage: string = 'C++';
  @Local draftLinks: StudyLink[] = [];
  @Local linkTitle: string = '';
  @Local linkUrl: string = '';
  @Local instruction: string = '';
  @Local error: string = '';
  @Local damaged: boolean = false;
  @Local generating: boolean = false;
  @Local candidate: VisualLesson | null = null;
  @Local builtIn: string = '';
  @Local generationRevision: number = -1;
  private editingRevision: number = -1;
  private generationToken: number = 0;
  private alive: boolean = true;

  aboutToAppear(): void { this.load(); this.builtIn = this.previewLessonId; }
  aboutToDisappear(): void { this.alive = false; this.cancel(); }
  @Monitor('closeSignal')
  closeRequested(): void { this.requestClose(); }
  @Monitor('note')
  noteChanged(): void { if (!this.editing && this.candidate === null && !this.generating) this.load(); }
  private load(): void {
    try {
      const parsed: StudyNote = decodeStudyNote(this.note);
      this.data = parsed.study; this.explanation = parsed.text; this.damaged = false;
    } catch (error) { this.error = (error as Error).message; this.damaged = true; this.explanation = this.note; }
  }
  private beginEdit(): void {
    this.editingRevision = this.revision; this.draftText = this.explanation; this.draftCode = this.data.code;
    this.draftLanguage = this.data.language;
    this.draftLinks = this.data.links.slice(); this.linkTitle = ''; this.linkUrl = ''; this.dirty = false; this.error = ''; this.editing = true;
  }
  private addLink(): void {
    if (!this.linkTitle.trim() || !validStudyUrl(this.linkUrl.trim())) { this.error = '请填写链接标题与有效 HTTPS 地址。'; return; }
    if (this.draftLinks.length >= 8) { this.error = '最多添加 8 个链接。'; return; }
    const next: StudyLink = { title: this.linkTitle.trim(), url: this.linkUrl.trim() };
    this.draftLinks = this.draftLinks.concat([next]); this.linkTitle = ''; this.linkUrl = ''; this.error = ''; this.dirty = true;
  }
  private saveEdit(): void {
    if (this.linkTitle.trim() || this.linkUrl.trim()) { this.error = '还有未添加的链接，请先点击“添加链接”或清空输入。'; return; }
    try {
      const study: NodeStudy = { version: 1, lessonId: this.data.lessonId, language: this.draftLanguage.trim(),
        code: this.draftCode, links: this.draftLinks, generated: this.data.generated };
      const note: string = encodeStudyNote(this.draftText, study);
      if (!this.onSave(note, this.editingRevision)) { this.error = '节点版本已变化或当前不可编辑；请保留输入，返回确认后重试。'; return; }
      this.data = study; this.explanation = this.draftText; this.editing = false; this.dirty = false; this.error = '';
    } catch (error) { this.error = (error as Error).message; }
  }
  private discardEdit(): void {
    if (!this.dirty && !this.linkTitle && !this.linkUrl) { this.editing = false; return; }
    this.getUIContext().getPromptAction().showDialog({ title: '放弃未保存的资料？', message: '节点原有内容保持不变。',
      buttons: [{ text: '继续编辑', color: $r('app.color.fs_accent') }, { text: '放弃修改', color: $r('app.color.fs_danger') }]
    }).then((result) => { if (result.index === 1) { this.editing = false; this.dirty = false; } }).catch(() => {});
  }
  private requestClose(): void {
    if (this.editing && (this.dirty || this.linkTitle || this.linkUrl) || this.candidate !== null || this.generating) {
      this.getUIContext().getPromptAction().showDialog({ title: '离开学习详情？', message: '未保存的编辑和未应用的 AI 讲解将被放弃，正在生成的请求会取消。',
        buttons: [{ text: '继续学习', color: $r('app.color.fs_accent') }, { text: '离开', color: $r('app.color.fs_danger') }]
      }).then((result) => { if (result.index === 1) { this.cancel(); this.onClose(); } }).catch(() => {});
    } else this.onClose();
  }
  private cancel(): void { this.generationToken++; if (this.generating) this.onCancelGeneration(); this.generating = false; }
  private async generate(): Promise<void> {
    if (this.generating || !this.editable || this.nodeId === '' || this.damaged || this.candidate !== null) return;
    const token: number = ++this.generationToken;
    this.generationRevision = this.revision; this.error = ''; this.generating = true;
    const request: LessonRequest = { requestId: 'lesson-' + Date.now() + '-' + Math.random().toString(36).slice(2, 9),
      documentId: this.documentId, nodeId: this.nodeId, baseRevision: this.revision, topic: this.title,
      instruction: this.instruction, context: this.explanation, code: this.data.code, links: this.data.links };
    try {
      const lesson: VisualLesson = await this.onGenerate(request);
      if (!this.alive || token !== this.generationToken) return;
      this.candidate = lesson;
    } catch (error) { if (this.alive && token === this.generationToken) this.error = (error as Error).message; }
    finally { if (token === this.generationToken) this.generating = false; }
  }
  private applyCandidate(): void {
    if (this.candidate === null || this.generationRevision !== this.revision) { this.error = '节点版本已变化，请放弃候选后重新生成。'; return; }
    try {
      const study: NodeStudy = { version: 1, lessonId: this.data.lessonId, language: this.data.language,
        code: this.data.code, links: this.data.links, generated: this.candidate };
      if (!this.onSave(encodeStudyNote(this.explanation, study), this.generationRevision)) { this.error = '讲解没有保存，节点可能已有修改。'; return; }
      this.data = study; this.candidate = null; this.builtIn = ''; this.error = '';
    } catch (error) { this.error = (error as Error).message; }
  }
  private activeLesson(): VisualLesson { return this.candidate || (this.builtIn ? visualLesson(this.builtIn) : this.data.generated || visualLesson(this.data.lessonId)); }
  private hasLesson(): boolean { return this.candidate !== null || this.builtIn !== '' || this.data.generated !== undefined || this.data.lessonId !== ''; }

  @Builder
  heading(text: string) { Text(text).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).width('100%') }
  @Builder
  editForm() {
    Column({ space: 12 }) {
      this.heading('编辑节点资料')
      TextArea({ text: this.draftText, placeholder: '知识说明、公式、学习笔记…' }).height(120).maxLength(10000)
        .fontSize(15).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
        .onChange((value: string) => { this.draftText = value; this.dirty = true; })
      this.heading('链接 · 最多 8 项')
      ForEach(this.draftLinks, (link: StudyLink, index: number) => {
        Row({ space: 8 }) {
          Text(link.title + '\n' + link.url).fontSize(13).lineHeight(20).fontColor($r('app.color.fs_muted')).layoutWeight(1)
          Button('移除').height(44).fontSize(12).backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_danger'))
            .onClick(() => { this.draftLinks = this.draftLinks.filter((_link: StudyLink, i: number) => i !== index); this.dirty = true; })
        }.width('100%')
      }, (link: StudyLink, index: number) => index + link.url)
      TextInput({ text: this.linkTitle, placeholder: '资料标题' }).height(48).maxLength(120).fontColor($r('app.color.fs_text'))
        .backgroundColor($r('app.color.fs_bg')).onChange((value: string) => { this.linkTitle = value; })
      TextInput({ text: this.linkUrl, placeholder: 'https:// 原站链接' }).height(48).maxLength(2000).fontColor($r('app.color.fs_text'))
        .backgroundColor($r('app.color.fs_bg')).onChange((value: string) => { this.linkUrl = value; })
      Button('添加链接').height(44).width('100%').fontColor($r('app.color.fs_accent')).backgroundColor($r('app.color.fs_soft'))
        .onClick(() => this.addLink())
      this.heading('代码 · 只展示，不执行')
      TextInput({ text: this.draftLanguage, placeholder: '语言，例如 C++ / Python' }).height(48).maxLength(30)
        .fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
        .onChange((value: string) => { this.draftLanguage = value; this.dirty = true; })
      TextArea({ text: this.draftCode, placeholder: '粘贴该节点对应的代码，最多 6000 字' }).height(220).maxLength(6000)
        .fontSize(13).fontFamily('monospace').fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
        .onChange((value: string) => { this.draftCode = value; this.dirty = true; })
      Row({ space: 10 }) {
        Button('取消').height(48).layoutWeight(1).fontColor($r('app.color.fs_accent')).backgroundColor($r('app.color.fs_soft')).onClick(() => this.discardEdit())
        Button('保存资料').height(48).layoutWeight(1).fontColor($r('app.color.fs_on_accent')).backgroundColor($r('app.color.fs_accent'))
          .onClick(() => this.saveEdit())
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  readContent() {
    Column({ space: 18 }) {
      if (this.explanation) { Text(this.explanation).fontSize(15).lineHeight(25).fontColor($r('app.color.fs_text')).width('100%').copyOption(CopyOptions.LocalDevice) }
      if (this.nodeId !== '') {
        Button('编辑说明、链接与代码').width('100%').height(46).fontSize(14).backgroundColor($r('app.color.fs_soft'))
          .fontColor($r('app.color.fs_accent')).enabled(this.editable && !this.damaged && !this.generating && this.candidate === null)
          .onClick(() => this.beginEdit())
        this.heading('AI 动态讲解')
        Text('根据节点主题、说明和代码生成分步可视化。链接仅作参考地址，未读取原站全文。生成后先预览，确认才保存。')
          .fontSize(13).lineHeight(22).fontColor($r('app.color.fs_muted')).width('100%')
        TextArea({ text: this.instruction, placeholder: '补充要求：例如用生活类比讲清楚，逐步推导，再给反例…' }).height(80).maxLength(2000)
          .fontSize(14).fontColor($r('app.color.fs_text')).backgroundColor($r('app.color.fs_bg'))
          .onChange((value: string) => { this.instruction = value; })
        if (this.generating) {
          Row({ space: 10 }) {
            LoadingProgress().width(24).height(24).color($r('app.color.fs_accent'))
            Text('正在生成分步讲解…').fontSize(14).fontColor($r('app.color.fs_muted')).layoutWeight(1)
            Button('取消').height(44).backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent')).onClick(() => this.cancel())
          }.width('100%')
        } else {
          Button(this.data.generated === undefined ? '生成动态讲解' : '重新生成讲解').height(48).width('100%')
            .fontColor($r('app.color.fs_on_accent')).backgroundColor($r('app.color.fs_accent'))
            .enabled(this.editable && !this.damaged && this.candidate === null).onClick(() => this.generate())
        }
      }
      if (this.candidate !== null) {
        Text('AI 候选 · 尚未保存，请核对事实与演示步骤。').fontSize(14).fontColor($r('app.color.fs_accent')).width('100%')
        Row({ space: 8 }) {
          Button('放弃').height(44).layoutWeight(1).backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
            .onClick(() => { this.candidate = null; this.error = ''; })
          Button('应用并保存').height(44).layoutWeight(1).backgroundColor($r('app.color.fs_accent')).fontColor($r('app.color.fs_on_accent'))
            .enabled(this.generationRevision === this.revision && this.editable).onClick(() => this.applyCandidate())
        }.width('100%')
        if (this.generationRevision !== this.revision) { Text('候选已过期，节点有新修改，请放弃后重试。').fontSize(13).fontColor($r('app.color.fs_danger')) }
      }
      if (this.hasLesson()) {
        Text(this.candidate !== null || (!this.builtIn && this.data.generated !== undefined) ? 'AI 生成内容 · 请对照可靠来源核实' : '内置教学演示 · 非本次 AI 生成')
          .fontSize(12).fontColor($r('app.color.fs_muted')).width('100%')
        LessonPlayer({ lesson: this.activeLesson(), reduceMotion: this.reduceMotion })
        if (this.activeLesson().sourceUrl) {
          Button(this.activeLesson().sourceTitle || '查看参考来源').height('auto').constraintSize({ minHeight: 44 }).width('100%')
            .fontSize(13).fontColor($r('app.color.fs_accent')).backgroundColor($r('app.color.fs_soft'))
            .onClick(() => { this.onOpenLink({ title: this.activeLesson().sourceTitle, url: this.activeLesson().sourceUrl }); })
        }
      } else if (this.nodeId === '') {
        Text('从下方选择一份内置示例，查看逐步高亮与代码对应效果。').fontSize(14).fontColor($r('app.color.fs_muted'))
      }
      if (this.data.links.length > 0) {
        this.heading('节点资料 · 原站链接')
        ForEach(this.data.links, (link: StudyLink) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 5 }) {
              Text(link.title + ' ↗').fontSize(15).fontColor($r('app.color.fs_accent')).width('100%')
              Text(link.url).fontSize(11).lineHeight(18).wordBreak(WordBreak.BREAK_ALL).fontColor($r('app.color.fs_muted')).width('100%')
            }.padding(14).width('100%')
          }.height('auto').constraintSize({ minHeight: 44 }).width('100%').padding(0).backgroundColor($r('app.color.fs_bg')).borderRadius(12)
            .onClick(() => this.onOpenLink(link))
        }, (link: StudyLink, index: number) => index + link.url)
      }
      if (this.data.code) {
        this.heading('附带代码 · ' + (this.data.language || '文本'))
        Text(this.data.code).fontSize(13).fontFamily('monospace').lineHeight(22).wordBreak(WordBreak.BREAK_ALL)
          .fontColor($r('app.color.fs_text')).padding(14).width('100%').backgroundColor($r('app.color.fs_bg')).borderRadius(12)
          .copyOption(CopyOptions.LocalDevice)
      }
      this.heading('内置演示 · 切换不改写节点')
      Row({ space: 6 }) {
        ForEach(VISUAL_LESSONS, (lesson: VisualLesson) => {
          Button(lesson.id === 'ring' ? '环形数组' : lesson.id === 'queue' ? '队列' : '栈').height(44).layoutWeight(1).fontSize(13)
            .backgroundColor(this.builtIn === lesson.id ? $r('app.color.fs_accent') : $r('app.color.fs_soft'))
            .fontColor(this.builtIn === lesson.id ? $r('app.color.fs_on_accent') : $r('app.color.fs_accent'))
            .onClick(() => { this.builtIn = lesson.id; })
        }, (lesson: VisualLesson) => lesson.id)
      }.width('100%')
      if (this.builtIn && (this.data.generated !== undefined || this.candidate !== null)) {
        Button('返回 AI 讲解').height(44).fontColor($r('app.color.fs_accent')).backgroundColor($r('app.color.fs_soft')).onClick(() => { this.builtIn = ''; })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    Column() {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text(this.title || '知识动态讲解').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.fs_text')).maxLines(2)
          Text(this.nodeId ? '节点学习详情 · ' + this.saveStatus : '可视化教学示例').fontSize(11).fontColor($r('app.color.fs_muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button('关闭').height(44).fontSize(14).fontColor($r('app.color.fs_accent')).backgroundColor(Color.Transparent).onClick(() => this.requestClose())
      }.padding(18).width('100%')
      Divider().color($r('app.color.fs_border'))
      Scroll() {
        Column({ space: 16 }) {
          if (this.error || this.externalError) {
            Text(this.error || this.externalError).fontSize(14).lineHeight(23).fontColor($r('app.color.fs_danger')).width('100%')
          }
          if (this.editing) { this.editForm() } else { this.readContent() }
        }.width('100%').padding({ left: 18, right: 18, top: 20, bottom: 36 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Auto)
    }.width('100%').height('100%').backgroundColor($r('app.color.fs_surface'))
  }
}
