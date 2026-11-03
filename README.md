# FlowSpace · AI 思维导图

面向鸿蒙手机的自然语言思维导图工具。描述主题或粘贴长文，由独立 AI 网关生成可编辑导图；继续对话、手工修改、撤销重做、本地保存与备份。首页与资料库提供工科学习视频、开放教材和课程仓库的原站入口。

新版采用 **HarmonyOS API 24 / ArkTS / ArkUI V2**，不包含旧工作台的任务、练习、排期、拍照、OCR、账号或云同步。旧版保存在 `archive/workbench-20261103` 分支；原本地工程及其未提交改动未被覆盖。

| 页面 | 负责人 | 已实现功能 |
| --- | --- | --- |
| 首页 | 赵紫石 | 自然语言/长文输入、示例、最近导图、8门工科视频课程 |
| DIY 思维导图 | 黄崇杰 | 原生画布、节点增删改移、折叠、缩放、两种布局、对话候选与导出入口 |
| 资料库 | 陈珂睿 | 13项资料、分类搜索、来源与许可、原站访问、主题生成 |
| 个人 | 白长林 | 本地导图管理、JSON恢复、外观、减少动效、后端配置和连接检查 |
| 公共能力 | 马兆坤 | Navigation、领域命令、版本保护、Repository、AI网关、导出、集成与验收 |

## 查看完整页面

双击 [四页面离线预览](docs/preview/index.html) 即可打开。现有界面是可调整初稿；四名负责人各自设计和微调对应页面，马兆坤统一联调。AI明确标为离线演示，浏览器数据与原生应用独立；不会冒充真实模型调用。原生页面代码位于 `entry/src/main/ets/ui/`。

## 启动和构建

需要 Node.js 24+；Windows构建脚本使用PowerShell 7（pwsh）。网关与测试没有 npm 第三方依赖，不需要 `npm install`。

```powershell
Copy-Item backend/.env.example backend/.env
# 仅在本地 backend/.env 配置 LLM_BASE_URL、LLM_MODEL、LLM_API_KEY
npm start
```

手机与电脑在同一网络时，后端设置 `HOST=0.0.0.0`，个人页填写电脑可达的地址，例如 `http://192.168.1.10:8787`。未配置模型会明确提示；健康检查仅确认网关与配置，生成操作才会调用供应商。不要把密钥填入手机或提交到 Git。

```powershell
npm run check
npm test
npm run build:harmony
```

构建脚本从当前源码复制到英文临时路径，避免 Hvigor 不支持中文路径。默认命令行工具在 `E:/harmony system/command-line-tools`，本机 JDK 在 `D:/projects/tools/jdk17/jdk-17.0.19+10`；其他电脑显式传入 `-Toolchain` 和 `-JavaHome`。产物位于 `artifacts/entry-default-unsigned.hap`。签名配置与证书不入仓库。

## 交付资料

- [最新分工与范围](requirements.md) · [飞书计划](https://nankai.feishu.cn/wiki/NVVxw1k9Sifu0okTLslcz0dRnbh)
- [架构与验收记录](docs/架构与验收.md) · [部署、安装及三条演示](docs/部署与演示.md)
- [AI 网关协议](backend/README.md) · [模块接口合同](docs/implementation/CONTRACT.md)
- [视频来源清单](docs/implementation/videos.md) · [资料与许可清单](docs/implementation/resources.md)
- [设计依据](docs/设计依据.md) · [预览测试边界](docs/preview/preview-result.md)

API 24 整体编译已通过。自动化测试使用本地假模型与原生接口替身，不等于真实供应商、手机数据库、文件选择器或手势验收；真实模型配置与签名设备验证仍待完成，详见验收记录。
