# 首页自然语言生成接 AI：接口与联调记录

负责人：赵紫石（首页）。上游网关由马兆坤交付，本文件说明**客户端需要什么**、**服务端必须提供什么**，以及 2026-11-24 的本机实测结果。

## 一、结论：客户端不需要新接口

首页「生成导图」通过 `pages/Index.ets` 的 `generate(text, true)` 和 `services/GenerationClient.ets` 调用网关。个人页使用健康检查接口。两者沿用 [共享协议](CONTRACT.md)。

## 二、网关配置

| 变量 | 说明 |
| --- | --- |
| `LLM_BASE_URL` | OpenAI 兼容接口的根地址或完整 `/chat/completions` 地址 |
| `LLM_MODEL` | 供应商提供的模型标识 |
| `LLM_API_KEY` | 保存到服务端环境变量或本机未跟踪的 `backend/.env` |

## 三、服务端必须提供的接口（后端已实现）

### 1. `GET /api/health`

返回 `{ configured, model, message }`。`configured:true` 只表示三个变量形状有效，不代表供应商连通；App 个人页“检查连接”用它。

### 2. `POST /api/mindmaps/generate`

- 请求头：`Content-Type: application/json`，`Accept: text/event-stream`
- 请求体 = 共享 `GenerationRequest`：

```text
requestId     string   客户端生成，用于幂等与回放
documentId    string   创建时也使用客户端传入的 documentId
baseRevision  number   必须等于请求体 document.revision
mode          'create' | 'revise'
instruction   string   用户主题或长文，≤20,000 字符
scopeNodeId   string   revise 必填真实节点 ID；create 传空串
document      MindMapDocument （schemaVersion=1, revision, rootId, nodes, layout, sourceText, messages, createdAt, updatedAt）
messages      ChatMessage[]   ≤100 条
```

- 成功：HTTP 200 + `text/event-stream`，每条事件 `data: 单行JSON\n\n`，只有四种：

```text
{type:'progress', message:string}
{type:'candidate', candidate:{requestId, baseRevision, document, summary}}
{type:'error', code:string, message:string}
{type:'done'}
```

- 失败（SSE 之前）：普通 JSON `{code, message}`，状态码 400 / 409 / 413 / 415；缺配置 503。SSE 已开始后的上游错误以 `error` + `done` 结束，HTTP 仍是 200，客户端必须解析事件。
- 硬约束：候选必须整份通过校验才发出；`baseRevision` 与 `requestId` 必须回传一致（客户端会比对，不一致即丢弃并保留原图）；同一 `documentId` 并发 409；客户端断开连接即中止上游；超时 120 秒；响应 ≤2 MiB。

## 四、本次实测（2026-11-24，本机）

| 步骤 | 命令/方式 | 结果 |
| --- | --- | --- |
| 网关启动 | `node --env-file-if-exists=backend/.env backend/server.mjs` | 200，`{"configured":true,"model":"deepseek-flash"}` |
| 真实生成 | 等价 Node 请求 `POST /api/mindmaps/generate`（与 App 请求体一致） | HTTP 200，26.0 s，27 条 `progress`，`candidate` 78 节点，根节点标题与主题一致，`requestId`/`baseRevision` 匹配，收到 `done`，`summary` 正常 |
| 密钥卫生 | `git status` / `git grep` | `backend/.env` 被忽略；已跟踪文件中无密钥 |

说明：上表验证的是**网关 + 真实供应商**。App 内 `GenerationClient`（ArkTS `http.requestInStream`）在真机上的表现仍需设备验收，本轮未做。

## 五、按联调环境启动

使用云模型时，在 `backend/.env` 填写上面的三个变量，然后在仓库根目录启动网关。

```powershell
npm start
curl.exe -sS http://127.0.0.1:8787/api/health
```

用本机模型时，启动 llama.cpp 和网关，电脑端打开 `http://127.0.0.1:18797/`。[本机模型步骤](../../README.md#用电脑上的开源模型运行)

| 联调环境 | 应用个人页的后端地址 | 连通方式 |
| --- | --- | --- |
| 模拟器或 USB 手机，云模型网关 | `http://127.0.0.1:8787` | `hdc -t <设备地址> rport tcp:8787 tcp:8787` |
| 模拟器或 USB 手机，本机模型网关 | `http://127.0.0.1:8787` | `hdc -t <设备地址> rport tcp:8787 tcp:18797` |
| 同一可信局域网的手机，云模型网关 | `http://<电脑局域网IP>:8787` | 启动网关时设置 `HOST=0.0.0.0` |

在个人页填写后端地址，点击「保存更改」后测试连接，再回首页输入主题或粘贴长文。首页显示进度并提供取消按钮，生成成功并写入本地后进入 DIY 导图。失败或取消时保留草稿及已有导图。
