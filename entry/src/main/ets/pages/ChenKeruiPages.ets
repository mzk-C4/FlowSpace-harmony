// ChenKeruiPages.ets
// FlowSpace · 陈珂睿模块全部页面（鸿蒙 ArkTS / ArkUI）
// 包含：15 行动工作台、09 概念对比台、10 对比实验结果、16 练习反馈与回流、18 学习记录/详情
// 路由名（router_map.json）：actionWorkbench / conceptCompare / compareResult / practiceFeedback / learningRecords
// 所有页面共用 PracticeService 作为唯一数据源；遵循 requirements.md 与 UI 设计稿（05-action-feedback、03-compare）。

import { PillTag } from '../components/PillTag';
import {
  CompareLaunchParams,
  CompareRecord,
  LaunchParams,
  NodeRef,
  PracticeLaunchParams,
  PracticeRecord,
  STATE_QUESTION,
  STATE_ACTUAL,
  STATE_FEEDBACK,
  STATE_SOURCE,
  TEMPLATE_STATE,
  TEMPLATE_STACK_QUEUE,
  getNodeRef
} from '../model/PracticeModels';
import { PracticeService } from '../service/PracticeService';

// ── 设计稿语义强调色（mid-tone，深浅色主题下均可读）──
const ACCENT_PURPLE: string = '#7C6BD6';
const ACCENT_PURPLE_BG: string = '#EFEBFB';
const ACCENT_MINT: string = '#2E9E6B';
const ACCENT_MINT_BG: string = '#E6F4EC';
const ACCENT_AMBER: string = '#C2762E';
const ACCENT_AMBER_BG: string = '#FCEFE2';
const ACCENT_LAVENDER_BG: string = '#EDEAFB';

// ════════════════════════════════════════════════════════════════
// 15 行动工作台
// ════════════════════════════════════════════════════════════════
@Component
export struct ActionWorkbenchPage {
  pathStack: NavPathStack = new NavPathStack();
  @State params: LaunchParams = { spaceId: 'space_hm', nodeId: 'state', templateId: TEMPLATE_STATE };
  @State nodeRef: NodeRef = getNodeRef('state');

  // 观察示例：普通变量 vs 状态变量，明确区分“数据值”与“界面显示值”
  @State commonData: number = 2;     // 普通变量：数据值
  @State commonShown: number = 2;    // 普通变量：界面显示值（不随点击变化）
  @State stateData: number = 2;      // 状态变量：数据值
  @State stateShown: number = 2;     // 状态变量：界面显示值（随点击变化）

  // 先预测，再点击
  @State predicted: string = '';     // '' | '会更新' | '不会更新'
  @State situation: string = '';     // '能解释了' | '还没懂' | '先留个问题'
  @State explanationDraft: string = '';
  @State draftId: string = 'draft_aw_0';

  aboutToAppear(): void {
    this.draftId = 'draft_aw_' + Date.now().toString();
  }

  private onReady(ctx: NavDestinationContext): void {
    this.pathStack = ctx.pathStack;
    const p = ctx.pathInfo.param as PracticeLaunchParams;
    if (p && p.nodeId) {
      this.params = {
        spaceId: p.spaceId || 'space_hm',
        nodeId: p.nodeId,
        templateId: p.templateId || TEMPLATE_STATE,
        taskId: p.taskId
      };
      this.nodeRef = getNodeRef(p.nodeId);
    }
  }

  private submitAndCheck(): void {
    if (this.predicted === '') {
      this.getUIContext().getPromptAction().showToast({ message: '请先选择你的预测' });
      return;
    }
    const p: PracticeLaunchParams = {
      spaceId: this.params.spaceId,
      nodeId: this.params.nodeId,
      templateId: this.params.templateId,
      taskId: this.params.taskId,
      draftId: this.draftId,
      predicted: this.predicted,
      explanation: this.explanationDraft,
      situation: this.situation
    };
    this.pathStack.pushPathByName('practiceFeedback', p);
  }

  @Builder
  varDemoCard(title: string, tagText: string, tagBg: string, tagFg: string, mode: string, hint: string) {
    Column({ space: 8 }) {
      Row() {
        Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        PillTag({ text: tagText, bg: tagBg, fg: tagFg })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Column({ space: 2 }) {
          Text('数据值').fontSize(11).fontColor($r('app.color.text_tertiary'))
          Text((mode === 'common' ? this.commonData : this.stateData).toString()).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
        Column({ space: 2 }) {
          Text('界面显示值').fontSize(11).fontColor($r('app.color.text_tertiary'))
          Text((mode === 'common' ? this.commonShown : this.stateShown).toString()).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.brand'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Button('+1')
          .fontSize(13)
          .fontColor($r('app.color.on_brand'))
          .backgroundColor($r('app.color.brand'))
          .height(32)
          .onClick(() => {
            if (mode === 'common') {
              this.commonData = this.commonData + 1;
            } else {
              this.stateData = this.stateData + 1;
              this.stateShown = this.stateData;
            }
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(hint).fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.bg_card'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  stepper(active: number) {
    Row({ space: 6 }) {
      ForEach([1, 2, 3], (step: number) => {
        Row({ space: 6 }) {
          Text(step.toString())
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(step === active ? $r('app.color.on_brand') : $r('app.color.text_secondary'))
            .backgroundColor(step === active ? $r('app.color.brand') : $r('app.color.bg_card'))
            .width(22).height(22).borderRadius(11)
            .textAlign(TextAlign.Center)
          Text(step === 1 ? '观察' : step === 2 ? '解释' : '修改')
            .fontSize(12)
            .fontColor(step === active ? $r('app.color.brand') : $r('app.color.text_secondary'))
        }
        .alignItems(VerticalAlign.Center)
      }, (step: number) => step.toString())
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          // 上下文：胶囊 + 面包屑
          Row({ space: 8 }) {
            PillTag({ text: '行动工作台', bg: '#EAEDFB', fg: '#4C5FD5' })
            Text(this.nodeRef.spaceName + ' / ' + this.nodeRef.name)
              .fontSize(12).fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text('这一次，把一件事做明白')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            .width('100%')

          // 任务卡
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text('理解状态变化如何影响界面').fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Row() {
                PillTag({ text: '约 10 分钟', bg: '#EAEDFB', fg: '#4C5FD5' })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.brand_weak'))
          .borderRadius(16)
          .alignItems(VerticalAlign.Center)

          this.stepper(1)

          // 观察示例
          Column({ space: 12 }) {
            Row() {
              Text('观察一次变化').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
              PillTag({ text: '示例练习', bg: ACCENT_LAVENDER_BG, fg: '#6B5BD0' })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            this.varDemoCard('普通变量', '数据不驱动界面', ACCENT_AMBER_BG, ACCENT_AMBER, 'common',
              '改了数据，界面显示值不变 —— 这正是需要状态变量的原因。')

            this.varDemoCard('状态变量', '数据驱动界面', ACCENT_MINT_BG, ACCENT_MINT, 'state',
              '数据一变，界面自动跟着刷新。')

            Row() {
              Text('变化前 2')
                .fontSize(13).fontColor($r('app.color.text_secondary'))
                .backgroundColor($r('app.color.bg_card'))
                .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(8)
              Text('→').fontSize(13).fontColor($r('app.color.text_tertiary')).margin({ left: 8, right: 8 })
              Text('变化后 ' + this.stateShown)
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.brand'))
                .backgroundColor($r('app.color.brand_weak'))
                .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(8)
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // 先预测，再点击
          Column({ space: 10 }) {
            Text('先预测，再点击').fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text(STATE_QUESTION).fontSize(14).fontColor($r('app.color.text_primary')).width('100%')
            Row({ space: 16 }) {
              Row({ space: 6 }) {
                Radio({ value: '会更新', group: 'predict' })
                  .checked(this.predicted === '会更新')
                  .onChange((isOn: boolean) => { if (isOn) { this.predicted = '会更新'; } })
                Text('会更新').fontSize(14).fontColor($r('app.color.text_primary'))
              }
              Row({ space: 6 }) {
                Radio({ value: '不会更新', group: 'predict' })
                  .checked(this.predicted === '不会更新')
                  .onChange((isOn: boolean) => { if (isOn) { this.predicted = '不会更新'; } })
                Text('不会更新').fontSize(14).fontColor($r('app.color.text_primary'))
              }
            }
            .width('100%')
            Row() {
              Text('关联资料：')
                .fontSize(12).fontColor($r('app.color.text_tertiary'))
              Text(STATE_SOURCE)
                .fontSize(12).fontColor($r('app.color.brand'))
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // 我现在的情况
          Column({ space: 10 }) {
            Text('我现在的情况').fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Row({ space: 8 }) {
              this.situationPill('能解释了', '能解释了')
              this.situationPill('还没懂', '还没懂')
              this.situationPill('先留个问题', '先留个问题')
            }
            .width('100%')
            TextInput({ placeholder: '写下你的解释或问题…', text: this.explanationDraft })
              .onChange((v: string) => { this.explanationDraft = v })
              .width('100%')
              .height(80)
              .backgroundColor($r('app.color.bg_card'))
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(12)
              .padding(12)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          Button('提交并检查')
            .fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_brand'))
            .backgroundColor($r('app.color.brand'))
            .height(46).width('100%').borderRadius(12)
            .onClick(() => { this.submitAndCheck(); })
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .align(Alignment.TopStart)
    }
    .title('行动工作台')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => { this.onReady(ctx); })
  }

  @Builder
  situationPill(label: string, value: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.situation === value ? $r('app.color.on_brand') : $r('app.color.text_secondary'))
      .backgroundColor(this.situation === value ? $r('app.color.brand') : $r('app.color.bg_card'))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(999)
      .onClick(() => { this.situation = value; })
  }
}

@Builder
export function actionWorkbenchBuilder() {
  ActionWorkbenchPage()
}

// ════════════════════════════════════════════════════════════════
// 09 概念对比台
// ════════════════════════════════════════════════════════════════
@Component
export struct ConceptComparePage {
  pathStack: NavPathStack = new NavPathStack();
  @State params: LaunchParams = { spaceId: 'space_ds', nodeId: 'stack', templateId: TEMPLATE_STACK_QUEUE };
  @State nodeRef: NodeRef = getNodeRef('stack');

  @State inputSeq: string[] = [];      // 已加入元素
  @State addCursor: number = 0;        // 下一个待加入字母下标
  @State stackPick: string = 'C';      // 对栈的预测取出
  @State queuePick: string = 'A';      // 对队列的预测取出
  @State intent: string = '';
  @State draftId: string = 'draft_cmp_0';

  private readonly letters: string[] = ['A', 'B', 'C'];

  aboutToAppear(): void {
    this.draftId = 'draft_cmp_' + Date.now().toString();
  }

  private onReady(ctx: NavDestinationContext): void {
    this.pathStack = ctx.pathStack;
    const p = ctx.pathInfo.param as CompareLaunchParams;
    if (p && p.nodeId) {
      this.params = {
        spaceId: p.spaceId || 'space_ds',
        nodeId: p.nodeId,
        templateId: p.templateId || TEMPLATE_STACK_QUEUE,
        taskId: p.taskId
      };
      this.nodeRef = getNodeRef(p.nodeId);
    }
  }

  private addElement(): void {
    if (this.inputSeq.length >= 3) {
      this.getUIContext().getPromptAction().showToast({ message: '已加入 A、B、C' });
      return;
    }
    this.inputSeq.push(this.letters[this.addCursor]);
    this.addCursor = this.addCursor + 1;
  }

  private runOnce(): void {
    if (this.inputSeq.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请先加入元素' });
      return;
    }
    const p: CompareLaunchParams = {
      spaceId: this.params.spaceId,
      nodeId: this.params.nodeId,
      templateId: this.params.templateId,
      taskId: this.params.taskId,
      draftId: this.draftId,
      inputSeq: this.inputSeq,
      stackPick: this.stackPick,
      queuePick: this.queuePick
    };
    this.pathStack.pushPathByName('compareResult', p);
  }

  @Builder
  stackVisual(seq: string[]) {
    Column({ space: 4 }) {
      Text('↓ 从这里取出').fontSize(10).fontColor(ACCENT_PURPLE)
      // 栈顶在上：逆序渲染
      ForEach(seq.slice().reverse(), (item: string) => {
        Text(item)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.on_brand'))
          .width(48).height(40)
          .backgroundColor(ACCENT_PURPLE)
          .borderRadius(8)
          .textAlign(TextAlign.Center)
      }, (item: string) => item + '_s')
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  queueVisual(seq: string[]) {
    Row({ space: 4 }) {
      ForEach(seq, (item: string) => {
        Text(item)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.on_brand'))
          .width(40).height(40)
          .backgroundColor(ACCENT_MINT)
          .borderRadius(8)
          .textAlign(TextAlign.Center)
      }, (item: string) => item + '_q')
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  compareRow(label: string, stackText: string, queueText: string) {
    Row() {
      Text(label).fontSize(13).fontColor($r('app.color.text_secondary')).width(84)
      Text('栈：' + stackText).fontSize(13).fontColor(ACCENT_PURPLE).layoutWeight(1)
      Text('队列：' + queueText).fontSize(13).fontColor(ACCENT_MINT).layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  pickSelector(label: string, current: string, group: string, color: string) {
    Column({ space: 6 }) {
      Text(label).fontSize(12).fontColor($r('app.color.text_secondary')).width('100%')
      Row({ space: 8 }) {
        ForEach(this.letters, (letter: string) => {
          Text(letter)
            .fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(current === letter ? $r('app.color.on_brand') : $r('app.color.text_secondary'))
            .backgroundColor(current === letter ? color : $r('app.color.bg_card'))
            .width(36).height(36).borderRadius(8).textAlign(TextAlign.Center)
            .onClick(() => {
              if (group === 'stack') { this.stackPick = letter; }
              else { this.queuePick = letter; }
            })
        }, (letter: string) => group + letter)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 8 }) {
            PillTag({ text: '对比台', bg: '#EAEDFB', fg: '#4C5FD5' })
            Text(this.nodeRef.spaceName + ' / ' + this.nodeRef.name).fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%').alignItems(VerticalAlign.Center)

          Text('同一批数据，两种顺序').fontSize(22).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).width('100%')

          // 栈 / 队列 双卡片
          Row({ space: 12 }) {
            Column({ space: 10 }) {
              Row() {
                Text('栈').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                PillTag({ text: '后进先出', bg: ACCENT_PURPLE_BG, fg: ACCENT_PURPLE })
              }
              .width('100%').justifyContent(FlexAlign.SpaceBetween)
              this.stackVisual(this.inputSeq)
            }
            .layoutWeight(1).padding(14).backgroundColor($r('app.color.bg_card'))
            .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
            .alignItems(HorizontalAlign.Center)

            Column({ space: 10 }) {
              Row() {
                Text('队列').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                PillTag({ text: '先进先出', bg: ACCENT_MINT_BG, fg: ACCENT_MINT })
              }
              .width('100%').justifyContent(FlexAlign.SpaceBetween)
              Column({ space: 4 }) {
                Text('← 从这里取出').fontSize(10).fontColor(ACCENT_MINT)
                this.queueVisual(this.inputSeq)
              }
              .alignItems(HorizontalAlign.Start)
            }
            .layoutWeight(1).padding(14).backgroundColor($r('app.color.bg_card'))
            .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')

          // 对比行
          Column({ space: 0 }) {
            this.compareRow('插入位置', '栈顶', '队尾')
            Divider().color($r('app.color.divider'))
            this.compareRow('取出位置', '栈顶', '队头')
          }
          .width('100%').padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)

          // 先猜结果
          Column({ space: 12 }) {
            Text('先猜结果').fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text('按 A、B、C 顺序加入后，各取出一个，会得到什么？').fontSize(13)
              .fontColor($r('app.color.text_primary')).width('100%')
            this.pickSelector('栈', this.stackPick, 'stack', ACCENT_PURPLE)
            this.pickSelector('队列', this.queuePick, 'queue', ACCENT_MINT)
          }
          .width('100%').padding(16).backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          Row({ space: 8 }) {
            Button('加入元素')
              .fontSize(14).fontColor($r('app.color.brand'))
              .backgroundColor($r('app.color.brand_weak')).height(42).layoutWeight(1)
              .onClick(() => { this.addElement(); })
            Button('运行一次')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_brand')).backgroundColor($r('app.color.brand'))
              .height(42).layoutWeight(1)
              .onClick(() => { this.runOnce(); })
          }
          .width('100%')

          Row() {
            Text('已验证的练习模板').fontSize(11).fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')

          TextInput({ placeholder: '说说你想比较什么…', text: this.intent })
            .onChange((v: string) => { this.intent = v })
            .width('100%').height(44).backgroundColor($r('app.color.bg_card'))
            .border({ width: 1, color: $r('app.color.divider') }).borderRadius(12)
            .padding({ left: 14, right: 14 })
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .width('100%').alignItems(HorizontalAlign.Start)
      }
      .scrollBar(BarState.Off).width('100%').height('100%')
      .backgroundColor($r('app.color.bg_page')).align(Alignment.TopStart)
    }
    .title('概念对比台')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => { this.onReady(ctx); })
  }
}

@Builder
export function conceptCompareBuilder() {
  ConceptComparePage()
}

// ════════════════════════════════════════════════════════════════
// 10 对比实验结果
// ════════════════════════════════════════════════════════════════
@Component
export struct CompareResultPage {
  pathStack: NavPathStack = new NavPathStack();
  @State params: CompareLaunchParams = {
    spaceId: 'space_ds', nodeId: 'stack', templateId: TEMPLATE_STACK_QUEUE,
    draftId: 'draft_cmp_0', inputSeq: ['A', 'B', 'C'], stackPick: 'C', queuePick: 'A'
  };
  @State nodeRef: NodeRef = getNodeRef('stack');

  @State stackOut: string = 'C';
  @State queueOut: string = 'A';
  @State stackRemain: string[] = ['B', 'A'];
  @State queueRemain: string[] = ['B', 'C'];
  @State explanation: string = '栈从同一端进出，队列从两端进出，所以顺序不同。';
  @State addToReview: boolean = false;
  @State stackPick: string = '';
  @State queuePick: string = '';

  private onReady(ctx: NavDestinationContext): void {
    this.pathStack = ctx.pathStack;
    const p = ctx.pathInfo.param as CompareLaunchParams;
    if (p) {
      this.stackPick = p.stackPick ?? '';
      this.queuePick = p.queuePick ?? '';
    }
    if (p && p.nodeId) {
      this.params = p;
      this.nodeRef = getNodeRef(p.nodeId);
      // 实际结果：栈取最后加入（LIFO），队列取最先加入（FIFO）
      if (p.inputSeq.length > 0) {
        this.stackOut = p.inputSeq[p.inputSeq.length - 1];
        this.queueOut = p.inputSeq[0];
        this.stackRemain = p.inputSeq.slice(0, p.inputSeq.length - 1);
        this.queueRemain = p.inputSeq.slice(1);
      }
    }
  }

  private stackCorrect(): boolean { return this.stackPick === this.stackOut; }
  private queueCorrect(): boolean { return this.queuePick === this.queueOut; }
  private allCorrect(): boolean { return this.stackCorrect() && this.queueCorrect(); }

  private save(): void {
    const record: CompareRecord = {
      recordId: '',
      spaceId: this.params.spaceId,
      spaceName: getNodeRef('stack').spaceName,
      nodeIdA: 'stack',
      nodeIdB: 'queue',
      nodeNameA: getNodeRef('stack').name,
      nodeNameB: getNodeRef('queue').name,
      templateId: this.params.templateId || '',
      inputSeq: this.params.inputSeq,
      stackOut: this.stackOut,
      queueOut: this.queueOut,
      stackRemain: this.stackRemain,
      queueRemain: this.queueRemain,
      diffText: '栈取最后加入的，队列取最先加入的。',
      explanation: this.explanation,
      addToReview: this.addToReview,
      createdAt: ''
    };
    PracticeService.saveCompareRecord(this.params.draftId, record).then(() => {
      this.getUIContext().getPromptAction().showToast({ message: '已保存这次理解' });
      this.pathStack.pop();
    });
  }

  @Builder
  resultCard(title: string, out: string, remain: string[], color: string, colorBg: string, label: string) {
    Column({ space: 10 }) {
      Row() {
        Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        PillTag({ text: label, bg: colorBg, fg: color })
      }
      .width('100%').justifyContent(FlexAlign.SpaceBetween)

      Row({ space: 8 }) {
        // 取出项（高亮）
        Column({ space: 4 }) {
          Text('取出').fontSize(11).fontColor($r('app.color.text_tertiary'))
          Text(out).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.on_brand'))
            .width(44).height(44).backgroundColor(color).borderRadius(8).textAlign(TextAlign.Center)
        }
        .alignItems(HorizontalAlign.Center)
        Text('剩余').fontSize(11).fontColor($r('app.color.text_tertiary')).alignSelf(ItemAlign.End)
        ForEach(remain, (item: string) => {
          Text(item).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            .width(40).height(40).backgroundColor($r('app.color.bg_card'))
            .border({ width: 1, color: $r('app.color.divider') }).borderRadius(8).textAlign(TextAlign.Center)
        }, (item: string) => item + '_r')
      }
      .width('100%').alignItems(VerticalAlign.Center)
    }
    .width('100%').padding(14).backgroundColor($r('app.color.bg_card'))
    .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16).alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          // 结果横幅
          Row({ space: 8 }) {
            Text(this.allCorrect() ? '预测正确，接下来试着解释' : '有地方需要再核对')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.allCorrect() ? ACCENT_MINT : ACCENT_AMBER)
          }
          .width('100%').padding(14)
          .backgroundColor(this.allCorrect() ? ACCENT_MINT_BG : ACCENT_AMBER_BG)
          .borderRadius(12)

          if (!this.allCorrect()) {
            Column({ space: 4 }) {
              if (!this.stackCorrect()) {
                Text('栈：你猜取出 ' + this.stackPick + '，实际取出 ' + this.stackOut).fontSize(12)
                  .fontColor(ACCENT_AMBER)
              }
              if (!this.queueCorrect()) {
                Text('队列：你猜取出 ' + this.queuePick + '，实际取出 ' + this.queueOut).fontSize(12)
                  .fontColor(ACCENT_AMBER)
              }
            }
            .width('100%').alignItems(HorizontalAlign.Start)
          }

          this.resultCard('栈 → 取出 ' + this.stackOut, this.stackOut, this.stackRemain,
            ACCENT_PURPLE, ACCENT_PURPLE_BG, '后进先出')
          this.resultCard('队列 → 取出 ' + this.queueOut, this.queueOut, this.queueRemain,
            ACCENT_MINT, ACCENT_MINT_BG, '先进先出')

          Column({ space: 8 }) {
            Text('差异发生在哪里？').fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text('栈取最后加入的，队列取最先加入的。').fontSize(14)
              .fontColor($r('app.color.text_primary')).width('100%')
            Row() {
              Text('课程资料 · 栈与队列').fontSize(12).fontColor($r('app.color.brand'))
            }
            .width('100%')
          }
          .width('100%').padding(16).backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('用自己的话解释').fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            TextInput({ placeholder: '写下你的理解…', text: this.explanation })
              .onChange((v: string) => { this.explanation = v })
              .width('100%').height(80).backgroundColor($r('app.color.bg_card'))
              .border({ width: 1, color: $r('app.color.divider') }).borderRadius(12).padding(12)
            Row({ space: 8 }) {
              PillTag({ text: '关联到：栈', bg: ACCENT_PURPLE_BG, fg: ACCENT_PURPLE })
              PillTag({ text: '队列', bg: ACCENT_MINT_BG, fg: ACCENT_MINT })
            }
            .width('100%')
          }
          .width('100%').padding(16).backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // 加入复习计划（默认关，不自动排期）
          Row() {
            Column({ space: 3 }) {
              Text('加入复习计划').fontSize(13).fontColor($r('app.color.text_primary'))
              Text('仅登记，不会自动占用日历').fontSize(11).fontColor($r('app.color.text_tertiary'))
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.addToReview })
              .selectedColor($r('app.color.brand'))
              .onChange((isOn: boolean) => { this.addToReview = isOn; })
          }
          .width('100%').padding(16).backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
          .alignItems(VerticalAlign.Center)

          Button('保存这次理解')
            .fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_brand')).backgroundColor($r('app.color.brand'))
            .height(46).width('100%').borderRadius(12)
            .onClick(() => { this.save(); })
          Button('再试一组')
            .fontSize(14).fontColor($r('app.color.brand')).backgroundColor($r('app.color.brand_weak'))
            .height(42).width('100%').borderRadius(12)
            .onClick(() => { this.pathStack.pop(); })
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .width('100%').alignItems(HorizontalAlign.Start)
      }
      .scrollBar(BarState.Off).width('100%').height('100%')
      .backgroundColor($r('app.color.bg_page')).align(Alignment.TopStart)
    }
    .title('实验结果')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => { this.onReady(ctx); })
  }
}

@Builder
export function compareResultBuilder() {
  CompareResultPage()
}

// ════════════════════════════════════════════════════════════════
// 16 练习反馈与回流
// ════════════════════════════════════════════════════════════════
@Component
export struct PracticeFeedbackPage {
  pathStack: NavPathStack = new NavPathStack();
  @State params: PracticeLaunchParams = {
    spaceId: 'space_hm', nodeId: 'state', templateId: TEMPLATE_STATE,
    draftId: 'draft_aw_0', predicted: '', explanation: '', situation: ''
  };
  @State nodeRef: NodeRef = getNodeRef('state');

  @State explanation: string = '';
  @State taskDone: boolean = true;      // 任务状态（与理解状态独立）
  @State understood: boolean = false;   // 理解状态：false=仍有疑问 true=已理解
  @State addToReview: boolean = false;
  @State saved: boolean = false;

  private onReady(ctx: NavDestinationContext): void {
    this.pathStack = ctx.pathStack;
    const p = ctx.pathInfo.param as PracticeLaunchParams;
    if (p && p.nodeId) {
      this.params = p;
      this.nodeRef = getNodeRef(p.nodeId);
      this.explanation = p.explanation || '状态变化会触发相关界面更新。';
    }
  }

  private correct(): boolean { return this.params.predicted === STATE_ACTUAL; }

  private save(): void {
    const record: PracticeRecord = {
      recordId: '',
      spaceId: this.params.spaceId,
      nodeId: this.params.nodeId,
      nodeName: this.nodeRef.name,
      spaceName: this.nodeRef.spaceName,
      templateId: this.params.templateId || '',
      question: STATE_QUESTION,
      predicted: this.params.predicted,
      actual: STATE_ACTUAL,
      correct: this.correct(),
      explanation: this.explanation,
      feedback: STATE_FEEDBACK,
      source: STATE_SOURCE,
      addToReview: this.addToReview,
      createdAt: ''
    };
    PracticeService.savePracticeRecord(this.params.draftId, record).then(() => {
      this.saved = true;
      this.getUIContext().getPromptAction().showToast({ message: '已保存并回到知识地图' });
      this.pathStack.pop();
    });
  }

  private statusIsOn(mode: string): boolean {
    return mode === 'task' ? this.taskDone : this.understood;
  }

  @Builder
  statusTile(mode: string) {
    Column({ space: 6 }) {
      Text(mode === 'task' ? '任务' : '理解').fontSize(12).fontColor($r('app.color.text_tertiary'))
      Row({ space: 6 }) {
        Text(mode === 'task'
          ? (this.taskDone ? '已完成' : '进行中')
          : (this.understood ? '已理解' : '仍有疑问')).fontSize(14).fontWeight(FontWeight.Bold)
          .fontColor(this.statusIsOn(mode) ? ACCENT_MINT : ACCENT_AMBER)
        Text(this.statusIsOn(mode) ? '✓' : '•').fontSize(14)
          .fontColor(this.statusIsOn(mode) ? ACCENT_MINT : ACCENT_AMBER)
      }
      .alignItems(VerticalAlign.Center)
      Text(this.statusIsOn(mode) ? '点击改为未' : '点击标记为')
        .fontSize(11).fontColor($r('app.color.text_tertiary'))
        .onClick(() => {
          if (mode === 'task') {
            this.taskDone = !this.taskDone;
          } else {
            this.understood = !this.understood;
          }
        })
    }
    .layoutWeight(1).padding(14).backgroundColor($r('app.color.bg_card'))
    .border({ width: 1, color: $r('app.color.divider') }).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          // 提示
          Row({ space: 8 }) {
            Text(this.correct() ? '预测正确' : '这次预测需要再核对')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.correct() ? ACCENT_MINT : ACCENT_AMBER)
          }
          .width('100%').padding(14)
          .backgroundColor(this.correct() ? ACCENT_MINT_BG : ACCENT_AMBER_BG)
          .borderRadius(12)

          // 作答
          Column({ space: 8 }) {
            Text(STATE_QUESTION).fontSize(14).fontColor($r('app.color.text_primary')).width('100%')
            Row({ space: 8 }) {
              Text('你的作答：' + this.params.predicted).fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
          }
          .width('100%').padding(16).backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // 规则校验反馈
          Column({ space: 8 }) {
            Row() {
              Text('规则校验').fontSize(12).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.brand')).layoutWeight(1)
            }
            .width('100%')
            Text(STATE_FEEDBACK).fontSize(14).fontColor($r('app.color.text_primary')).width('100%')
            Row() {
              Text('查看示例与资料').fontSize(12).fontColor($r('app.color.brand'))
                .onClick(() => {
                  this.getUIContext().getPromptAction().showToast({ message: STATE_SOURCE });
                })
            }
            .width('100%')
          }
          .width('100%').padding(16).backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // AI 建议
          Column({ space: 6 }) {
            Text('AI 建议 · 可修改').fontSize(12).fontWeight(FontWeight.Bold)
              .fontColor('#6B5BD0').width('100%')
            Text('试着分别修改普通变量和状态变量，观察差别。').fontSize(13)
              .fontColor($r('app.color.text_primary')).width('100%')
          }
          .width('100%').padding(16).backgroundColor(ACCENT_LAVENDER_BG)
          .borderRadius(16).alignItems(HorizontalAlign.Start)

          // 个人解释（可编辑）
          Column({ space: 8 }) {
            Text('我的理解').fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            TextInput({ placeholder: '写下你的理解…', text: this.explanation })
              .onChange((v: string) => { this.explanation = v })
              .width('100%').height(72).backgroundColor($r('app.color.bg_card'))
              .border({ width: 1, color: $r('app.color.divider') }).borderRadius(12).padding(12)
          }
          .width('100%').padding(16).backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // 任务 / 理解 双独立状态（两者相互独立）
          Row({ space: 12 }) {
            this.statusTile('task')
            this.statusTile('understand')
          }
          .width('100%')

          // 保存目的地
          Row({ space: 10 }) {
            Column() {
              Text('记录将回到：' + this.nodeRef.spaceName + ' / ' + this.nodeRef.name)
                .fontSize(13).fontColor($r('app.color.text_primary'))
              Text('作答、反馈、解释一起保存').fontSize(11).fontColor($r('app.color.text_tertiary'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1)
          }
          .width('100%').padding(14).backgroundColor($r('app.color.brand_weak'))
          .borderRadius(12).alignItems(VerticalAlign.Center)

          // 加入复习
          Row() {
            Column({ space: 3 }) {
              Text('加入下一次复习').fontSize(13).fontColor($r('app.color.text_primary'))
              Text('仅登记，不会自动重排本周计划').fontSize(11).fontColor($r('app.color.text_tertiary'))
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.addToReview })
              .selectedColor($r('app.color.brand'))
              .onChange((isOn: boolean) => { this.addToReview = isOn; })
          }
          .width('100%').padding(16).backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
          .alignItems(VerticalAlign.Center)

          Button('保存并回到知识地图')
            .fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_brand')).backgroundColor($r('app.color.brand'))
            .height(46).width('100%').borderRadius(12)
            .onClick(() => { this.save(); })
          Button('继续修改例子')
            .fontSize(14).fontColor($r('app.color.brand')).backgroundColor($r('app.color.brand_weak'))
            .height(42).width('100%').borderRadius(12)
            .onClick(() => { this.pathStack.pop(); })

          Text('不会自动重排本周计划').fontSize(11).fontColor($r('app.color.text_tertiary'))
            .width('100%').textAlign(TextAlign.Center)
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .width('100%').alignItems(HorizontalAlign.Start)
      }
      .scrollBar(BarState.Off).width('100%').height('100%')
      .backgroundColor($r('app.color.bg_page')).align(Alignment.TopStart)
    }
    .title('本次练习记录')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => { this.onReady(ctx); })
  }
}

@Builder
export function practiceFeedbackBuilder() {
  PracticeFeedbackPage()
}

// ════════════════════════════════════════════════════════════════
// 18 学习记录 / 记录详情（P1）
// ════════════════════════════════════════════════════════════════
@Component
export struct LearningRecordsPage {
  pathStack: NavPathStack = new NavPathStack();
  @State tab: string = 'practice';   // 'practice' | 'compare'
  @State spaceFilter: string = '';    // '' = 全部
  @State practiceRecords: PracticeRecord[] = [];
  @State compareRecords: CompareRecord[] = [];
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.loading = true;
    const sf: string = this.spaceFilter;
    PracticeService.getPracticeRecords(sf === '' ? undefined : sf, undefined).then((list: PracticeRecord[]) => {
      this.practiceRecords = list;
      PracticeService.getCompareRecords(sf === '' ? undefined : sf, undefined).then((clist: CompareRecord[]) => {
        this.compareRecords = clist;
        this.loading = false;
      });
    });
  }

  private onReady(ctx: NavDestinationContext): void {
    this.pathStack = ctx.pathStack;
  }

  @Builder
  tabButton(label: string, value: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.tab === value ? $r('app.color.on_brand') : $r('app.color.text_secondary'))
      .backgroundColor(this.tab === value ? $r('app.color.brand') : $r('app.color.bg_card'))
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(999)
      .onClick(() => { this.tab = value; })
  }

  @Builder
  spaceFilterChip(label: string, value: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.spaceFilter === value ? $r('app.color.brand') : $r('app.color.text_secondary'))
      .backgroundColor(this.spaceFilter === value ? $r('app.color.brand_weak') : $r('app.color.bg_card'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(999)
      .onClick(() => { this.spaceFilter = value; this.reload(); })
  }

  @Builder
  practiceCard(r: PracticeRecord) {
    PracticeRecordCard({ record: r })
  }

  @Builder
  compareCard(r: CompareRecord) {
    CompareRecordCard({ record: r })
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        // 类型页签
        Row({ space: 8 }) {
          this.tabButton('练习记录', 'practice')
          this.tabButton('对比记录', 'compare')
        }
        .width('100%')
        .padding({ left: 4, right: 4 })

        // 空间筛选
        Row({ space: 8 }) {
          this.spaceFilterChip('全部', '')
          this.spaceFilterChip('鸿蒙课程项目', 'space_hm')
          this.spaceFilterChip('数据结构与算法', 'space_ds')
        }
        .width('100%')

        Scroll() {
          Column({ space: 12 }) {
            if (this.loading) {
              Text('加载中...').fontSize(12).fontColor($r('app.color.text_tertiary'))
                .padding({ top: 20, bottom: 20 })
            } else {
              if (this.tab === 'practice') {
                if (this.practiceRecords.length === 0) {
                  this.emptyHint()
                } else {
                  ForEach(this.practiceRecords, (r: PracticeRecord) => {
                    this.practiceCard(r)
                  }, (r: PracticeRecord) => r.recordId)
                }
              } else {
                if (this.compareRecords.length === 0) {
                  this.emptyHint()
                } else {
                  ForEach(this.compareRecords, (r: CompareRecord) => {
                    this.compareCard(r)
                  }, (r: CompareRecord) => r.recordId)
                }
              }
            }
          }
          .width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
        }
        .layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart).width('100%')
      }
      .padding({ left: 16, right: 16, top: 12 })
      .width('100%').height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .alignItems(HorizontalAlign.Start)
    }
    .title('学习记录')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => { this.onReady(ctx); })
  }

  @Builder
  emptyHint() {
    Column({ space: 8 }) {
      Text('还没有记录').fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      Text('在“练一下”或“对比台”完成一次后，记录会出现在这里').fontSize(12)
        .fontColor($r('app.color.text_tertiary')).textAlign(TextAlign.Center)
    }
    .width('100%').padding({ top: 40, bottom: 40 })
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}

@Builder
export function learningRecordsBuilder() {
  LearningRecordsPage()
}

// ── 18 用：可展开的练习记录卡片 ──
@Component
struct PracticeRecordCard {
  record: PracticeRecord = {
    recordId: '', spaceId: '', nodeId: '', nodeName: '', spaceName: '', templateId: '',
    question: '', predicted: '', actual: '', correct: false, explanation: '',
    feedback: '', source: '', addToReview: false, createdAt: ''
  };
  @State expanded: boolean = false;

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text(this.record.nodeName).fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.record.spaceName + ' · ' + this.record.createdAt).fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1)
        PillTag({
          text: this.record.correct ? '预测正确' : '需核对',
          bg: this.record.correct ? '#E6F4EC' : '#FCEFE2',
          fg: this.record.correct ? '#2E9E6B' : '#C2762E'
        })
        Text(this.expanded ? '收起' : '展开')
          .fontSize(12).fontColor($r('app.color.brand'))
          .onClick(() => { this.expanded = !this.expanded; })
      }
      .width('100%').alignItems(VerticalAlign.Center)

      if (this.expanded) {
        Column({ space: 8 }) {
          this.row('问题', this.record.question)
          this.row('你的作答', this.record.predicted)
          this.row('实际结果', this.record.actual)
          this.row('规则校验', this.record.feedback)
          this.row('我的解释', this.record.explanation)
          this.row('来源', this.record.source)
        }
        .width('100%').padding(12).backgroundColor($r('app.color.bg_page'))
        .borderRadius(12).alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%').padding(14).backgroundColor($r('app.color.bg_card'))
    .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  row(label: string, value: string) {
    Row({ space: 8 }) {
      Text(label + '：').fontSize(12).fontColor($r('app.color.text_tertiary')).width(64)
      Text(value).fontSize(13).fontColor($r('app.color.text_primary')).layoutWeight(1)
    }
    .width('100%').alignItems(VerticalAlign.Top)
  }
}

// ── 18 用：可展开的对比记录卡片 ──
@Component
struct CompareRecordCard {
  record: CompareRecord = {
    recordId: '', spaceId: '', spaceName: '', nodeIdA: '', nodeIdB: '', nodeNameA: '', nodeNameB: '',
    templateId: '', inputSeq: [], stackOut: '', queueOut: '', stackRemain: [], queueRemain: [],
    diffText: '', explanation: '', addToReview: false, createdAt: ''
  };
  @State expanded: boolean = false;

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('栈 ' + this.record.nodeNameA + ' / 队列 ' + this.record.nodeNameB)
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          Text(this.record.spaceName + ' · ' + this.record.createdAt).fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(this.expanded ? '收起' : '展开')
          .fontSize(12).fontColor($r('app.color.brand'))
          .onClick(() => { this.expanded = !this.expanded; })
      }
      .width('100%').alignItems(VerticalAlign.Center)

      // 一行摘要：输入 + 两个取出
      Row({ space: 8 }) {
        Text('输入 ' + this.record.inputSeq.join('→')).fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Text('栈取 ' + this.record.stackOut).fontSize(12).fontColor(ACCENT_PURPLE)
        Text('队列取 ' + this.record.queueOut).fontSize(12).fontColor(ACCENT_MINT)
      }
      .width('100%')

      if (this.expanded) {
        Column({ space: 8 }) {
          this.row('输入序列', this.record.inputSeq.join(' → '))
          this.row('栈结果', '取出 ' + this.record.stackOut + '，剩余 ' + this.record.stackRemain.join('、'))
          this.row('队列结果', '取出 ' + this.record.queueOut + '，剩余 ' + this.record.queueRemain.join('、'))
          this.row('差异说明', this.record.diffText)
          this.row('我的解释', this.record.explanation)
        }
        .width('100%').padding(12).backgroundColor($r('app.color.bg_page'))
        .borderRadius(12).alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%').padding(14).backgroundColor($r('app.color.bg_card'))
    .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  row(label: string, value: string) {
    Row({ space: 8 }) {
      Text(label + '：').fontSize(12).fontColor($r('app.color.text_tertiary')).width(64)
      Text(value).fontSize(13).fontColor($r('app.color.text_primary')).layoutWeight(1)
    }
    .width('100%').alignItems(VerticalAlign.Top)
  }
}
