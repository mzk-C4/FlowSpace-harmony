# 赵紫石：首页交付

## 已实施

- `entry/src/main/ets/ui/HomePage.ets`：独立 `@ComponentV2`，合同要求的两个 `@Param` 和四个 `@Event` 均完整保留，无 Entry、Navigation 或重复底栏。只维护本地表单、筛选和详情展开状态，不修改传入文档。
- 自然语言 / 长文两种输入模式，共享草稿，最大 20,000 字；长度反馈、清空、三组可编辑示例。空白输入与 busy 状态禁用生成，提交再次 trim 并检查长度，提交前通过 UIContext FocusController 释放输入焦点。
- 文档按更新时间降序副本排序，最多显示三项，提供节点数、更新日期、打开回调和新建回调；初次使用展示真实空态。
- 8 项课程视频集合，覆盖数学基础、算法、电路、信号、控制；横向类别筛选、逐项详情、官方入口、来源 / 语言 / 许可展示。使用 List + LazyForEach + IDataSource / DataChangeListener 和 cachedCount(3)。
- 暖白、石墨与蓝紫均通过合同中的 `fs_*` 颜色资源引用；系统 Button 保留触摸反馈，按钮最小 44vp，长文字按钮按内容增高。页面纵向滚动，长文编辑区内部滚动。无装饰动效。
- `entry/src/main/ets/data/VideoCatalog.ets`：`VIDEO_RESOURCES` 保持原有的 `LearningResource[]` 字段不变；2026-11-24 追加 `VIDEO_CATEGORIES`、`findVideos()` 与 `VIDEO_VERIFICATION`（机构 / 主讲 / 访问条件 / 适合内容 / 核验日期）。官方链接与来源证据见 [videos.md](videos.md)。

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

## 2026-11-24 第二轮补强（分支 `feature/home-zhaozishi-20261124`）

### 本轮改动

1. `data/VideoCatalog.ets`：新增 `VIDEO_CATEGORIES`（全部 + 数学基础 / 算法 / 电路 / 信号 / 控制）、`findVideos(category)` 与 `VideoVerification` / `VIDEO_VERIFICATION` 八条登记（`videoId`、机构、主讲、访问条件、适合内容、`verifiedAt = 2026-11-24`）。**未改动** `VIDEO_RESOURCES` 的既有字段，`docs/preview` 的深比较测试因此不受影响。
2. `ui/HomePage.ets`：
   - 分类常量改为读取 `VIDEO_CATEGORIES`，筛选与计数共用 `findVideos()`，避免两处硬编码。
   - 视频详情改为统一的“标签—值”信息行：提供机构、主讲、学科、语言、访问条件、使用条件、原始链接、核验日期，再附“适合”说明与官方入口按钮；八门课程字段完全对齐。未登记时显示“以官方课程页为准 / 未登记”，不编造数据。
   - 卡片副行改为“方向 · 语言 · 核验日期”，标题区右侧显示当前分组数量（`8 门 · 5 个方向` / `算法 · 2 门`），并新增使用边界说明“视频在原站观看，公开视频不代表可下载或再分发”。
   - 输入区：主题 / 长文编辑区高度 104 / 180vp；超长时就地提示改为“已保留这段输入。请缩短至 20,000 字以内再生成。”，计数行额外显示超出字数；生成按钮最小高度 52vp；按钮下补一行“生成失败时草稿会保留在输入框，可直接再次生成。”；示例区补“点一下填入输入框”提示。空白输入、busy、超长三种状态仍由 `generate()` 二次拦截。
3. 新增 `tools/tests/home-page.mjs`（7 项）：沿用 `resource-library.mjs` 的 `stripTypeScriptTypes` 真实执行方式，直接加载 `VideoCatalog.ets` 与 `HomePage` 的方法体，校验 8 门课程字段完整性与 5 个方向覆盖、`findVideos` 返回副本、`recentDocuments()` 降序且最多 3 项且不改写入参、`generate()` 对空白 / busy / 超长的拦截与 trim 后回调、`HomeVideoSource` 的筛选与监听通知、详情信息行标签齐全。

### 本轮验证（全部在本机实际执行）

| 命令 | 结果 |
| --- | --- |
| `node --test tools/tests/home-page.mjs` | 7 项通过，0 失败 |
| `npm run check` | 通过：4 个已接入页面、28 个 ArkTS 文件、有效导入与双主题文字对比 |
| `npm test` | 123 项通过，0 失败（含 `docs/preview/test-preview.mjs` 的 `VIDEO_RESOURCES` 深比较） |
| `curl.exe -sS -L -o NUL -w '%{http_code}'`（八条入口逐条） | 全部 200（2026-11-24） |

### 仍未覆盖

本轮未执行 SDK/hvigor 构建，未在模拟器或实体手机验收布局与交互，未验证实体设备网络下的视频播放，也未发起真实 AI 请求。上述测试执行的是真实 ArkTS 方法体与真实目录数据，但不等同于 ArkUI 渲染或设备验收；构建与设备验收仍需主入口统一完成。`HTTP 200` 只表示入口可达，不作为可播放、可下载或可再分发的依据。

## 2026-11-24 第三轮：补齐 PDF 9.1 的状态与微调（合并前记录）

### 本轮改动

1. 首页可见的生成状态（对应 PDF 9.1「生成中 / 生成失败」）：
   - `ui/HomePage.ets` 新增 `@Param progress`、`@Param errorMessage` 与本地 `dismissedError`，并在输入区顶部新增 `generationStatus()`：
     - 生成中：`LoadingProgress` + 进度文案（缺省「正在生成导图」），附「生成在『DIY 导图』页继续，返回本页也能看到当前进度」，标识 `home-generate-status`；
     - 生成失败：红字「生成失败：<原因>」+「草稿已保留，可直接再次点击『生成导图』重试」+ 可关闭的「知道了」，标识 `home-generate-failed`；
     - 状态条只读 `busy` / 失败原因，不新增网络或数据逻辑，草稿仍由本地 `draft` 持有。
   - `pages/Index.ets`：新增 `@Local generateError`，请求开始与复用已生成输入时清空，`catch` 记录失败原因，主动取消（`已取消生成…`）不计为失败；向 `HomePage` 传入 `progress` 与 `generateError`。
2. 9.1 微调补齐：
   - 主标题 33 → 35sp，上方留白 12 → 16vp，并补一行定位说明「说出主题或粘贴长文，生成可编辑、可导出的思维导图」；
   - 生成按钮最小高度 52 → 56vp，图标 18 → 20，文字 17sp 由 Medium 改 Bold；
   - 最近导图卡片收紧：图标 38 → 36vp、圆角 11 → 10、行间距 12 → 10、文字间距 4 → 3、内边距 14 → 12、分隔线缩进 64 → 60。
3. `tools/tests/home-page.mjs` 增至 9 项：新增「首页生成中 / 失败状态与外壳接线」（含“主动取消不算失败”）与「9.1 层级、生成按钮强调与最近导图卡片密度」两项断言；其余 7 项仍执行真实 ArkTS 方法体与真实目录数据。

### 本轮验证（全部在本机实际执行）

| 命令 | 结果 |
| --- | --- |
| `node --test tools/tests/home-page.mjs` | 9 项通过，0 失败 |
| `npm run check` | 通过：4 个已接入页面、28 个 ArkTS 文件、有效导入与双主题文字对比 |
| `npm test` | 125 项通过，0 失败 |

### 仍未覆盖

本轮实测范围是本机网关与 DeepSeek 上游，记录见 [AI 连接说明](ai-connection.md)。截图对应调整前的版本。

## 2026-11-26 首页合并后的接线

首页输入由 `Index.ets` 管理。资料库选「用作导图主题」会把主题填到首页，用户可以先修改，再提交。首页通过 `generating`、`generationProgress` 和 `generationError` 显示首次生成状态。可取消期间显示取消按钮，连接失败时可打开后端设置。生成成功且写入本地后打开 DIY 导图，失败或取消保留草稿和已有导图。

首页保留 9.1 的标题、生成按钮、最近导图卡片和课程分类、详情改动。九项首页测试随 `npm test` 一起运行。
