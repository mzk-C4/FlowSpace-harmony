import { EmptyState } from '../components/EmptyState';
import { SectionTitle } from '../components/SectionTitle';
import { ProjectLink } from '../model/Models';
import { MockService } from '../service/MockService';

interface ProjectSpaceFilter {
  spaceId: string;
  name: string;
}

@Component
export struct KnowledgeProjectPage {
  pathStack: NavPathStack = new NavPathStack();
  @State spaceFilter: string = '';
  @State links: ProjectLink[] = [];
  @State expandedId: string = '';
  @State loaded: boolean = false;

  private load(): void {
    MockService.getProjectLinks('').then((list: ProjectLink[]) => {
      this.links = list;
      this.loaded = true;
    });
  }

  private filters(): ProjectSpaceFilter[] {
    const result: ProjectSpaceFilter[] = [{ spaceId: '', name: '全部' }];
    for (let i = 0; i < this.links.length; i++) {
      let exists = false;
      for (let j = 0; j < result.length; j++) {
        if (result[j].spaceId === this.links[i].spaceId) {
          exists = true;
        }
      }
      if (!exists) {
        result.push({ spaceId: this.links[i].spaceId, name: this.links[i].spaceName });
      }
    }
    return result;
  }

  private filteredLinks(): ProjectLink[] {
    if (this.spaceFilter === '') {
      return this.links;
    }
    const result: ProjectLink[] = [];
    for (let i = 0; i < this.links.length; i++) {
      if (this.links[i].spaceId === this.spaceFilter) {
        result.push(this.links[i]);
      }
    }
    return result;
  }

  private toggleLink(linkId: string): void {
    this.expandedId = this.expandedId === linkId ? '' : linkId;
  }

  @Builder
  headerCard() {
    Column({ space: 7 }) {
      Text('知识关联项目')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('按“知识 → 项目功能”查看：这条知识用在了项目的哪个功能里，怎么实现，原始资料与练习在哪里。')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
      Text('原始资料、样例补充与个人练习分别标注来源，便于课程成果讲述。')
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
  linkCard(link: ProjectLink) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(link.nodeName)
          .fontSize(12)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_weak'))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .borderRadius(9)
        Text('→')
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
        Text(link.featureName)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(link.spaceName)
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
      Text(link.featureDesc)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      Text(this.expandedId === link.linkId ? '收起说明' : '展开实现说明与资料 ›')
        .fontSize(11)
        .fontColor($r('app.color.brand'))

      if (this.expandedId === link.linkId) {
        Divider()
          .color($r('app.color.divider'))
          .margin({ top: 2, bottom: 2 })

        Column({ space: 4 }) {
          Text('实现说明')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(link.implementation)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('原始资料')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(link.materialTitle)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(link.materialBody)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
          Text('来源：' + link.materialSource)
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(10)
        .borderRadius(9)
        .backgroundColor($r('app.color.bg_page'))

        Column({ space: 4 }) {
          Text('关联练习')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(link.practice)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.toggleLink(link.linkId);
    })
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
      } else {
        Scroll() {
          Column({ space: 12 }) {
            this.headerCard()

            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.filters(), (filter: ProjectSpaceFilter) => {
                  Text(filter.name)
                    .fontSize(12)
                    .fontColor(this.spaceFilter === filter.spaceId ?
                      $r('app.color.on_brand') : $r('app.color.text_secondary'))
                    .backgroundColor(this.spaceFilter === filter.spaceId ?
                      $r('app.color.brand') : $r('app.color.bg_card'))
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .borderRadius(999)
                    .onClick(() => {
                      this.spaceFilter = filter.spaceId;
                      this.expandedId = '';
                    })
                }, (filter: ProjectSpaceFilter) => filter.spaceId)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')

            SectionTitle({ title: '知识 → 功能' })
            if (this.filteredLinks().length === 0) {
              EmptyState({
                title: '没有关联项目',
                hint: '这个空间的知识还没有连接到项目功能',
                actionText: '查看全部',
                onAction: () => {
                  this.spaceFilter = '';
                }
              })
            } else {
              ForEach(this.filteredLinks(), (link: ProjectLink) => {
                this.linkCard(link)
              }, (link: ProjectLink) => link.linkId)
            }
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
    .title('知识关联项目')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => {
      this.pathStack = ctx.pathStack;
      const param = ctx.pathInfo.param;
      if (typeof param === 'string') {
        this.spaceFilter = param;
      }
      this.load();
    })
  }
}

@Builder
export function knowledgeProjectsBuilder() {
  KnowledgeProjectPage()
}
