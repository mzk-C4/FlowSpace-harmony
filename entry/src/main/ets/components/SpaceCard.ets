import { SpaceInfo } from '../model/Models';
import { StatusTag } from './StatusTag';

@Component
export struct SpaceCard {
  space: SpaceInfo = {
    spaceId: '',
    name: '',
    goal: '',
    progress: 0,
    nodeCount: 0,
    completedNodeCount: 0,
    lastNodeName: '',
    lastLearnedAt: '',
    isArchived: false,
    coverColor: '#4C5FD5'
  };
  compact: boolean = false;
  showActions: boolean = false;
  onOpen: (spaceId: string) => void = (spaceId: string) => {};
  onArchive: (spaceId: string, archived: boolean) => void = (spaceId: string, archived: boolean) => {};

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Column()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.space.coverColor)
        Text(this.space.name)
          .fontSize(this.compact ? 15 : 16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.space.isArchived) {
          StatusTag({ label: '已归档', kind: 'orange' })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.space.goal)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(this.compact ? 2 : 1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Progress({ value: this.space.progress, total: 100, type: ProgressType.Linear })
        .color(this.space.coverColor)
        .backgroundColor($r('app.color.track'))
        .height(6)
        .borderRadius(3)
        .width('100%')

      Row() {
        Text(this.space.completedNodeCount + '/' + this.space.nodeCount + ' 个知识点')
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
        Blank()
        if (this.compact) {
          Text(this.space.progress + '%')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand'))
        }
      }
      .width('100%')

      if (!this.compact) {
        Divider()
          .color($r('app.color.divider'))
          .margin({ top: 2, bottom: 2 })
        Row() {
          Text('上次学到：' + this.space.lastNodeName)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.showActions) {
            if (this.space.isArchived) {
              Text('恢复')
                .fontSize(12)
                .fontColor($r('app.color.brand'))
                .padding({ left: 8, top: 4, bottom: 4 })
                .onClick(() => {
                  this.onArchive(this.space.spaceId, false);
                })
            } else {
              Text('归档')
                .fontSize(12)
                .fontColor($r('app.color.text_tertiary'))
                .padding({ left: 8, top: 4, bottom: 4 })
                .onClick(() => {
                  this.onArchive(this.space.spaceId, true);
                })
            }
          } else {
            Text(this.space.progress + '%')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand'))
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(16)
    .padding(14)
    .onClick(() => {
      this.onOpen(this.space.spaceId);
    })
    .alignItems(HorizontalAlign.Start)
  }
}
