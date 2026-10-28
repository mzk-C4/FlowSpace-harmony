import { EmptyState } from '../components/EmptyState';

@Component
export struct MapPlaceholderPanel {
  build() {
    Column() {
      EmptyState({
        title: '知识地图建设中',
        hint: '知识地图 / 列表由白长林负责，将在 M1 阶段交付。\n当前页面为导航占位，保证三栏导航可切换。'
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .justifyContent(FlexAlign.Center)
  }
}

@Builder
export function createSpaceBuilder() {
  NavDestination() {
    Column() {
      EmptyState({
        title: '新建学习空间',
        hint: '创建流程（填写→预览→确认）由白长林负责，将在 M2 阶段交付。'
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .justifyContent(FlexAlign.Center)
  }
  .backgroundColor($r('app.color.bg_page'))
  .title('新建学习空间')
}

@Builder
export function learningRecordsBuilder() {
  NavDestination() {
    Column() {
      EmptyState({
        title: '学习记录',
        hint: '学习记录 / 记录详情由陈珂睿负责，将在 M3（P1）阶段交付。'
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .justifyContent(FlexAlign.Center)
  }
  .backgroundColor($r('app.color.bg_page'))
  .title('学习记录')
}
