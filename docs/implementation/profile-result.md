# 白长林 · 个人页交付

实现文件：`entry/src/main/ets/ui/ProfilePage.ets`，目标 API 24，独立导出 `ProfilePage`，无 `@Entry` 或自建导航。仅新增本页和本文档，未改共享类型、入口、构建配置或其他协作者文件，未执行 Git 提交或分支操作。

## 已实现

- 本地文档按名称搜索、真实数量、无文档/无匹配空态；List + LazyForEach + IDataSource，cachedCount(6)。文档 props 替换后重建数据源，列表 key 包括标题和更新时间，重命名后不会复用旧内容。
- 点击打开；行内重命名，可取消，去除首尾空格，拒绝空白名称，输入上限 100 字符。通过合同回调请求写入，不修改 @Param。
- 删除使用 UIContext.showAlertDialog 系统确认，默认焦点为“保留”，只有确认才发出 onDeleteDocument；明确提示无法撤销与先导出备份。
- JSON 恢复按钮触发 onImport，说明创建新文档与保留原件。文件选择、内容校验及保存由主工程 ExportService/Repository 实现。
- 跟随系统/浅色/深色、减少动效和后端地址的本地草稿统一保存。aboutToAppear 初始化，@Monitor('settings') 在父组件替换已保存配置后同步全部表单。未对父传设置对象原地赋值。
- HTTP/HTTPS 地址通过 SDK url.URL 解析，去除首尾空格/末尾斜杠；拒绝账号、查询串、片段及空白字符；错误显示在表单。手机局域网地址、回环地址与后端密钥存放有文字说明。
- 连接测试通过 onCheckConnection，存在未保存草稿时禁用，避免测试目标与表单不符。显示父传真实结果，标注为最近一次检测；页面不伪造成功或保存完成。
- 关于、来源许可与本地数据说明；明确无账号/云同步、卸载数据风险、JSON 备份，以及 AI 请求涉及配置的后端及模型服务。
- 使用合同资源色，深色由主工程资源/外观控制生效；按钮、输入与开关触控目标至少 44vp；整页可滚动，无自定义装饰动画。

## 已做验证

已完整阅读 CONTRACT.md、arkts-syntax.md、arkui-patterns.md、emil-design-eng.md，并核对根 build-profile.json5 的 compatible/target 均为 `6.1.1(24)`。

真实 SDK：`E:/harmony system/command-line-tools/sdk/default/openharmony/ets/`。

| 检查项 | 结果/依据 |
| --- | --- |
| 系统删除确认 | api/@ohos.arkui.UIContext.d.ts:4264，showAlertDialog；component/alert_dialog.d.ts 中 primaryButton、secondaryButton、defaultFocus、fontColor、action |
| 设置同步 | component/common.d.ts:1273，MonitorDecorator 接受字符串路径 |
| 地址校验 | kits/@kit.ArkTS.d.ts 导出 url；api/@ohos.url.d.ts 的 URL 构造、protocol/hostname/username/password/search/hash |
| 懒加载 | component/lazy_for_each.d.ts 中 IDataSource/DataChangeListener/onDataReloaded |
| 资源与语法静态扫描 | 所用 app.color 均存在；仅 V2 状态，无入口导航，无 any/unknown 逃逸 |
| 官方 CodeLinter | 对本文件运行项目 code-linter.json5，生成报告为空数组 `[]`（CLI 退出码为 1，故只记录无诊断，不宣称编译通过） |

未运行整工程 Hvigor 编译，由主对话统一集成编译。未进行设备/模拟器、实际文件导入、真实 AI/后端连接测试，不能据此声称真机交互已通过。

## 主工程接入与验收

按合同传入所有事件；持久化成功后替换 settings/documents 引用，失败由主工程展示真实错误。onCheckConnection 应检测当前已保存 settings.backendUrl，并将配置缺失/网络失败/可用状态写入 connectionMessage。JSON 恢复和重命名/删除的最终结果来自主工程。

建议集成后验证：搜索→重命名→删除取消/确认；导入合法/非法 JSON；保存后切换页面；父组件异步加载设置后表单回填；局域网地址检测；深色与大字号；输入框聚焦时滚动到保存按钮。
