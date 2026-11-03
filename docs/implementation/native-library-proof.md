# @ohos/mind-elixir 1.0.1 独立 API 24 构建验证

核对日期：2026-11-04。本任务只新增本文档；测试工程与依赖均在临时英文目录。未修改主应用、Canvas、依赖或第三方源码，未使用浏览器、未绕过此前的 file: URL 拦截。

## 结论

**官方 ohpm 包 `@ohos/mind-elixir@1.0.1` 在本机 API 24 实际编译和 unsigned HAP 打包成功。** 最小工程真实导入并调用库的 `MindElixir` 原生组件，加载含中文标题的 `MindElixirData`，页面有 `getData()` 读取按钮及 `refresh(data)` 恢复按钮；不是用列表或占位画面冒充集成。

另完成 `@ComponentV2` 入口 → 隔离 `@Component` V1 容器 → 第三方 V1 组件的第二次构建，也成功。这个验证仅证明组件宿主组合可编译：边界没有混传 `@Param` / `@Link`，尚未接入主应用文档、统一命令、存储或 AI。

没有设备或模拟器运行，因此**不能据此宣称屏幕渲染、中文实绘、触控、缩放、键盘、读取/恢复按钮的运行效果、500 节点性能已验收**。页面内的中文数据只是已编译打包的样例。

## 保留的临时工程与产物

- 构建工程：`C:/Users/HP/AppData/Local/Temp/flowspace-native-library-build-api24-20261104`。
- 最终页面：`entry/src/main/ets/pages/Index.ets`。纯 V1 首次页面备份：工程根 `Index-v1-only.ets.txt`。
- 首次 V1 完整成功日志：`build-api24.log`，`BUILD SUCCESSFUL in 13 s 26 ms`。
- V2 宿主第一次尝试日志：`build-api24-v2host.log`，失败原因是本验证页 `@Entry` 根节点直接用了自定义组件，报 10905210；包一层 `Column` 后解决。这是测试页写法错误，不能归因为库不兼容。
- V2 宿主最终成功日志：`build-api24-v2host-fixed.log`，`CompileArkTS` 通过，`BUILD SUCCESSFUL in 9 s 713 ms`。
- 最终 HAP：`entry/build/default/outputs/default/entry-default-unsigned.hap`，565931 字节。
- 最终 HAP SHA-256：`36784D7A690556394B7121BAE37559294E3417284645C2BA79CE3CEE527D6F5E`。
- 依赖锁：`entry/oh-package-lock.json5`，精确版本 1.0.1，registry 为 `https://ohpm.openharmony.cn/ohpm/`，HAR 为 `https://ohpm.openharmony.cn/ohpm/@ohos/mind-elixir/-/mind-elixir-1.0.1.har`。未打补丁、未降级版本。

工程复制主项目的 API 24 最小构建配置、资源和 EntryAbility；移除临时模块中不需要的 routerMap 与备份扩展声明，只编译一页。声明依赖在临时 entry 中，不污染主工程。

## 环境与重现

```powershell
Set-Location 'C:/Users/HP/AppData/Local/Temp/flowspace-native-library-build-api24-20261104'
$env:JAVA_HOME='D:/projects/tools/jdk17/jdk-17.0.19+10'
$env:NODE_HOME='E:/harmony system/command-line-tools/tool/node'
$env:DEVECO_SDK_HOME='E:/harmony system/command-line-tools/sdk'
$env:PATH="$env:JAVA_HOME/bin;$env:NODE_HOME;$env:PATH"
& 'E:/harmony system/command-line-tools/ohpm/bin/ohpm.bat' install
& 'E:/harmony system/command-line-tools/hvigor/bin/hvigorw.bat' --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
```

`targetSdkVersion` / `compatibleSdkVersion` 都为 `6.1.1(24)`，根包和 Hvigor `modelVersion` 为 `6.0.0`。没有签名配置，只有 unsigned 包。

实际警告包括库 `MindMapLines.ets` 的测试 `key`、`WindowManager.ets` 三处可能抛异常调用，以及主工程样例资源与库通用资源名冲突。首次完整编译还报告库导出 `@Entry` 且有 `@Link/@Prop` 的不推荐组合；这些都是 warning，首次及修正后的最终构建均无阻断错误。后续正式集成仍应治理资源命名与生命周期/预览风险。

## 源码核查：读取、恢复与数据转换

核查包内 `src/main/ets/controller/MindElixirCore.ets`、`components/MindElixir.ets`、`controller/NodeHelper.ets` 和 `model/NodeObj.ets`；同时参考克隆的上游示例。上游检出位置 `C:/Users/HP/AppData/Local/Temp/flowspace-mind-elixir-proof`，此前记录 HEAD 为 `52d1ee7a134c4ca021092a159f0c819e35220835`。以本次实际下载的 1.0.1 为编译对象，不把上游 HEAD 等同于发布包。

| 能力 | 1.0.1 的实际源码行为 | 统一文档适配要求 |
| --- | --- | --- |
| 初次加载 | `MindElixir.aboutToAppear()` 调用 `model.init(data)`；不存在名为 load 的必要 API | 将不可变正式文档投影为独立的嵌套树再传入 |
| 数据读取 | `getData(): MindElixirData \| null` 返回 `originMindElixirData` 引用，不是防写快照 | 读取后立即复制/规范化，不能让外部直接改引用 |
| 替换恢复 | `refresh(optionalData)` 调用 `init(data)`；`init` 设置内部数据、深拷贝 origin、计算布局、发更新事件；开历史时再记一条历史 | 对父层文档变更显式 refresh，不依靠 `data` 属性变化自动重载；本地库历史应关闭 |
| 节点格式 | `nodeData` 根对象，节点 `id/topic/children/expanded`；布局会增加坐标、层级、父节点摘要等信息 | `text→topic`、`collapsed→!expanded`，按 `parentId/order` 嵌套，回读仅提取允许的字段 |
| 文档格式 | 库不管理本项目的 documentId、revision、sourceText、messages、备注或保存状态 | 原文档仍是唯一数据源；备注与元信息不从库输出覆盖 |
| 布局 | `LayoutDirection.RIGHT`、`BOTTOM` 可表达本项目 right/down | 枚举映射留在适配器，不改公共领域类型 |

`NodeHelper` 会为展示树增加 `parent` 摘要和布局信息；不要将带视图元数据的任意对象直接当作领域备份。当前最小页读取及恢复按钮只是调用能力的编译证明，运行时一致性需要后续设备验证。

## 事件能否直接接入统一命令

**不能把现有事件直接当成写入前、可取消的 `EditorAction` 协议；需要专门适配。**

- `MindMapEvents.ets` 实际通过系统 emitter 广播 `NODE_UPDATED=1` / `CANVAS_UPDATED=2`；Core 的 `notifyUpdate()` 发出时没有节点 ID、action、旧值、revision 或 instanceId。
- `add/remove/updateNode/drag`、内建编辑和折叠先修改库内部树，再 `refresh()` / 发更新。事件是更新通知，不是操作授权或事务提交前钩子；不能用它来阻止不合法修改，AI baseRevision 也无处自动校验。
- `selectNode()` 只更新内部 selectedNodeId，不发选择事件；虽有 `getSelectedNodeId()` / `getSelectedNode()`，公共 `Index.ets` 未导出 `MindMapEventEmitter`。不能把另一个 `EventTypes.ets` 中定义但未使用的 `NODE_SELECTED=1002` 误认成已工作的对外回调。
- 事件 ID 是全局的；`offNodeUpdated/offCanvasUpdated` 按事件 ID 整体移除监听，`destroy()` 会调用它们。多个实例的监听隔离需实测或治理，不能默认互不影响。
- Core 自带 `history/future` 和 `undo/redo`，不认识本项目单调 revision、一次候选一个撤销单元等要求。正式应用应只有 `DocumentSession` 管历史。

如果继续探索第三方渲染，应先限定为 V1 展示适配器，关闭内建编辑、拖拽重排、contextMenu、toolBar、allowUndo 和 collapsible（折叠同样是领域动作）；手工命令、历史、AI 候选应用都由正式 `DocumentSession` 执行后重新投影并 refresh。节点选择需增加明确的桥接回调或受控分支，不能轮询更新广播来猜操作。若要开放库自带编辑，则需要明确的动作桥接、校验失败回滚及监听隔离测试，不能直接接上服务后当成完成。

本次没有替换已通过主工程构建的自研 Canvas。准确结论是“库原生且可在 API 24 构建，命令及状态桥接仍待设计和实机验证”，不是“库编译失败”或“库不能用”。
