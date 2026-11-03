import { EmptyState } from '../components/EmptyState';
import { SectionTitle } from '../components/SectionTitle';
import { StatusTag } from '../components/StatusTag';
import {
  ActionResult,
  DayPlan,
  LearningTask,
  LifeReservedBlock,
  MOCK_TODAY,
  SpaceTimeline,
  TaskStatus,
  formatMinutes,
  shortDateLabel,
  taskStatusKind,
  taskStatusText
} from '../model/Models';
import { MockService } from '../service/MockService';

@Component
export struct TimelinePage {
  pathStack: NavPathStack = new NavPathStack();
  spaceId: string = 'space_ds';
  @State timeline: SpaceTimeline | null = null;
  @State selectedDayIndex: number = 0;
  @State confirmUndo: boolean = false;
  private shownOnce: boolean = false;

  private load(): void {
    MockService.getSpaceTimeline(this.spaceId).then((data: SpaceTimeline) => {
      this.timeline = data;
      if (this.selectedDayIndex >= data.days.length) {
        this.selectedDayIndex = 0;
      }
    });
  }

  private selectedDay(): DayPlan | null {
    if (this.timeline === null) {
      return null;
    }
    if (this.selectedDayIndex < 0 || this.selectedDayIndex >= this.timeline.days.length) {
      return null;
    }
    return this.timeline.days[this.selectedDayIndex];
  }

  private weekTaskCount(): number {
    if (this.timeline === null) {
      return 0;
    }
    let total = 0;
    for (let i = 0; i < this.timeline.days.length; i++) {
      total += this.timeline.days[i].tasks.length;
    }
    return total;
  }

  private weekMinutes(): number {
    if (this.timeline === null) {
      return 0;
    }
    let total = 0;
    for (let i = 0; i < this.timeline.days.length; i++) {
      total += this.timeline.days[i].totalMinutes;
    }
    return total;
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

  private startTask(task: LearningTask): void {
    MockService.startTask(task.taskId).then((result: ActionResult) => {
      this.getUIContext().getPromptAction().showToast({ message: result.message });
      this.load();
    });
  }

  private openAdjust(task: LearningTask): void {
    this.pathStack.pushPathByName('adjustPreview', task.taskId);
  }

  private openTask(task: LearningTask): void {
    this.pathStack.pushPathByName('taskDetail', task.taskId);
  }

  private doUndo(): void {
    this.confirmUndo = false;
    MockService.undoLastAdjust(this.spaceId).then((result: ActionResult) => {
      this.getUIContext().getPromptAction().showToast({ message: result.message });
      this.load();
    });
  }

  @Builder
  headerStat(label: string, value: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(label)
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  headerCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(this.timeline!.spaceName)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('计划 v' + this.timeline!.planVersion)
          .fontSize(11)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_weak'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(10)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.timeline!.goal)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Row({ space: 8 }) {
        this.headerStat('本周任务', this.weekTaskCount() + ' 项')
        this.headerStat('本周学习', formatMinutes(this.weekMinutes()))
        this.headerStat('每日上限', this.timeline!.dailyLimitMinutes + ' 分钟')
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
  weekStrip(days: DayPlan[]) {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(days, (day: DayPlan, index: number) => {
          Column({ space: 3 }) {
            Text(day.weekday)
              .fontSize(10)
              .fontColor(this.selectedDayIndex === index ?
                $r('app.color.on_brand') : $r('app.color.text_tertiary'))
            Text(shortDateLabel(day.date))
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.selectedDayIndex === index ?
                $r('app.color.on_brand') : $r('app.color.text_primary'))
            Text(day.tasks.length + ' 项')
              .fontSize(9)
              .fontColor(this.selectedDayIndex === index ?
                $r('app.color.on_brand') : $r('app.color.text_tertiary'))
            if (day.isToday) {
              Text('今天')
                .fontSize(9)
                .fontColor(this.selectedDayIndex === index ?
                  $r('app.color.on_brand') : $r('app.color.brand'))
            }
          }
          .width(58)
          .padding({ top: 9, bottom: 7 })
          .borderRadius(12)
          .backgroundColor(this.selectedDayIndex === index ?
            $r('app.color.brand') : $r('app.color.bg_card'))
          .onClick(() => {
            this.selectedDayIndex = index;
          })
        }, (day: DayPlan) => day.date)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  daySummary(day: DayPlan) {
    Column({ space: 6 }) {
      Row({ space: 10 }) {
        Text(day.weekday + ' · ' + shortDateLabel(day.date))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('学习 ' + formatMinutes(day.totalMinutes))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Text('保留 ' + formatMinutes(day.reservedMinutes))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (day.totalMinutes > day.dailyLimitMinutes) {
        Text('提醒：当天学习任务已超过每日上限 ' + day.dailyLimitMinutes + ' 分钟')
          .fontSize(11)
          .fontColor($r('app.color.tag_orange_text'))
          .backgroundColor($r('app.color.tag_orange_bg'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  lifeRow(block: LifeReservedBlock) {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(block.label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(block.timeRange + ' · ' + formatMinutes(block.durationMinutes))
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      StatusTag({ label: '不可占用', kind: 'orange' })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  taskCard(task: LearningTask) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text(task.timeRange.substring(0, 5))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(formatMinutes(task.durationMinutes))
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width(52)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text(task.title)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('产出：' + task.output)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('清单 ' + this.doneCount(task) + '/' + task.checklist.length)
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        StatusTag({ label: taskStatusText(task.status), kind: taskStatusKind(task.status) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 8 }) {
        if (task.status !== TaskStatus.Done) {
          Button(task.status === TaskStatus.InProgress ? '继续' : '开始')
            .fontSize(12)
            .fontColor($r('app.color.on_brand'))
            .backgroundColor($r('app.color.brand'))
            .height(30)
            .borderRadius(8)
            .onClick(() => {
              this.startTask(task);
            })
          Button('调整')
            .fontSize(12)
            .fontColor($r('app.color.brand'))
            .backgroundColor($r('app.color.brand_weak'))
            .height(30)
            .borderRadius(8)
            .enabled(task.durationMinutes >= 45 && task.date === MOCK_TODAY)
            .onClick(() => {
              this.openAdjust(task);
            })
        }
        Blank()
        Text('任务详情 ›')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .padding({ top: 5, bottom: 5 })
          .onClick(() => {
            this.openTask(task);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .borderRadius(14)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  undoCard() {
    Column({ space: 8 }) {
      Text('最近一次计划调整可撤销')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('撤销前会检查之后是否已有新的调整或任务进展；取消不改动任何安排。')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
      if (this.confirmUndo) {
        Row({ space: 8 }) {
          Button('取消')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.bg_page'))
            .height(32)
            .borderRadius(8)
            .onClick(() => {
              this.confirmUndo = false;
            })
          Button('确认撤销')
            .fontSize(12)
            .fontColor($r('app.color.on_brand'))
            .backgroundColor($r('app.color.brand'))
            .height(32)
            .borderRadius(8)
            .onClick(() => {
              this.doUndo();
            })
        }
        .width('100%')
      } else {
        Button('撤销上次调整')
          .fontSize(12)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_weak'))
          .height(32)
          .borderRadius(8)
          .onClick(() => {
            this.confirmUndo = true;
          })
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  dayContent(day: DayPlan) {
    Column({ space: 10 }) {
      this.daySummary(day)

      SectionTitle({ title: '生活保留时间' })
      Text('保留时间不能安排学习任务，调整计划时也会避开。')
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
      ForEach(day.lifeBlocks, (block: LifeReservedBlock) => {
        this.lifeRow(block)
      }, (block: LifeReservedBlock) => block.blockId)

      SectionTitle({ title: '学习任务' })
      if (day.tasks.length === 0) {
        EmptyState({
          title: '这一天没有学习任务',
          hint: '选择其他日期，或到安排总览查看全部空间的任务'
        })
      } else {
        ForEach(day.tasks, (task: LearningTask) => {
          this.taskCard(task)
        }, (task: LearningTask) => task.taskId)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      if (this.timeline === null) {
        Column() {
          Text('加载中...')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.timeline.space === null) {
        Column() {
          EmptyState({
            title: '空间不存在或已过期',
            hint: '该空间可能已被删除或归档，请返回安排总览重新选择。',
            actionText: '返回安排总览',
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
          Column({ space: 14 }) {
            this.headerCard()
            this.weekStrip(this.timeline.days)
            if (this.timeline.hasSnapshot) {
              this.undoCard()
            }
            this.dayContent(this.selectedDay()!)
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
    .title('空间学习时间轴')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => {
      this.pathStack = ctx.pathStack;
      const param = ctx.pathInfo.param;
      if (typeof param === 'string' && param !== '') {
        this.spaceId = param;
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
export function timelineBuilder() {
  TimelinePage()
}
