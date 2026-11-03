# 赵紫石：首页交付

## 已实施

- `entry/src/main/ets/ui/HomePage.ets`：独立 `@ComponentV2`，合同要求的两个 `@Param` 和四个 `@Event` 均完整保留，无 Entry、Navigation 或重复底栏。只维护本地表单、筛选和详情展开状态，不修改传入文档。
- 自然语言 / 长文两种输入模式，共享草稿，最大 20,000 字；长度反馈、清空、三组可编辑示例。空白输入与 busy 状态禁用生成，提交再次 trim 并检查长度，提交前通过 UIContext FocusController 释放输入焦点。
- 文档按更新时间降序副本排序，最多显示三项，提供节点数、更新日期、打开回调和新建回调；初次使用展示真实空态。
- 8 项课程视频集合，覆盖数学基础、算法、电路、信号、控制；横向类别筛选、逐项详情、官方入口、来源 / 语言 / 许可展示。使用 List + LazyForEach + IDataSource / DataChangeListener 和 cachedCount(3)。
- 暖白、石墨与蓝紫均通过合同中的 `fs_*` 颜色资源引用；系统 Button 保留触摸反馈，按钮最小 44vp，长文字按钮按内容增高。页面纵向滚动，长文编辑区内部滚动。无装饰动效。
- `entry/src/main/ets/data/VideoCatalog.ets`：仅导出共享 `LearningResource[]`；官方链接与来源证据见 [videos.md](videos.md)。

## 已做验证

1. 已读取完整 CONTRACT、arkts-syntax、arkui-patterns、emil-design-eng；UI skills 路由选择已存在的 emil-design-eng，无额外框架依赖。
2. 根 build-profile 实际锁定 compatible / target `6.1.1(24)`。SDK 包版本 `6.1.1.125`，apiVersion `24`。
3. 本机真实 SDK 接口签名核验：
   - `ets/component/text_area.d.ts`：onChange(EditableTextOnChangeCallback)、maxLength(number)、showCounter 等真实声明；实际实现采用 onChange 与 maxLength。
   - `ets/component/list.d.ts`：scrollBar(BarState)、cachedCount(number)。
   - `ets/component/lazy_for_each.d.ts`：IDataSource.totalCount/getData/registerDataChangeListener/unregisterDataChangeListener；通知使用 DataChangeListener.onDataReloaded。
   - `ets/api/@ohos.arkui.UIContext.d.ts`：getFocusController(): FocusController、clearFocus(): void。
4. 使用 SDK 自带 TypeScript 4.9.5 ETS parser（ScriptKind.ETS），读取 SDK 的 tsconfig `compilerOptions.ets` 以启用 ArkUI Builder 语法后，两份新增 .ets 的 parseDiagnostics 均为 0。最初未载入 SDK ETS 选项的裸解析会把 UI DSL 误判为普通 TS，修正解析选项后无语法诊断；这不是 UI 修改或完整编译结果。
5. 通过 SDK transpileModule 加载 VideoCatalog 并执行断言：8 项、8 个不同 ID、5 个要求类别、每项 10 个非空共享字段、官方 ocw.mit.edu HTTPS URL。通过。
6. 静态自查：无 any/unknown、无解构/对象展开、无 V1 状态、无直接 HTTP、无伪造文档、无公共配置变更。最近文档排序操作副本。

## 集成与未做项

主对话统一完成 SDK 构建、资源合并、onGenerate/onNewMap/onOpenDocument/onOpenResource 接线和后端联调。本模块未运行全工程构建，未执行设备或模拟器测试，未验证真实 AI 请求，也未确认实体设备网络的视频播放。键盘弹出后的可见区域、系统字号放大和深色主题仍需主入口统一避让策略与设备验收。页面没有新增窗口级全局键盘配置。

未修改公共入口、颜色定义、构建配置、他人模块；未提交或切换 Git。
