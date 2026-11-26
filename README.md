# FlowSpace · AI 思维导图

在鸿蒙手机上把一个主题或一段长文整理成树状导图。可以选中分支继续对话，先预览 AI 的修改，再决定是否应用。节点可手动增删、改名、移动或折叠。文档保存在本机，支持 PNG 全图、Markdown 和 JSON 备份。

## 在电脑上试一遍

**通过网关打开网页，即可输入一个主题或粘贴长文并生成导图。** 生成后进入编辑器，选择整图或一个分支继续整理，预览后确认应用。导图自动保存在当前浏览器。鸿蒙应用使用相同的生成协议与备份格式。

直接打开 [四页预览](docs/preview/index.html) 也可以离线编辑《信号与系统》示例和导入、导出备份。文件页与网关网页各自保存导图，可以用 JSON 备份在两边恢复。[网页操作说明](docs/preview/README.md)

### 在电脑上用自己的模型

需要 Node.js 24+。在仓库根目录运行下面的命令，已有 `backend/.env` 时直接使用自己的配置。

```powershell
if (!(Test-Path backend/.env)) { Copy-Item backend/.env.example backend/.env }
# 在 backend/.env 填好 LLM_BASE_URL、LLM_MODEL、LLM_API_KEY，再启动
npm start
```

保持网关运行，打开 [FlowSpace 网页](http://127.0.0.1:8787/)。从终端生成可以使用下方命令，长文可用 `npm run try:ai -- --file "课程笔记.txt"` 读取 UTF-8 文件。

```powershell
npm run try:ai -- "按信号、系统和频域分析整理复习提纲"
```

命令会输出 JSON 备份的本地路径。模型密钥只由服务端读取。

### 用电脑上的开源模型运行

用 llama.cpp 启动兼容服务，再运行本机网关。将命令中的模型文件换成已下载的 GGUF 权重。这里的模型名称与 `--alias` 一致。[llama.cpp 运行说明](https://github.com/ggml-org/llama.cpp/tree/master/tools/server) · [Qwen3-4B-Instruct-2507 GGUF](https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF)

```powershell
llama-server --model "./Qwen3-4B-Instruct-2507-Q4_K_M.gguf" --alias Qwen3-4B-Instruct-2507 --host 127.0.0.1 --port 11524 --ctx-size 32768 --parallel 1
npm run start:local -- Qwen3-4B-Instruct-2507
```

两条命令在不同终端运行。浏览器打开 [本机模型工作页](http://127.0.0.1:18797/)。模拟器可通过 `hdc -t <模拟器地址> rport tcp:8787 tcp:18797` 使用同一网关，应用后端地址填 `http://127.0.0.1:8787`。本机模式使用两个回环端口，供应商配置通过 `npm start` 加载。

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
| DIY 思维导图 | 黄崇杰 | 原生画布、节点增删改移、手势与布局、对话、撤销及导出 |
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

专项手机脚本回归需要本机 SDK 和先前构建的 unsigned HAP。当前提交的原生截图来自 API 24 SDK Previewer。实体机签名安装、手机键盘触控、真实供应商生成和设备上导出由接机验收记录。[架构与本轮验收](docs/架构与验收.md) · [AI 协议](backend/README.md) · [AI 联调记录](docs/implementation/ai-connection.md) · [模块接口](docs/implementation/CONTRACT.md) · [视频来源](docs/implementation/videos.md) · [资料与许可](docs/implementation/resources.md)
