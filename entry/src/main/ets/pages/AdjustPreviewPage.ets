import { EmptyState } from '../components/EmptyState';
import { SectionTitle } from '../components/SectionTitle';
import { StatusTag } from '../components/StatusTag';
import {
  ActionResult,
  PlanAdjustItem,
  PlanAdjustPreview
} from '../model/Models';
import { MockService } from '../service/MockService';

interface TargetDayOption {
  date: string;
  label: string;
}

const TARGET_OPTIONS: TargetDayOption[] = [
  { date: '2026-10-22', label: '周四' },
  { date: '2026-10-23', label: '周五' }
];

@Component
export struct AdjustPreviewPage {
  pathStack: NavPathStack = new NavPathStack();
  taskId: string = '';
  @State targetDate: string = '2026-10-22';
  @State preview: PlanAdjustPreview | null = null;
  @State loading: boolean = true;
  @State actionError: string = '';

  private load(): void {
    this.loading = true;
    MockService.createAdjustPreview(this.taskId, this.targetDate).then((data: PlanAdjustPreview | null) => {
      this.preview = data;
      this.loading = false;
    });
  }

  private selectTarget(option: TargetDayOption): void {
    if (this.targetDate === option.date) {
      return;
    }
    this.targetDate = option.date;
    this.actionError = '';
    this.load();
  }

  private confirm(): void {
    if (this.preview === null) {
      return;
    }
    MockService.confirmAdjust(this.preview.previewId).then((result: ActionResult) => {
      if (result.ok) {
        this.getUIContext().getPromptAction().showToast({ message: result.message });
        this.pathStack.pop();
      } else {
        this.actionError = result.message;
        this.load();
      }
    });
  }

  @Builder
  headerCard(preview: PlanAdjustPreview) {
    Column({ space: 10 }) {
      Text('调整预览')
        .fontSize(12)
        .fontColor($r('app.color.brand'))
        .backgroundColor($r('app.color.brand_weak'))
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(10)
      Text(preview.reason)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('任务：' + preview.taskTitle)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))

      Row({ space: 8 }) {
        Text('调整到')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        ForEach(TARGET_OPTIONS, (option: TargetDayOption) => {
          Text(option.label)
            .fontSize(12)
            .fontColor(this.targetDate === option.date ?
              $r('app.color.on_brand') : $r('app.color.text_secondary'))
            .backgroundColor(this.targetDate === option.date ?
              $r('app.color.brand') : $r('app.color.bg_page'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(999)
            .onClick(() => {
              this.selectTarget(option);
            })
        }, (option: TargetDayOption) => option.date)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('只有确认后才写入正式计划；取消不会改动任何安排。')
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  compareRow(label: string, before: number, after: number, limit: number) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width(48)
      Text(before + ' 分钟')
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
      Text('→')
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
      Text(after + ' 分钟')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand'))
      Blank()
      Text(after <= limit ? '在上限内' : '超出上限')
        .fontSize(10)
        .fontColor(after <= limit ? $r('app.color.tag_green_text') : $r('app.color.tag_orange_text'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  compareCard(preview: PlanAdjustPreview) {
    Column({ space: 10 }) {
      Text('每日时长对比')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      this.compareRow('今天', preview.beforeDailyMinutes, preview.afterDailyMinutes, preview.dailyLimitMinutes)
      this.compareRow(preview.targetDayLabel, preview.beforeTargetDailyMinutes,
        preview.afterTargetDailyMinutes, preview.dailyLimitMinutes)
      Divider()
        .color($r('app.color.divider'))
      Text('总量保持：' + (preview.taskDurationMinutes - preview.reduceMinutes) + ' + ' +
        preview.reduceMinutes + ' = ' + preview.taskDurationMinutes + ' 分钟')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand'))
      Text('若原任务含 10 分钟检查，会拆成今天 5 分钟 + ' + preview.targetDayLabel + ' 5 分钟，避免总量增加。')
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
  itemCard(item: PlanAdjustItem) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        StatusTag({ label: item.action, kind: item.action === '新增' ? 'blue' : 'orange' })
        Text(item.title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(item.beforeTimeRange + ' → ' + item.afterTimeRange)
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
      Text(item.beforeMinutes + ' 分钟 → ' + item.afterMinutes + ' 分钟')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
      Text(item.detail)
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  checkCard(preview: PlanAdjustPreview) {
    Column({ space: 8 }) {
      if (preview.errors.length > 0) {
        Text('发现冲突，暂不能确认')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.tag_orange_text'))
        ForEach(preview.errors, (error: string) => {
          Text('· ' + error)
            .fontSize(11)
            .fontColor($r('app.color.tag_orange_text'))
        }, (error: string) => error)
        Text('可以改到另一个日期，或先取消并手动调整其他任务。')
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
      } else {
        Text('冲突检查通过')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.tag_green_text'))
        Text('已检查所有空间的已有任务、每日时长上限和生活保留时间。')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
        ForEach(preview.warnings, (warning: string) => {
          Text('· ' + warning)
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        }, (warning: string) => warning)
      }
      if (this.actionError !== '') {
        Text(this.actionError)
          .fontSize(11)
          .fontColor($r('app.color.tag_orange_text'))
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor(preview.errors.length > 0 ?
      $r('app.color.tag_orange_bg') : $r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      if (this.loading) {
        Column() {
          Text('正在生成调整预览...')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.preview === null) {
        Column() {
          EmptyState({
            title: '任务不存在或已过期',
            hint: '无法生成调整预览，请返回后重新选择任务。',
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
            this.headerCard(this.preview!)
            this.compareCard(this.preview!)
            SectionTitle({ title: '调整内容' })
            ForEach(this.preview!.items, (item: PlanAdjustItem) => {
              this.itemCard(item)
            }, (item: PlanAdjustItem) => item.itemId)
            this.checkCard(this.preview!)
            Row({ space: 10 }) {
              Button('取消，不改动')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor($r('app.color.bg_card'))
                .height(42)
                .layoutWeight(1)
                .borderRadius(10)
                .onClick(() => {
                  this.pathStack.pop();
                })
              Button('确认调整')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.on_brand'))
                .backgroundColor($r('app.color.brand'))
                .height(42)
                .layoutWeight(1)
                .borderRadius(10)
                .enabled(this.preview!.errors.length === 0)
                .onClick(() => {
                  this.confirm();
                })
            }
            .width('100%')
            Text('确认后，首页今日安排、安排总览和时间轴会同步；可在时间轴撤销。')
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
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
    .title('计划调整预览')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => {
      this.pathStack = ctx.pathStack;
      const param = ctx.pathInfo.param;
      if (typeof param === 'string' && param !== '') {
        this.taskId = param;
      }
      this.load();
    })
  }
}

@Builder
export function adjustPreviewBuilder() {
  AdjustPreviewPage()
}
