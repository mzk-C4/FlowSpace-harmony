# FlowSpace 自然语言导图 AI 网关

独立 Node.js 24+ 服务，无第三方依赖，不使用旧学习工作台数据库、MathMate 配置或密钥。真实上游调用 OpenAI 兼容 Chat Completions 流式协议；没有配置时返回明确错误，不生成假 AI 结果。

## 启动

在新工程根目录执行：

```powershell
Copy-Item backend/.env.example backend/.env
# 在本地编辑 backend/.env，填写自己的供应商地址、模型和密钥
node --env-file-if-exists=backend/.env backend/server.mjs
```

环境变量：

| 变量 | 含义 |
| --- | --- |
| `LLM_BASE_URL` | 供应商兼容根地址，如 `https://example.com/v1`，或完整 `/chat/completions` 地址。不要填写平台网页地址。 |
| `LLM_MODEL` | 供应商实际可用的模型标识 |
| `LLM_API_KEY` | 只由服务器读取的密钥；不得进入 HAP、日志或仓库 |
| `HOST` | 默认 `127.0.0.1`；手机同局域网联调可设 `0.0.0.0` |
| `PORT` | 默认 `8787` |

`.env` 由 backend/.gitignore 忽略。这里不附带真实 key；密钥必须由使用者自行配置。手机端填电脑局域网地址，而不是手机自己的 `127.0.0.1`。

## HTTP 与 SSE

`GET /api/health` 返回 `{configured,model,message}`。`configured:true` 只表示三个变量具备有效形状，不代表已连接或测试供应商；响应明确说明这一点。

`POST /api/mindmaps/generate` 使用 `Content-Type: application/json`。请求形状与共享 `GenerationRequest` 完全相同：

```text
requestId, documentId, baseRevision, mode(create|revise), instruction,
scopeNodeId, document(MindMapDocument), messages(ChatMessage[])
```

创建同样使用客户端传入的 documentId 和根 ID。`baseRevision` 必须等于传入文档的 revision。修改必须指定真实 scopeNodeId，整图修改也明确指定 rootId。

成功进入生成时返回 `text/event-stream`，每条事件为 `data: 单行JSON\n\n`，仅有四种：

```text
{type:'progress',message:string}
{type:'candidate',candidate:{requestId,baseRevision,document,summary}}
{type:'error',code:string,message:string}
{type:'done'}
```

candidate 必须完整通过校验才会发出；原始 token、模型推理字段和未完成 JSON 不会转发给客户端。候选 revision 保持 baseRevision，由客户端统一命令入口在用户确认后递增；网关没有文档长期存储，不能替代客户端的当前 revision 检查。

请求错误在 SSE 开始前返回普通 JSON `{code,message}`，HTTP 400/409/413/415；缺配置为 503。已开始 SSE 的上游或模型错误以 error 再 done 结束，HTTP 状态维持 200，客户端必须解析事件，不能只看 HTTP 状态。客户端关闭连接会立即中止上游请求；超时为 120 秒，整个生成与一次修复共用此期限。

## 校验与一致性

- 输入指令至多 20000 字符，请求体至多 512 KiB；上游响应至多 2 MiB。
- 首次候选至多 200 节点，修改候选及传入文档至多 500 节点，深度至多 8 层（包括根）。检查唯一根、父 ID、重复 ID、环、孤儿和字段类型。
- 保留 schemaVersion/documentId/rootId/revision/layout/sourceText/messages/createdAt/updatedAt；AI 只修改内容树，标题只允许创建或修改整图根时改变。时间和对话历史由客户端管理。
- 修改范围外节点逐字段不变；范围根的 ID、父 ID 和顺序不能改变。保留节点不可重新分配 ID，新增节点只能位于选中子树内；子树内部允许新增、删除、改名、移动。
- 节点 ID 代表身份。服务端能验证 ID 唯一性、保留 ID、范围边界和完全相同节点被换 ID；无法凭语义判断“全部文本也被重写”的节点究竟是新建还是改名，因此客户端仍应显示候选预览供确认。
- 无效模型 JSON/树结构最多追加一次修复请求；第二次仍非法时不返回候选。网络、鉴权和限流错误不会触发结构修复或自动无限重试。
- 同一 documentId 一次只允许一个活跃生成，其他请求 409；网关最多同时运行 8 个文档生成。
- requestId 绑定规范化请求体摘要。相同 requestId/不同内容 409；相同活跃请求 409；已完成请求在进程内最多缓存 5 分钟、30 个候选（每 30 秒清理），重复请求回放候选而不重复调用供应商。失败/取消可用原请求重试。重启、过期或容量淘汰后不保证跨进程幂等，不声称持久化计费去重。

这是本机/可信局域网课程联调服务，没有公网账号鉴权；对公网部署应在受控 HTTPS 网关后接入鉴权与限流。现有接口不提供云端文档同步。

## 测试与验证边界

```powershell
node --test backend/tests/*.test.mjs
```

测试使用本地 HTTP 假上游，无外部凭据、无付费调用。验证跨网络块 UTF-8/SSE、候选结构、一次修复、取消与并发、请求重放、超时和错误。未配置/调用任何真实供应商，真实模型输出质量与供应商特定参数兼容性仍需使用者填入配置后实测。当前请求使用 `stream:true`、`temperature:0.2` 和 `max_tokens:12000`；供应商须支持这些 Chat Completions 字段。
