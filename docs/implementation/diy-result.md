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

## 2026-11-23 视觉与交互设计微调

方向为“克制层级”，详细设计见 [DIY 思维导图设计](diy-design.md)。

- **选中分支可追踪**：画布缓存根到选中节点的路径；路径连线改为蓝紫 2.6vp，中间节点 1.8vp 描边，选中节点保持 2.5vp 强描边。普通连线降到 1.8vp 的中性色，层级一眼可读。
- **层级权重**：根节点实心强调；一级节点 1.2vp 蓝紫描边；叶子使用 1vp 细边。没有引入新的分支配色，仍与四页主题一致。
- **折叠徽标**：`MapLayout` 预计算隐藏后代数；折叠节点显示 `+N`（超过 99 显示 `+99`），展开仍为 `−`。500 节点下为一次记忆化计数，不增加绘制时的线性查找。
- **画布优先**：顶部内边距 10→7vp；底部由“选中信息 + 全宽继续整理”两行收为一行（当前分支名、编辑、添加、更多、继续整理胶囊），画布多出约 20–30vp。
- **候选确认**：预览条显示节点数与修改范围，补充“应用后可一次撤销”；“确认应用”按 1.8 倍宽度成为主操作，“放弃候选”降为次要；过期候选改用危险色并禁用确认。
- **对话面板**：修改范围改为浅紫卡片，非根节点提供“改为整图”；生成中同时显示进度与范围；输入框/发送按钮固定在底部，发送按钮禁用时显式降透明度。
- **空图提示**：仅单根节点时显示“从根节点开始”，不拦截画布手势。
- **2D / 3D 双视图**：缩放条最左侧新增切换按钮。2D 保持平面树；3D 使用 yaw/pitch 透视相机，默认 −20° / 20°，节点按 `(x, y, depth*70)` 旋转并透视缩放，投影前按层级展开树间距避免卡片重叠。卡片保持正面朝向，绘制“投影阴影 + 右下厚度面 + 顶面”，按相机深度从远到近绘制，选中卡片补绘到最上。
- **3D 交互**：单指拖动旋转视角，pitch 限制 ±1 rad；双指拖动平移、双指捏合缩放；右下角“复位”回到默认角度并适应画布。连线、徽标、选中路径和命中测试都使用投影坐标；导出仍使用完整 2D 树。
- **验证**：`npm run check` 通过；`npm test` 130 项全部通过（画布 38 项）。新增 14 项画布测试覆盖隐藏后代计数、选中分支、折叠徽标，以及 3D 投影、yaw/pitch 旋转、200/500 节点适应、3D 命中、3D 绘制、500 卡片绘制、旋转手势、默认角度不重叠和 2D/3D 切换。本机无 HarmonyOS SDK/真机，未做 ArkTS 编译、原生预览、键盘与手势验收；[2D/3D 对照图](../design/README.md)由预览页面生成，不是原生截图。
