# FlowSpace · AI 思维导图

在鸿蒙手机上把一个主题或一段长文整理成树状导图。画布支持 2D 平面和球形自由旋转、根节点居中的 3D 卡片两种视图，可以选中分支继续对话，先预览 AI 的修改，再决定是否应用。节点可手动增删、改名、移动或折叠。文档保存在本机，支持 PNG 全图、Markdown 和 JSON 备份。

## 在电脑上试一遍

**双击 [本地四页预览](docs/preview/index.html)，在首页点「打开示例导图 · 信号与系统」。** 选中「信号表征」，改一个节点再撤销，然后导出 JSON，在「个人」页导入即可比较两份导图。浏览器和鸿蒙应用使用同一份 10 节点示例与备份格式。网页中的生成及对话使用已标明的离线演示，编辑和备份可在本地实际操作。网页预览是 2D 交互草稿；3D 旋转透视和 2D/3D 对照见 [设计预览](docs/design/README.md)。[离线操作说明](docs/preview/README.md)

### 在电脑上用自己的模型

需要 Node.js 24+。在仓库根目录运行下面的命令，已有 `backend/.env` 时直接使用自己的配置。

```powershell
if (!(Test-Path backend/.env)) { Copy-Item backend/.env.example backend/.env }
# 在 backend/.env 填好 LLM_BASE_URL、LLM_MODEL、LLM_API_KEY，再启动
npm start
```

保持网关运行，在第二个终端生成可导入的备份。长文也可以用 `npm run try:ai -- --file "课程笔记.txt"` 读取 UTF-8 文件。

```powershell
npm run try:ai -- "按信号、系统和频域分析整理复习提纲"
```

命令会输出新 JSON 的本地路径。在离线预览或鸿蒙应用的「个人 → 从 JSON 备份恢复」中打开。模型密钥只由本机后端读取。缺配置、服务断开或候选不完整时，命令会显示原因。

### 在电脑上预览原生页面

Windows 需要 PowerShell 7、HarmonyOS API 24 命令行工具、SDK Previewer 和 JDK 17。在本项目环境运行下列命令，用原生 ArkUI 渲染手机界面并输出截图到 `artifacts/native-preview/`。

```powershell
npm run preview:native
npm run preview:native -- -ColorMode dark
```

[首页](docs/screenshots/home.jpg) · [DIY 编辑器](docs/screenshots/diy.jpg) · [资料库](docs/screenshots/library.jpg) · [个人](docs/screenshots/profile.jpg) · [深色画布](docs/screenshots/diy-dark.jpg)

## 安装到手机

需要 API 24 或更高的鸿蒙手机、开启并授权 USB 调试，以及本应用 `com.mzk.flowspace` 的合法调试签名。公开构建产物为 unsigned HAP。本机签名工程里的证书与配置保留在仓库外。

```powershell
npm run build:harmony
npm run phone:check -- -Hap artifacts/entry-default-unsigned.hap
# 有签名工程后，将参数换成它的真实路径
./tools/build-harmony.ps1 -SigningProject 'D:/FlowSpaceSigning' -OutputDirectory 'D:/FlowSpaceHap'
# 使用上一步 VerifiedSignedHaps 中的实际文件，可带 -DeviceId 选择 hdc 设备
./tools/test-phone.ps1 -Hap 'D:/FlowSpaceHap/entry-default-signed.hap' -MapGateway
```

真机脚本会核对签名、包名、目标设备、API 和 Ability 启动结果，采用更新安装。USB 映射时手机后端地址使用 `http://127.0.0.1:8787`。其他电脑可用 `-Toolchain` 和 `-JavaHome` 指定工具路径。[签名与真机步骤](docs/implementation/phone-testing.md) · [三条课程演示](docs/部署与演示.md)

## 页面分工

| 页面 | 负责人 | 微调与联调内容 |
| --- | --- | --- |
| 首页 | 赵紫石 | 主题或长文输入、最近导图、整理和维护 8 门工科视频原站链接 |
| DIY 思维导图 | 黄崇杰 | 原生 2D/3D 画布、节点增删改移、手势与布局、对话、撤销及导出 |
| 资料库 | 陈珂睿 | 维护 13 项开放教材与课程仓库，核对来源和许可，打磨检索与详情 |
| 个人 | 白长林 | 本地导图管理、JSON 恢复、外观、减少动效、后端配置 |
| 公共能力 | 马兆坤 | 领域命令、存储、AI 网关、合并、构建及验收 |

每位负责人可在 `entry/src/main/ets/ui/` 内调整自己的页面。页面共享双主题资源、系统线形图标和至少 44 vp 的常用触控按钮。旧学习工作台的 Git 快照位于 `archive/workbench-20261103`。[飞书分工与截图](https://nankai.feishu.cn/wiki/NVVxw1k9Sifu0okTLslcz0dRnbh)

## 验证与接口

```powershell
npm run check
npm test
npm run test:phone-scripts
```

专项手机脚本回归需要本机 SDK 和先前构建的 unsigned HAP。当前提交的原生截图来自 API 24 SDK Previewer。实体机签名安装、手机键盘触控、真实供应商生成和设备上导出由接机验收记录。[架构与本轮验收](docs/架构与验收.md) · [AI 协议](backend/README.md) · [模块接口](docs/implementation/CONTRACT.md) · [视频来源](docs/implementation/videos.md) · [资料与许可](docs/implementation/resources.md)
