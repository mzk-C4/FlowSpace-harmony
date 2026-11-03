# DIY 思维导图交付记录

负责人：黄崇杰模块。以 CONTRACT.md 为接口来源；API 24，ComponentV2 / Param / Local / Event。只新增 ui/DIYPage.ets、canvas/ 和本记录，未改依赖、入口、构建配置或其他成员文件，未进行 Git 提交或切换。

## 原生库验证与适配选择

- 指定源码仓库 https://gitcode.com/CPF-ApplicationTPC/ohos_mind_elixir/tree/master 的网页获取超时，但 Git clone 成功。临时检出位置为 `C:/Users/HP/AppData/Local/Temp/flowspace-mind-elixir-proof`，HEAD `52d1ee7a134c4ca021092a159f0c819e35220835`。
- 独立目录 `C:/Users/HP/AppData/Local/Temp/flowspace-mind-elixir-registry-proof` 中执行官方 ohpm `install @ohos/mind-elixir` 成功，从 registry 下载 `mind-elixir-1.0.1.har`。主工程没有安装此依赖。
- 源码验证：原生 ArkUI，非 WebView。`MindMapNode` 等用 V1 `@Link model: MindElixirCore`；Core 保存可变数据、history/future；MindMapEvents 暴露节点/画布更新 emitter（不是本项目 EditorAction 的写入前拦截协议）。支持 RIGHT/BOTTOM 等方向。
- 在限定时间内无法证明第三方内部编辑、历史与 ComponentV2 单向文档、revision 校验能可靠统一，故采用用户已授权的自研 ArkUI Canvas 适配器。未声称该库不可用或编译失败，未复制其源码。

## 实现

- `canvas/MapLayout.ets`：纯函数布局，中文/拉丁字符近似宽度换行，节点按原 order 排列；right/down 两种树布局，折叠隐藏子树，动态节点高度和非重叠子树占位。导出 layoutMap / MapScene / CanvasNode，可供集成层复用。
- `canvas/MindMapCanvas.ets`：真正 Canvas 节点、曲线连线、选中描边、展开标志；单指平移、双指缩放、按钮缩放、适应全图；切换 documentId 自动适应；同一文档更新维持视口。颜色从共享资源解析，中文 HarmonyOS Sans 绘制。无 WebView、无列表冒充导图。
- `ui/DIYPage.ets`：完整合同 Param/Event；标题与保存状态、撤销/重做、布局切换、重命名、源文收起、节点编辑/备注/子节点/同级/移动/折叠/删除（系统二次确认，根禁删）、对话 sheet 与最近消息、进度和取消/错误、候选预览/应用/放弃、PNG/Markdown/JSON 导出入口。
- 所有正式写入仅 onAction / onGenerate / onApplyCandidate / onDiscardCandidate / onExport 回调。Canvas 从不修改 document；没有本地历史与正式数据副本。
- 候选期禁用正式编辑和导出，直接绘制父层传入的 candidate.document，放弃/应用后父层替换 document。候选阶段不自行恢复正式文档。
- 移动选项排除自己及后代，通过 LazyForEach 展示；合法性最终由父层 DocumentSession 校验。交互按钮最小44vp。不添加运动动画，减少动效偏好下也无额外运动。

## SDK 与静态验证

读取真实 SDK `E:/harmony system/command-line-tools/sdk/default/openharmony/ets/component/` 声明（本机不是 api/@internal/component 布局）：

- canvas.d.ts：roundRect、bezierCurveTo、fillText、CanvasRenderingContext2D.width/height。
- gesture.d.ts：PanGesture/PinchGesture onActionStart/onActionUpdate、GestureEvent.offsetX/offsetY/scale、FingerInfo.localX/localY。
- common.d.ts：bindSheet(boolean, CustomBuilder, SheetOptions)、SheetSize.LARGE、onAreaChange。
- api/@ohos.arkui.UIContext.d.ts：getPromptAction().showDialog(options) Promise，返回 index。
- api/@ohos.resourceManager.d.ts：getColorSync(Resource) 同步颜色解析。

运行纯布局 Node 断言，通过：right/down 各5节点、两两矩形不重叠、输入文档不变、折叠后子树隐藏、500节点布局、中文换行。使用 SDK 随附 TypeScript 对纯布局转译，诊断0；这不等同于 ArkTS 编译。

未运行设备/模拟器、真实 AI、文件导出或完整工程编译。完整 ArkTS 编译由主对话统一运行；PNG全图生成、系统文件选择器、存储、revision与撤销语义由合同指定父层服务提供，当前模块只提供可操作入口。仍需真机核验双指手势仲裁、软键盘弹出后的 sheet 可滚动性、暗色资源更新及中文字体实绘。
