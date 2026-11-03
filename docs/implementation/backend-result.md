# Backend 交付结果

已交付独立 Node.js AI 网关，不复用旧工作台后端或 MathMate 密钥。

- `backend/server.mjs`：health、生成 SSE、关闭连接取消、120 秒超时、文档并发锁、有界请求幂等缓存、body 限制。
- `backend/llm.mjs`：真实兼容上游流式 HTTP、跨块 UTF-8 和 SSE 解析、无隐藏推理转发、严格结构提示、一次修复。
- `backend/validation.mjs`：共享领域形状、身份/版本/根/稳定 ID、子树范围、200/500 节点与 8 层校验。
- `backend/tests/gateway.test.mjs`：10 组本地单元及 HTTP 测试。
- `backend/.env.example`、局部 `.gitignore` 与 `backend/README.md`：配置、协议及验证限制。

已运行 `node --test backend/tests/*.test.mjs`，10 组通过，覆盖文档非法结构、输入长度、版本冲突、范围越界、隐藏字段、真实 HTTP SSE 分块、完成请求去重、同 ID 异内容冲突、一次修复/修复失败、同文档并发、取消上游并释放锁、超时、上游鉴权失败、非法 JSON、body 超限、无配置 503。

尚未进行真实模型供应商调用，没有读取/复制任何旧密钥。`configured:true` 仅表示环境变量完整，health 不声称供应商连接成功。节点身份的语义变化不能仅凭模型文本自动判断，候选需客户端预览确认；最终应用必须检查当前 revision。幂等只覆盖进程内短期缓存，不是持久化跨重启计费保证。详情见 backend/README.md。

没有修改根 package、公共模型或其他成员源码，也没有 git 提交。
