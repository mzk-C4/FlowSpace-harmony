// Preview-only host for the actual LibraryPage. No database, model, or copied catalog.
// Copy to pages/LibraryPreview.ets in an isolated preview project; never add to release routes.
import { LibraryPage } from '../ui/LibraryPage';
import { LearningResource } from '../domain/MindMap';
import { appSymbol } from '../ui/Controls';

@Entry
@ComponentV2
struct LibraryPreview {
  @Local tab: number = 2;
  @Local errorMessage: string = '';
  @Local failedId: string = '';

  @Builder
  tabLabel(label: string, glyph: Resource, index: number) {
    Column({ space: 3 }) {
      appSymbol(glyph, 22, this.tab === index ? $r('app.color.fs_accent') : $r('app.color.fs_muted'))
      Text(label).fontSize(12).fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Regular).fontColor(this.tab === index ? $r('app.color.fs_accent') : $r('app.color.fs_muted'))
    }.height('100%').width('100%').justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.tab }) {
        TabContent() { Column() {} }.tabBar(this.tabLabel('首页', $r('sys.symbol.house'), 0))
        TabContent() { Column() {} }.tabBar(this.tabLabel('DIY 导图', $r('sys.symbol.rectangle_3_group'), 1))
        TabContent() {
          LibraryPage({ externalOpenError: this.errorMessage, failedResourceId: this.failedId,
            onOpenResource: (resource: LearningResource) => {
              this.failedId = resource.id;
              this.errorMessage = '预览环境不启动外部浏览器，请在手机上验证原站访问。';
            },
            onUseTopic: (text: string) => {
              this.getUIContext().getPromptAction().showToast({ message: '已收到主题提示，预览不调用 AI。' });
            } })
        }.tabBar(this.tabLabel('资料库', $r('sys.symbol.book_pages'), 2))
        TabContent() { Column() {} }.tabBar(this.tabLabel('个人', $r('sys.symbol.person'), 3))
      }.barMode(BarMode.Fixed).barHeight(60).barBackgroundColor($r('app.color.fs_surface'))
        .divider({ strokeWidth: 0.5, color: $r('app.color.fs_border') }).scrollable(false)
        .width('100%').height('100%').onChange((index: number) => { this.tab = index; })
    }.width('100%').height('100%').backgroundColor($r('app.color.fs_bg'))
  }
}
