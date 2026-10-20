import { SpaceHomePage } from './SpaceHomePage';
import { MinePage } from './MinePage';
import { MapPlaceholderPanel } from './PlaceholderPages';

@Entry
@Component
struct Index {
  pathStack: NavPathStack = new NavPathStack();
  @State currentTab: number = 0;

  @Builder
  tabBarBuilder(title: string, tabIndex: number) {
    Column({ space: 3 }) {
      Divider()
        .color($r('app.color.divider'))
        .width('100%')
      Text(title)
        .fontSize(13)
        .fontWeight(this.currentTab === tabIndex ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === tabIndex ? $r('app.color.brand') : $r('app.color.text_secondary'))
        .padding({ top: 8, bottom: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentTab = tabIndex;
    })
  }

  build() {
    Navigation(this.pathStack) {
      Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
        TabContent() {
          SpaceHomePage({
            pathStack: this.pathStack,
            onSwitchTab: (tabIndex: number) => {
              this.currentTab = tabIndex;
            }
          })
        }
        .tabBar(this.tabBarBuilder('首页', 0))

        TabContent() {
          MapPlaceholderPanel()
        }
        .tabBar(this.tabBarBuilder('地图', 1))

        TabContent() {
          MinePage({ pathStack: this.pathStack })
        }
        .tabBar(this.tabBarBuilder('我的', 2))
      }
      .scrollable(false)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.currentTab = index;
      })
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_page'))
  }
}
