# 资料库原生组件截图

这里的预览宿主直接加载正式 `ui/LibraryPage.ets` 和同一份 `ResourceCatalog.ets`，不复制资料目录，不修改正式 `main_pages.json`。只有独立临时工程增加 `LibraryPreview` 路由。其余三个标签只用于还原公共导航的外观，不作为可用的正式页面交付。

在 macOS、DevEco Studio 和 Node 24+ 环境执行：

```sh
node tools/library-preview/capture-macos.mjs light
node tools/library-preview/capture-macos.mjs dark
```

默认输出 `artifacts/library-preview/`，分辨率 1080×2340，密度 480（360×780vp）。脚本通过 SDK Previewer 原生命令点击“开放教材”和 D2L 资料，保存主屏、筛选结果和详情。可用 `FLOWSPACE_DEVECO` 指定 DevEco Contents 路径，`FLOWSPACE_LIBRARY_OUTPUT` 指定输出目录。

小屏可指定 `FLOWSPACE_PREVIEW_WIDTH=960 FLOWSPACE_PREVIEW_HEIGHT=1800`（320×600vp），触控坐标请按实际截图在可选 steps.json 中修改。每步支持 `{name,tap:[x,y],waitMs}` 或 `{name,swipe:[x1,y1,x2,y2],waitMs}`。

原站打开在该宿主中明确显示“预览环境不启动外部浏览器”，用于检查失败反馈；主题回调仅显示“已收到主题提示，预览不调用 AI”。不得把这些替身当成系统浏览器或真实 AI 验收。全应用的实际外部浏览器调用仍由 `pages/Index.ets` 负责。

本轮使用的是 SDK 26.0.0.105，工程 compatible/target 均保留 `6.1.1(24)`；这不等于使用纯 API24 SDK 验证。正式路由、数据库和模型接口保持原工程实现。
