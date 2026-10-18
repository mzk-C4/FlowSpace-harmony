import { EmptyState } from '../components/EmptyState';
import { SpaceCard } from '../components/SpaceCard';
import { SpaceInfo, SpaceListResult } from '../model/Models';
import { MockService } from '../service/MockService';

@Component
export struct SpaceListPage {
  pathStack: NavPathStack = new NavPathStack();
  @State spaces: SpaceInfo[] = [];
  @State keyword: string = '';
  @State showArchived: boolean = false;
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.loading = true;
    MockService.getSpacesFiltered(this.keyword, this.showArchived).then((list: SpaceInfo[]) => {
      this.spaces = list;
      this.loading = false;
    });
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        TextInput({ placeholder: '搜索空间名称或目标', text: this.keyword })
          .placeholderColor($r('app.color.text_tertiary'))
          .placeholderFont({ size: 14 })
          .fontColor($r('app.color.text_primary'))
          .fontSize(14)
          .backgroundColor($r('app.color.bg_card'))
          .borderRadius(12)
          .caretColor($r('app.color.brand'))
          .height(42)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.keyword = value;
            this.reload();
          })

        Row({ space: 8 }) {
          Text(this.showArchived ? '已含归档空间' : '显示归档空间')
            .fontSize(12)
            .fontColor(this.showArchived ? $r('app.color.on_brand') : $r('app.color.text_secondary'))
            .backgroundColor(this.showArchived ? $r('app.color.brand') : $r('app.color.bg_card'))
            .borderRadius(999)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => {
              this.showArchived = !this.showArchived;
              this.reload();
            })
          Blank()
          Text(this.spaces.length + ' 个空间')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.spaces, (space: SpaceInfo) => {
              SpaceCard({
                space: space,
                showActions: true,
                onOpen: (spaceId: string) => {
                  const result: SpaceListResult = { openMap: true, spaceId: spaceId };
                  this.pathStack.pop(result);
                },
                onArchive: (spaceId: string, archived: boolean) => {
                  MockService.archiveSpace(spaceId, archived).then((ok: boolean) => {
                    if (ok) {
                      this.getUIContext().getPromptAction().showToast({
                        message: archived ? '已归档' : '已恢复'
                      });
                      this.reload();
                    }
                  });
                }
              })
            }, (space: SpaceInfo) => space.spaceId + (space.isArchived ? '_a' : ''))

            if (this.loading) {
              Text('加载中...')
                .fontSize(12)
                .fontColor($r('app.color.text_tertiary'))
                .padding({ top: 20, bottom: 20 })
            } else {
              if (this.spaces.length === 0) {
                EmptyState({
                  title: this.showArchived ? '没有找到空间' : '未找到相关空间',
                  hint: this.showArchived ? '调整关键词或新建一个学习空间' : '换个关键词试试，或查看归档空间',
                  actionText: '清空搜索',
                  onAction: () => {
                    this.keyword = '';
                    this.reload();
                  }
                })
              }
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
        .width('100%')
      }
      .padding({ left: 16, right: 16, top: 12 })
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .alignItems(HorizontalAlign.Start)
    }
    .title('全部学习空间')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => {
      this.pathStack = ctx.pathStack;
    })
  }
}

@Builder
export function spaceListBuilder() {
  SpaceListPage()
}
