import { SectionTitle } from '../components/SectionTitle';
import { SpaceCard } from '../components/SpaceCard';
import { StatusTag } from '../components/StatusTag';
import { EmptyState } from '../components/EmptyState';
import { SpaceInfo, SpaceListResult, TodayTask, formatLearnedAt, taskStatusKind, taskStatusText } from '../model/Models';
import { MockService } from '../service/MockService';

@Component
export struct SpaceHomePage {
  pathStack: NavPathStack = new NavPathStack();
  onSwitchTab: (tabIndex: number) => void = (tabIndex: number) => {};
  @State recentSpace: SpaceInfo | null = null;
  @State spaces: SpaceInfo[] = [];
  @State todayTasks: TodayTask[] = [];

  aboutToAppear(): void {
    MockService.getRecentSpace().then((space: SpaceInfo | null) => {
      this.recentSpace = space;
    });
    MockService.getSpacesFiltered('', false).then((list: SpaceInfo[]) => {
      this.spaces = list;
    });
    MockService.getTodayTasks().then((list: TodayTask[]) => {
      this.todayTasks = list;
    });
  }

  private openSpaceList(): void {
    this.pathStack.pushPathByName('spaceList', '', (popInfo: PopInfo) => {
      if (popInfo.result === undefined || popInfo.result === null) {
        return;
      }
      const result = popInfo.result as SpaceListResult;
      if (result.openMap) {
        this.onSwitchTab(1);
      }
    });
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Column({ space: 4 }) {
            Text('FlowSpace')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('10月18日 · 周日')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('设置')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.bg_card'))
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(999)
            .onClick(() => {
              this.pathStack.pushPathByName('settings', '');
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        SectionTitle({ title: '最近学习' })
        if (this.recentSpace === null) {
          EmptyState({ title: '还没有学习记录', hint: '新建一个学习空间开始吧' })
        } else {
          Column({ space: 12 }) {
            Row({ space: 10 }) {
              Text('继续学习')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.brand'))
                .backgroundColor($r('app.color.brand_weak'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(10)
              Text(formatLearnedAt(this.recentSpace.lastLearnedAt))
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')

            Text(this.recentSpace.name)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            Text('上次学到：' + this.recentSpace.lastNodeName)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))

            Row({ space: 12 }) {
              Button('继续学习')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.on_brand'))
                .backgroundColor($r('app.color.brand'))
                .height(38)
                .layoutWeight(1)
                .onClick(() => {
                  this.onSwitchTab(1);
                })
              Button('查看空间')
                .fontSize(14)
                .fontColor($r('app.color.brand'))
                .backgroundColor($r('app.color.brand_weak'))
                .height(38)
                .layoutWeight(1)
                .onClick(() => {
                  this.openSpaceList();
                })
            }
            .width('100%')
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('app.color.brand_weak'))
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        SectionTitle({
          title: '我的空间',
          actionText: '全部 >',
          onAction: () => {
            this.openSpaceList();
          }
        })
        Scroll() {
          Row({ space: 12 }) {
            ForEach(this.spaces, (space: SpaceInfo) => {
              SpaceCard({
                space: space,
                compact: true,
                onOpen: (spaceId: string) => {
                  this.onSwitchTab(1);
                }
              })
                .width(200)
            }, (space: SpaceInfo) => space.spaceId)

            Column({ space: 8 }) {
              Text('+')
                .fontSize(24)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.brand'))
              Text('新建学习空间')
                .fontSize(12)
                .fontColor($r('app.color.brand'))
                .textAlign(TextAlign.Center)
            }
            .width(110)
            .padding({ top: 20, bottom: 20, left: 10, right: 10 })
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.divider'), style: BorderStyle.Dashed })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.pathStack.pushPathByName('createSpace', '');
            })
          }
          .width('100%')
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        SectionTitle({
          title: '今日安排',
          actionText: '安排总览 >',
          onAction: () => {
            this.pathStack.pushPathByName('scheduleOverview', '');
          }
        })
        Column({ space: 10 }) {
          ForEach(this.todayTasks, (task: TodayTask) => {
            Row({ space: 12 }) {
              Column({ space: 2 }) {
                Text(task.timeRange.substring(0, 5))
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text(task.durationMinutes + '分钟')
                  .fontSize(11)
                  .fontColor($r('app.color.text_tertiary'))
              }
              .alignItems(HorizontalAlign.Start)

              Column({ space: 4 }) {
                Text(task.title)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(task.spaceName + ' · 产出：' + task.output)
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              StatusTag({ label: taskStatusText(task.status), kind: taskStatusKind(task.status) })
            }
            .width('100%')
            .padding(14)
            .borderRadius(16)
            .backgroundColor($r('app.color.bg_card'))
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.pathStack.pushPathByName('taskDetail', task.taskId);
            })
          }, (task: TodayTask) => task.taskId)

          if (this.todayTasks.length === 0) {
            EmptyState({ title: '今天没有安排', hint: '去安排总览制定今天的计划' })
          }
        }
        .width('100%')
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
}
