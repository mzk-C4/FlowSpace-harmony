import { EmptyState } from '../components/EmptyState';
import { SectionTitle } from '../components/SectionTitle';
import { StatusTag } from '../components/StatusTag';
import {
  DayPlan,
  LearningTask,
  LifeReservedBlock,
  ScheduleOverview,
  SpaceScheduleSummary,
  formatMinutes,
  formatDateLabel,
  shortDateLabel,
  taskStatusKind,
  taskStatusText
} from '../model/Models';
import { MockService } from '../service/MockService';

@Component
export struct ScheduleOverviewPage {
  pathStack: NavPathStack = new NavPathStack();
  @State overview: ScheduleOverview | null = null;
  @State selectedDayIndex: number = 0;
  private shownOnce: boolean = false;

  private load(): void {
    MockService.getScheduleOverview().then((data: ScheduleOverview) => {
      this.overview = data;
      if (this.selectedDayIndex >= data.days.length) {
        this.selectedDayIndex = 0;
      }
    });
  }

  private selectedDay(): DayPlan | null {
    if (this.overview === null) {
      return null;
    }
    if (this.selectedDayIndex < 0 || this.selectedDayIndex >= this.overview.days.length) {
      return null;
    }
    return this.overview.days[this.selectedDayIndex];
  }

  private openTimeline(spaceId: string): void {
    this.pathStack.pushPathByName('timeline', spaceId);
  }

  private openTask(taskId: string): void {
    this.pathStack.pushPathByName('taskDetail', taskId);
  }

  @Builder
  summaryCard() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('安排总览')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(formatDateLabel(this.overview!.days[0].date) + ' · ' +
            this.overview!.days[0].weekday + ' · 所有空间')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('计划 v' + this.overview!.planVersion)
          .fontSize(11)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_weak'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(10)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        this.summaryStat('今日学习', formatMinutes(this.overview!.todayStudyMinutes))
        this.summaryStat('生活保留', formatMinutes(this.overview!.todayReservedMinutes))
        this.summaryStat('每日上限', this.overview!.dailyLimitMinutes + ' 分钟')
      }
      .width('100%')

      if (this.overview!.todayStudyMinutes > this.overview!.dailyLimitMinutes) {
        Text('今天已超过每日上限，请调整任务或改到其他日期')
          .fontSize(11)
          .fontColor($r('app.color.tag_orange_text'))
          .backgroundColor($r('app.color.tag_orange_bg'))
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
          .borderRadius(8)
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  summaryStat(label: string, value: string) {
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
  quickLinks() {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text('复习清单')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text('主动加入的疑问与练习，不会自动排期')
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding(12)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))
      .onClick(() => {
        this.pathStack.pushPathByName('reviewList', '');
      })

      Column({ space: 4 }) {
        Text('知识关联项目')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text('把学过的知识连到项目功能')
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding(12)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))
      .onClick(() => {
        this.pathStack.pushPathByName('knowledgeProjects', '');
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
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
          }
          .width(58)
          .padding({ top: 9, bottom: 9 })
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
  spaceCard(summary: SpaceScheduleSummary) {
    Row({ space: 12 }) {
      Column()
        .width(10)
        .height(10)
        .borderRadius(5)
        .backgroundColor(summary.coverColor)

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(summary.spaceName)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          if (summary.todayTaskCount > 0) {
            StatusTag({ label: '今日 ' + summary.todayTaskCount + ' 项', kind: 'blue' })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text('本周 ' + summary.weekTaskCount + ' 项 · ' + formatMinutes(summary.weekMinutes))
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))

        if (summary.nextTaskTitle === '') {
          Text('本周暂无待开始任务')
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        } else {
          Text('下一项：' + summary.nextTaskTitle + ' · ' + summary.nextTaskLabel)
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('时间轴 ›')
        .fontSize(12)
        .fontColor($r('app.color.brand'))
        .padding({ left: 4, top: 4, bottom: 4 })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openTimeline(summary.spaceId);
    })
  }

  @Builder
  lifeRow(block: LifeReservedBlock) {
    Row({ space: 8 }) {
      Text(block.label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      Text(block.timeRange)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      StatusTag({ label: '保留', kind: 'orange' })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .borderRadius(10)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  taskRow(task: LearningTask) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(task.timeRange.substring(0, 5))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(formatMinutes(task.durationMinutes))
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width(48)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 3 }) {
        Text(task.title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(task.spaceName + ' · 产出：' + task.output)
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      StatusTag({ label: taskStatusText(task.status), kind: taskStatusKind(task.status) })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openTask(task.taskId);
    })
  }

  @Builder
  dayContent(day: DayPlan) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(formatDateLabel(day.date) + ' · ' + day.weekday)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('学习 ' + formatMinutes(day.totalMinutes) + ' · 保留 ' + formatMinutes(day.reservedMinutes))
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      SectionTitle({ title: '生活保留时间' })
      ForEach(day.lifeBlocks, (block: LifeReservedBlock) => {
        this.lifeRow(block)
      }, (block: LifeReservedBlock) => block.blockId)

      SectionTitle({ title: '当日任务' })
      if (day.tasks.length === 0) {
        EmptyState({ title: '这一天没有任务', hint: '选择其他日期，或从空间时间轴开始安排' })
      } else {
        ForEach(day.tasks, (task: LearningTask) => {
          this.taskRow(task)
        }, (task: LearningTask) => task.taskId)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      if (this.overview === null) {
        Column() {
          Text('加载中...')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            this.summaryCard()
            this.quickLinks()
            this.weekStrip(this.overview.days)
            SectionTitle({ title: '各空间安排' })
            ForEach(this.overview.spaceSummaries, (summary: SpaceScheduleSummary) => {
              this.spaceCard(summary)
            }, (summary: SpaceScheduleSummary) => summary.spaceId)
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
    .title('安排总览')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => {
      this.pathStack = ctx.pathStack;
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
export function scheduleOverviewBuilder() {
  ScheduleOverviewPage()
}
