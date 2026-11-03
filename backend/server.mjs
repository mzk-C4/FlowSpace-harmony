import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { GatewayError, validateRequest, validateCandidate } from './validation.mjs';
import { readConfig, buildMessages, callModel, parseOutput } from './llm.mjs';

export function createGateway({ env = process.env, timeoutMs = 120000, cacheTtlMs = 300000, maxCacheEntries = 30 } = {}) {
  const config = readConfig(env);
  const activeDocuments = new Map(), requests = new Map();
  const stable = value => Array.isArray(value) ? value.map(stable) : value && typeof value === 'object'
    ? Object.fromEntries(Object.keys(value).sort().map(key => [key, stable(value[key])])) : value;
  const json = (res, status, object) => {
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify(object));
  };
  function prune() {
    for (const [id, entry] of requests) if (!entry.pending && entry.expires <= Date.now()) requests.delete(id);
    while (requests.size >= maxCacheEntries) {
      const oldest = [...requests].find(([, value]) => !value.pending);
      if (!oldest) break;
      requests.delete(oldest[0]);
    }
  }
  const cacheSweep = setInterval(prune, 30000);
  cacheSweep.unref();
  function body(req) {
    return new Promise((resolve, reject) => {
      let size = 0, oversized = false; const chunks = [];
      req.on('data', chunk => {
        size += chunk.length;
        if (size > 512 * 1024) {
          if (!oversized) { oversized = true; chunks.length = 0; reject(new GatewayError('BODY_TOO_LARGE', '请求体超过 512 KiB', 413)); }
          return;
        }
        if (!oversized) chunks.push(chunk);
      });
      req.on('end', () => {
        if (oversized) return;
        try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
        catch { reject(new GatewayError('INVALID_JSON', '请求体不是有效 JSON')); }
      });
      req.on('error', reject);
      req.on('aborted', () => reject(new GatewayError('REQUEST_ABORTED', '请求已取消')));
    });
  }
  const server = createServer(async (req, res) => {
    const pathname = new URL(req.url, 'http://localhost').pathname;
    if (req.method === 'GET' && pathname === '/api/health') {
      return json(res, 200, { configured: config.configured, model: config.model,
        message: config.configured ? 'AI 网关已配置（尚未验证供应商连接）' : '请在服务端配置 LLM_BASE_URL、LLM_MODEL、LLM_API_KEY' });
    }
    if (req.method !== 'POST' || pathname !== '/api/mindmaps/generate') return json(res, 404, { code: 'NOT_FOUND', message: '接口不存在' });
    let request;
    try {
      if (!/^application\/json(?:;|$)/i.test(req.headers['content-type'] || '')) throw new GatewayError('UNSUPPORTED_MEDIA_TYPE', '请使用 application/json', 415);
      if (Number(req.headers['content-length']) > 512 * 1024) throw new GatewayError('BODY_TOO_LARGE', '请求体超过 512 KiB', 413);
      request = validateRequest(await body(req));
      if (!config.configured) throw new GatewayError('NOT_CONFIGURED', 'AI 服务未配置，请在服务端设置 LLM_BASE_URL、LLM_MODEL、LLM_API_KEY', 503);
    } catch (error) {
      return json(res, error instanceof GatewayError ? error.status : 400, { code: error.code || 'INVALID_REQUEST', message: error.message || '请求无效' });
    }
    prune();
    const fingerprint = createHash('sha256').update(JSON.stringify(stable(request))).digest('hex');
    const existing = requests.get(request.requestId);
    if (existing && existing.fingerprint !== fingerprint) return json(res, 409, { code: 'REQUEST_ID_CONFLICT', message: '同一 requestId 不可用于不同内容' });
    if (existing?.pending) return json(res, 409, { code: 'REQUEST_IN_PROGRESS', message: '该请求正在生成，请等待或取消' });
    if (activeDocuments.has(request.documentId)) return json(res, 409, { code: 'DOCUMENT_BUSY', message: '此文档正在生成，请先等待或取消' });
    res.writeHead(200, { 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-store', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
    res.flushHeaders();
    const send = event => { if (!res.destroyed && !res.writableEnded) res.write(`data: ${JSON.stringify(event)}\n\n`); };
    if (existing?.candidate) { send({ type: 'candidate', candidate: existing.candidate }); send({ type: 'done' }); return res.end(); }
    if (activeDocuments.size >= 8) { send({ type: 'error', code: 'GATEWAY_BUSY', message: '网关正在处理其他生成任务，请稍后重试' }); send({ type: 'done' }); return res.end(); }
    const controller = new AbortController();
    const abort = () => { if (!res.writableEnded) controller.abort(new Error('CLIENT_DISCONNECTED')); };
    res.on('close', abort); req.on('aborted', abort);
    activeDocuments.set(request.documentId, controller);
    const pending = { fingerprint, pending: true };
    requests.set(request.requestId, pending);
    const timeout = setTimeout(() => controller.abort(new Error('GENERATION_TIMEOUT')), timeoutMs);
    try {
      send({ type: 'progress', message: request.mode === 'create' ? '正在生成导图…' : '正在整理选中分支的修改…' });
      const messages = buildMessages(request);
      const progress = message => send({ type: 'progress', message });
      let candidate;
      for (let attempt = 0; attempt < 2; attempt++) {
        const content = await callModel(config, messages, controller.signal, progress);
        try { candidate = validateCandidate(parseOutput(content), request); break; }
        catch (error) {
          if (attempt === 1) throw new GatewayError('INVALID_MODEL_OUTPUT', '模型结构未通过校验，修复一次后仍无效。原导图未改变。', 502);
          send({ type: 'progress', message: '正在修复导图结构…' });
          messages.push({ role: 'assistant', content });
          messages.push({ role: 'user', content: `上次输出校验失败：${error.message}。按原协议修复，只返回完整 JSON {document,summary}，保留原文档身份、版本、范围外节点与稳定ID。` });
        }
      }
      if (controller.signal.aborted) throw controller.signal.reason;
      requests.set(request.requestId, { fingerprint, candidate, expires: Date.now() + cacheTtlMs, pending: false });
      send({ type: 'candidate', candidate });
    } catch (error) {
      if (requests.get(request.requestId) === pending) requests.delete(request.requestId);
      const timeoutError = controller.signal.reason?.message === 'GENERATION_TIMEOUT';
      if (!res.destroyed) send({ type: 'error', code: timeoutError ? 'GENERATION_TIMEOUT' : error instanceof GatewayError ? error.code : 'GENERATION_FAILED',
        message: timeoutError ? '生成超时，请重试。原导图未改变。' : error instanceof GatewayError ? error.message : '生成中断，请重试。原导图未改变。' });
    } finally {
      clearTimeout(timeout); res.off('close', abort); req.off('aborted', abort);
      activeDocuments.delete(request.documentId);
      send({ type: 'done' }); res.end();
    }
  });
  server.headersTimeout = 15000;
  server.requestTimeout = 30000;
  server.on('close', () => { clearInterval(cacheSweep); for (const controller of activeDocuments.values()) controller.abort(); requests.clear(); activeDocuments.clear(); });
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const port = Number(process.env.PORT || 8787), host = process.env.HOST || '127.0.0.1';
  const server = createGateway();
  server.listen(port, host, () => console.log(`FlowSpace AI gateway: http://${host}:${port} (configured: ${readConfig().configured})`));
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => process.exit(0)));
}
