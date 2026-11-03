import { EmptyState } from '../components/EmptyState';
import { StatusTag } from '../components/StatusTag';
import {
  ActionResult,
  LearningTask,
  MOCK_TODAY,
  TaskChecklistItem,
  TaskStatus,
  formatDateLabel,
  formatMinutes,
  taskStatusKind,
  taskStatusText
} from '../model/Models';
import { MockService } from '../service/MockService';

@Component
export struct TaskDetailPage {
  pathStack: NavPathStack = new NavPathStack();
  taskId: string = '';
  @State task: LearningTask | null = null;
  @State loaded: boolean = false;
  private shownOnce: boolean = false;

  private load(): void {
    MockService.getTaskDetail(this.taskId).then((data: LearningTask | null) => {
      this.task = data;
      this.loaded = true;
    });
  }

  private doneCount(task: LearningTask): number {
    let total = 0;
    for (let i = 0; i < task.checklist.length; i++) {
      if (task.checklist[i].done) {
        total += 1;
      }
    }
    return total;
  }

  private toggleItem(item: TaskChecklistItem): void {
    MockService.toggleChecklistItem(this.taskId, item.itemId).then((ok: boolean) => {
      if (ok) {
        this.load();
      }
    });
  }

  private startTask(): void {
    MockService.startTask(this.taskId).then((result: ActionResult) => {
      this.getUIContext().getPromptAction().showToast({ message: result.message });
      this.load();
    });
  }

  private completeTask(): void {
    MockService.completeTask(this.taskId).then((result: ActionResult) => {
      this.getUIContext().getPromptAction().showToast({ message: result.message });
      this.load();
    });
  }

  @Builder
  headerCard(task: LearningTask) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(task.spaceName)
          .fontSize(12)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_weak'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(10)
        Blank()
        StatusTag({ label: taskStatusText(task.status), kind: taskStatusKind(task.status) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(task.title)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Row({ space: 14 }) {
        Column({ space: 3 }) {
          Text('日期')
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
          Text(formatDateLabel(task.date) + ' · ' + task.weekday)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)

        Column({ space: 3 }) {
          Text('时间')
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
          Text(task.timeRange)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)

        Column({ space: 3 }) {
          Text('时长')
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
          Text(formatMinutes(task.durationMinutes))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  outputCard(task: LearningTask) {
    Column({ space: 6 }) {
      Text('预计产出')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(task.output)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  checklistCard(task: LearningTask) {
    Column({ space: 10 }) {
      Row() {
        Text('任务清单')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(this.doneCount(task) + '/' + task.checklist.length)
          .fontSize(12)
          .fontColor($r('app.color.brand'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Progress({ value: this.doneCount(task), total: task.checklist.length, type: ProgressType.Linear })
        .color($r('app.color.brand'))
        .backgroundColor($r('app.color.track'))
        .height(5)
        .borderRadius(3)
        .width('100%')

      ForEach(task.checklist, (item: TaskChecklistItem) => {
        Row({ space: 10 }) {
          Text(item.done ? '✓' : '○')
            .fontSize(16)
            .fontColor(item.done ? $r('app.color.tag_green_text') : $r('app.color.text_tertiary'))
          Text(item.text)
            .fontSize(13)
            .fontColor(item.done ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
            .layoutWeight(1)
          Text(item.minutes + '分钟')
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .padding({ top: 5, bottom: 5 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.toggleItem(item);
        })
      }, (item: TaskChecklistItem) => item.itemId)
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  knowledgeCard(task: LearningTask) {
    Column({ space: 8 }) {
      Row() {
        Text('关联知识')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('知识关联项目 ›')
          .fontSize(11)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            this.pathStack.pushPathByName('knowledgeProjects', task.spaceId);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (task.nodeNames.length === 0) {
        Text('暂未关联知识点')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      } else {
        Row({ space: 8 }) {
          ForEach(task.nodeNames, (name: string) => {
            Text(name)
              .fontSize(12)
              .fontColor($r('app.color.brand'))
              .backgroundColor($r('app.color.brand_weak'))
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(10)
              .onClick(() => {
                this.pathStack.pushPathByName('knowledgeProjects', task.spaceId);
              })
          }, (name: string) => name)
        }
        .width('100%')
      }

      Text('任务状态与理解状态独立：开始或完成任务不会自动代表掌握知识。')
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  actionCard(task: LearningTask) {
    Column({ space: 10 }) {
      if (task.status === TaskStatus.NotStarted) {
        Button('开始任务')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.on_brand'))
          .backgroundColor($r('app.color.brand'))
          .height(42)
          .width('100%')
          .borderRadius(10)
          .onClick(() => {
            this.startTask();
          })
      } else if (task.status === TaskStatus.InProgress) {
        Button('标记完成')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.on_brand'))
          .backgroundColor($r('app.color.brand'))
          .height(42)
          .width('100%')
          .borderRadius(10)
          .onClick(() => {
            this.completeTask();
          })
      } else {
        Button('已完成')
          .fontSize(14)
          .fontColor($r('app.color.tag_green_text'))
          .backgroundColor($r('app.color.tag_green_bg'))
          .height(42)
          .width('100%')
          .borderRadius(10)
          .enabled(false)
      }

      if (task.status !== TaskStatus.Done) {
        Button('调整计划')
          .fontSize(14)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_weak'))
          .height(42)
          .width('100%')
          .borderRadius(10)
          .enabled(task.durationMinutes >= 45 && task.date === MOCK_TODAY)
          .onClick(() => {
            this.pathStack.pushPathByName('adjustPreview', task.taskId);
          })
        if (task.date !== MOCK_TODAY) {
          Text('只有当天可用时间变化时，才能预览计划调整。')
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        } else if (task.durationMinutes < 45) {
          Text('任务不足 45 分钟，暂不支持按 15 + 30 拆分调整。')
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      if (!this.loaded) {
        Column() {
          Text('加载中...')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.task === null) {
        Column() {
          EmptyState({
            title: '任务不存在或已过期',
            hint: '任务可能已被撤销或调整，请回到安排总览重新选择。',
            actionText: '返回',
            onAction: () => {
              this.pathStack.pop();
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            this.headerCard(this.task!)
            this.outputCard(this.task!)
            this.checklistCard(this.task!)
            this.knowledgeCard(this.task!)
            this.actionCard(this.task!)
          }
          .padding({ left: 16, right: 16, top: 14, bottom: 24 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart)
      }
    }
    .title('学习任务详情')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => {
      this.pathStack = ctx.pathStack;
      const param = ctx.pathInfo.param;
      if (typeof param === 'string' && param !== '') {
        this.taskId = param;
      }
      this.load();
    })
    .onShown(() => {
      if (this.shownOnce) {
        this.load();
      } else {
        this.shownOnce = true;
      }
    })
  }
}

@Builder
export function taskDetailBuilder() {
  TaskDetailPage()
}
