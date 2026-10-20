import { ConfigurationConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeModeOption, UserSettings, formatMinutes } from '../model/Models';
import { MockService } from '../service/MockService';

interface ThemeOptionItem {
  label: string;
  value: ThemeModeOption;
}

const THEME_OPTIONS: ThemeOptionItem[] = [
  { label: '跟随系统', value: ThemeModeOption.FollowSystem },
  { label: '浅色', value: ThemeModeOption.Light },
  { label: '深色', value: ThemeModeOption.Dark }
];

@Component
export struct SettingsPage {
  @State settings: UserSettings = {
    themeMode: ThemeModeOption.FollowSystem,
    reduceMotion: false,
    dailyTargetMinutes: 120,
    focusMinutes: 45,
    restMinutes: 10
  };
  @State loaded: boolean = false;

  aboutToAppear(): void {
    MockService.getSettings().then((settings: UserSettings) => {
      this.settings = settings;
      this.loaded = true;
    });
  }

  private applyThemeMode(mode: ThemeModeOption): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || context === null) {
      return;
    }
    let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (mode === ThemeModeOption.Light) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    if (mode === ThemeModeOption.Dark) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    try {
      context.getApplicationContext().setColorMode(colorMode);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, 'SettingsPage', 'setColorMode failed: %{public}s', err.message);
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          if (!this.loaded) {
            Text('加载中...')
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .padding({ top: 24 })
          } else {
            Column({ space: 12 }) {
              Text('外观')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Row({ space: 10 }) {
                ForEach(THEME_OPTIONS, (item: ThemeOptionItem) => {
                  Text(item.label)
                    .fontSize(13)
                    .fontColor(this.settings.themeMode === item.value ?
                      $r('app.color.on_brand') : $r('app.color.text_secondary'))
                    .backgroundColor(this.settings.themeMode === item.value ?
                      $r('app.color.brand') : $r('app.color.brand_weak'))
                    .borderRadius(999)
                    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .onClick(() => {
                      this.settings.themeMode = item.value;
                      this.applyThemeMode(item.value);
                    })
                }, (item: ThemeOptionItem) => item.label)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('app.color.bg_card'))
            .alignItems(HorizontalAlign.Start)

            Column({ space: 12 }) {
              Text('动效')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Row() {
                Column({ space: 3 }) {
                  Text('减少动效')
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                  Text('开启后降低转场与列表动画')
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.settings.reduceMotion })
                  .selectedColor($r('app.color.brand'))
                  .onChange((isOn: boolean) => {
                    this.settings.reduceMotion = isOn;
                  })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('app.color.bg_card'))
            .alignItems(HorizontalAlign.Start)

            Column({ space: 12 }) {
              Text('学习时长')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Column({ space: 6 }) {
                Row() {
                  Text('每日目标时长')
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                  Blank()
                  Text(formatMinutes(this.settings.dailyTargetMinutes))
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.brand'))
                }
                .width('100%')

                Slider({ value: this.settings.dailyTargetMinutes, min: 30, max: 360, step: 15,
                  style: SliderStyle.OutSet })
                  .blockColor($r('app.color.brand'))
                  .selectedColor($r('app.color.brand'))
                  .trackColor($r('app.color.track'))
                  .width('100%')
                  .onChange((value: number) => {
                    this.settings.dailyTargetMinutes = Math.round(value);
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              Column({ space: 6 }) {
                Row() {
                  Text('专注时长')
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                  Blank()
                  Text(formatMinutes(this.settings.focusMinutes))
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.brand'))
                }
                .width('100%')

                Slider({ value: this.settings.focusMinutes, min: 15, max: 60, step: 5,
                  style: SliderStyle.OutSet })
                  .blockColor($r('app.color.brand'))
                  .selectedColor($r('app.color.brand'))
                  .trackColor($r('app.color.track'))
                  .width('100%')
                  .onChange((value: number) => {
                    this.settings.focusMinutes = Math.round(value);
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              Column({ space: 6 }) {
                Row() {
                  Text('休息时长')
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                  Blank()
                  Text(formatMinutes(this.settings.restMinutes))
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.brand'))
                }
                .width('100%')

                Slider({ value: this.settings.restMinutes, min: 5, max: 20, step: 5,
                  style: SliderStyle.OutSet })
                  .blockColor($r('app.color.brand'))
                  .selectedColor($r('app.color.brand'))
                  .trackColor($r('app.color.track'))
                  .width('100%')
                  .onChange((value: number) => {
                    this.settings.restMinutes = Math.round(value);
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('app.color.bg_card'))
            .alignItems(HorizontalAlign.Start)

            Button('保存偏好')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_brand'))
              .backgroundColor($r('app.color.brand'))
              .height(44)
              .width('100%')
              .borderRadius(12)
              .onClick(() => {
                MockService.saveSettings(this.settings).then(() => {
                  this.getUIContext().getPromptAction().showToast({ message: '偏好已保存' });
                });
              })
          }
        }
        .padding({ left: 16, right: 16, top: 14, bottom: 24 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .align(Alignment.TopStart)
    }
    .title('偏好设置')
    .backgroundColor($r('app.color.bg_page'))
  }
}

@Builder
export function settingsBuilder() {
  SettingsPage()
}
