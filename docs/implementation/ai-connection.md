# 首页自然语言生成接 AI：接口与联调记录

负责人：赵紫石（首页）。上游网关由马兆坤交付，本文件说明**客户端需要什么**、**服务端必须提供什么**，以及 2026-11-24 的本机实测结果。

## 一、结论：客户端不需要新接口

首页「生成导图」按钮 → `pages/Index.ets` 的 `generate(text, true)` → `services/GenerationClient.ets` → 后端两个 HTTP 接口。协议与 `docs/implementation/CONTRACT.md` 一致，本轮**未改客户端协议**，只需服务端填好三个环境变量。

## 二、需要队长/后端确认的信息

| 信息 | 说明 | 本次结果 |
| --- | --- | --- |
| `LLM_BASE_URL` | OpenAI 兼容根地址，或完整 `/chat/completions` 地址；不要填平台网页地址 | `https://api.deepseek.com` |
| `LLM_MODEL` | 供应商实际可用模型标识 | `deepseek-flash`（可选 `deepseek-v4-pro`，更强但更慢更贵） |
| `LLM_API_KEY` | 只由服务器读取，绝不进入 HAP、日志、仓库 | 已放入本机 `backend/.env`（被 gitignore 忽略，未提交） |
| 手机联调地址 | App 个人页的“后端地址”必须填电脑局域网 IP，不能用手机自己的 `127.0.0.1` | `http://<电脑局域网IP>:8787`，服务端 `HOST=0.0.0.0` |

> 密钥是队长在聊天里直接发的。**课程结束后建议在 DeepSeek 控制台轮换**；传递密钥请走私聊或密码管理器，不要写进 PR 描述、群公告或截图。

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
| 供应商识别 | `GET {dashscope,moonshot,deepseek}/models` 各一次 | DashScope 401、Moonshot 401、**DeepSeek 200** |
| 网关启动 | `node --env-file-if-exists=backend/.env backend/server.mjs` | 200，`{"configured":true,"model":"deepseek-flash"}` |
| 真实生成 | 等价 Node 请求 `POST /api/mindmaps/generate`（与 App 请求体一致） | HTTP 200，26.0 s，27 条 `progress`，`candidate` 78 节点，根节点标题与主题一致，`requestId`/`baseRevision` 匹配，收到 `done`，`summary` 正常 |
| 密钥卫生 | `git status` / `git grep` | `backend/.env` 被忽略；已跟踪文件中无密钥 |

说明：上表验证的是**网关 + 真实供应商**。App 内 `GenerationClient`（ArkTS `http.requestInStream`）在真机上的表现仍需设备验收，本轮未做。

## 五、复现步骤

```powershell
Copy-Item backend/.env.example backend/.env
# 填写 LLM_BASE_URL / LLM_MODEL / LLM_API_KEY；手机联调时 HOST=0.0.0.0
node --env-file-if-exists=backend/.env backend/server.mjs
curl.exe -sS http://127.0.0.1:8787/api/health
```

App 侧：个人页填 `http://<电脑IP>:8787` → 检查连接 → 回首页输入主题 → 生成导图。生成中切回首页可看到进度，失败会显示原因与“草稿已保留”提示。

## 六、审批边界

- 未修改 `CONTRACT.md`、`backend/*`、密钥以外的配置；`backend/.env` 是本机未跟踪文件。
- 真实模型输出质量、供应商参数兼容性（`stream:true`、`temperature:0.2`、`max_tokens:12000`）已验证可跑通，但**不等于**课程验收：真机网络、签名安装、断网/取消仍需主入口统一验收。
