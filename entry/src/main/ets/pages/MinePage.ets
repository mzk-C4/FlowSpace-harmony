import { UserStats, formatMinutes } from '../model/Models';
import { MockService } from '../service/MockService';

@Component
export struct MinePage {
  pathStack: NavPathStack = new NavPathStack();
  @State stats: UserStats | null = null;

  aboutToAppear(): void {
    MockService.getUserStats().then((stats: UserStats) => {
      this.stats = stats;
    });
  }

  @Builder
  statBlock(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  entryRow(title: string, hint: string, routeName: string) {
    Row() {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(hint)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.pathStack.pushPathByName(routeName, '');
    })
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row({ space: 14 }) {
          Column() {
            Text('学')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.on_brand'))
          }
          .width(56)
          .height(56)
          .borderRadius(28)
          .backgroundColor($r('app.color.brand'))
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          Column({ space: 4 }) {
            Text('学习者')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('FlowSpace 学习工作台')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: 14 }) {
          Text('学习概况')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          if (this.stats === null) {
            Text('加载中...')
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
          } else {
            Row({ space: 8 }) {
              this.statBlock(this.stats.streakDays + ' 天', '连续学习')
              this.statBlock(formatMinutes(this.stats.weekLearnMinutes), '本周学习')
            }
            .width('100%')
            Row({ space: 8 }) {
              this.statBlock(this.stats.completedTaskCount + '/' + this.stats.totalTaskCount, '完成任务')
              this.statBlock(formatMinutes(this.stats.totalLearnMinutes), '累计学习')
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor($r('app.color.bg_card'))
        .alignItems(HorizontalAlign.Start)

        Column() {
          this.entryRow('学习记录', '按节点或空间回看作答与解释', 'learningRecords')
          Divider()
            .color($r('app.color.divider'))
          this.entryRow('复习清单', '主动加入的疑问与练习', 'reviewList')
          Divider()
            .color($r('app.color.divider'))
          this.entryRow('偏好设置', '外观、动效与学习时长', 'settings')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor($r('app.color.bg_card'))

        Text('数字来自统一 Mock 数据，后续接入统一 service 层')
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
      }
      .padding({ left: 16, right: 16, top: 24, bottom: 24 })
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
