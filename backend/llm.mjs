import { GatewayError, subtreeIds, validateCandidate } from './validation.mjs';

const nodeProperties = {
  id: { type: 'string' }, parentId: { type: 'string' }, order: { type: 'integer', minimum: 0 },
  text: { type: 'string' }, note: { type: 'string' }, collapsed: { type: 'boolean' }
};
const structuredResult = {
  type: 'json_schema',
  json_schema: {
    name: 'flowspace_map',
    schema: {
      type: 'object', required: ['title', 'nodes', 'summary'], additionalProperties: false,
      properties: {
        title: { type: 'string' }, summary: { type: 'string' },
        removeIds: { type: 'array', items: { type: 'string' } },
        nodes: {
          type: 'array', items: {
            type: 'object', properties: nodeProperties, required: ['id', 'parentId', 'order', 'text'],
            additionalProperties: false
          }
        }
      }
    }
  }
};

export function readConfig(env = process.env) {
  const baseUrl = (env.LLM_BASE_URL || '').trim();
  const model = (env.LLM_MODEL || '').trim();
  const apiKey = (env.LLM_API_KEY || '').trim();
  let endpoint = '';
  let local = false;
  try {
    const url = new URL(baseUrl);
    if (['https:', 'http:'].includes(url.protocol) && !url.username && !url.password && !url.search && !url.hash) {
      url.pathname = url.pathname.replace(/\/$/, '');
      if (!url.pathname.endsWith('/chat/completions')) url.pathname += '/chat/completions';
      endpoint = url.toString();
      local = ['127.0.0.1', '[::1]', 'localhost'].includes(url.hostname);
    }
  } catch { /* Health reports incomplete configuration; never echo secrets. */ }
  return { endpoint, model, apiKey, configured: Boolean(endpoint && model && (apiKey || local)) };
}

export function buildMessages(request) {
  const { document, mode, instruction, scopeNodeId } = request;
  if (mode === 'create') {
    return [
      { role: 'system', content: `把 instruction 中的自然语言或长文整理为思维导图。只输出 JSON {"title":"中心主题","nodes":[{"text":"一级分支","children":[{"text":"下级节点"}]}],"summary":"简短说明"}。nodes 是根的子分支。分支字段只有 text、可选的 note 和可选的 children，不写 ID。
遵循指定的分支、节点名称和层级。宽泛主题通常用三到六个一级分支。重要事实、例子或步骤用下级节点呈现，补充解释可用 note。保留原意，避免长段照抄或编造细节。用原文的语言和简洁标题。包括中心主题最多 200 个节点和 8 层。不加 Markdown 围栏。` },
      { role: 'user', content: JSON.stringify({ mode, instruction }) }
    ];
  }
  const scope = subtreeIds(document, scopeNodeId);
  const parentId = document.nodes.find(node => node.id === scopeNodeId).parentId;
  const context = {
    mode, scopeNodeId,
    document: { title: document.title, rootId: scopeNodeId, nodes: document.nodes.filter(node => scope.has(node.id))
      .map(node => node.id === scopeNodeId ? { ...node, parentId: '', order: 0 } : node) },
    parentLabel: document.nodes.find(node => node.id === parentId)?.text ?? '',
    sourceText: scopeNodeId === document.rootId && document.sourceText !== instruction ? document.sourceText : '',
    conversation: request.messages.filter(message => message.content !== instruction && message.content !== document.sourceText)
      .map(({ role, content }) => ({ role, content })),
    instruction
  };
  return [
    { role: 'system', content: `你是思维导图编辑器。只执行 instruction 中当前这次修改，其他内容仅供参考。只返回 JSON {"title":"主题","nodes":[新增或更新的节点],"summary":"简短说明"}，可以用 removeIds 列出待删分支 ID。用输入的语言。
nodes 只写需要增加或修改的节点。按指令指定的文字命名。若要求给选中分支加直接子节点，新节点的 parentId 必须等于 scopeNodeId。已有节点改名或移动时保留 ID。选中节点为子树根，不可删除。只在修改整图且有需要时更改 title。
节点必须有 id、parentId、order、text。新节点用 new-1、new-2 等临时 ID，新节点之间可以用临时 ID 引用父节点。parentId 指向父节点，输出范围根的 parentId 用空字符串。order 从 0 起按同级顺序排列。保留的节点会由程序补齐。可用 note 补充解释、collapsed 表示折叠，省略时保留旧值或使用默认值。全图最多 8 层和 500 节点。summary 说明实际改动。` },
    { role: 'user', content: JSON.stringify(context) }
  ];
}

function outlineDocument(output, base) {
  if (output.removeIds !== undefined) throw new GatewayError('INVALID_MODEL_OUTPUT', '创建不能包含待删除节点', 502);
  const nodes = [{ id: base.rootId, parentId: '', order: 0, text: output.title, note: '', collapsed: false }];
  const prefix = base.rootId.startsWith('branch-') ? 'topic-' : 'branch-';
  function visit(branches, parentId, depth) {
    if (!Array.isArray(branches)) throw new GatewayError('INVALID_MODEL_OUTPUT', 'children 必须为节点数组', 502);
    for (const [order, branch] of branches.entries()) {
      if (nodes.length >= 200 || depth > 8) throw new GatewayError('INVALID_MODEL_OUTPUT', '最多 200 个节点、8 层', 502);
      if (!branch || typeof branch.text !== 'string' || Object.keys(branch).some(key => !['text', 'note', 'children'].includes(key))) {
        throw new GatewayError('INVALID_MODEL_OUTPUT', '分支只接受 text、note 和 children', 502);
      }
      const id = prefix + nodes.length;
      nodes.push({ id, parentId, order, text: branch.text, note: branch.note ?? '', collapsed: false });
      if (branch.children !== undefined) visit(branch.children, id, depth + 1);
    }
  }
  if (!output.nodes.length) throw new GatewayError('INVALID_MODEL_OUTPUT', '请至少生成一个子分支', 502);
  visit(output.nodes, base.rootId, 2);
  return { ...base, title: output.title, nodes };
}

export function assembleCandidate(output, request) {
  if (!output || !Array.isArray(output.nodes) || typeof output.title !== 'string' ||
      Object.keys(output).some(key => !['title', 'nodes', 'summary', 'removeIds'].includes(key))) {
    throw new GatewayError('INVALID_MODEL_OUTPUT', '模型必须返回 title、nodes 和 summary', 502);
  }
  const base = request.document;
  if (request.mode === 'create') {
    return validateCandidate({ document: outlineDocument(output, base), summary: output.summary }, request);
  }
  const scopeRoot = request.scopeNodeId;
  const scope = subtreeIds(base, scopeRoot);
  const existing = new Map(base.nodes.map(node => [node.id, node]));
  const root = existing.get(scopeRoot);
  const ids = new Map();
  let serial = base.nodes.length + 1;
  for (const node of output.nodes) {
    if (!node || typeof node.id !== 'string') throw new GatewayError('INVALID_MODEL_OUTPUT', '节点缺少 ID', 502);
    if (ids.has(node.id)) throw new GatewayError('INVALID_MODEL_OUTPUT', '存在重复节点 ID', 502);
    if (scope.has(node.id)) { ids.set(node.id, node.id); continue; }
    if (!/^[a-zA-Z0-9_-]{1,128}$/.test(node.id)) {
      throw new GatewayError('INVALID_MODEL_OUTPUT', '新节点 ID 只能使用英文字母、数字、短横线和下划线', 502);
    }
    // The model sees only this branch. Its new IDs may coincide with IDs in other branches.
    let id = 'ai-' + serial++;
    while (existing.has(id)) id = 'ai-' + serial++;
    ids.set(node.id, id);
  }
  const updates = new Map(output.nodes.map(node => {
    const id = ids.get(node.id), previous = existing.get(id);
    const fields = { note: previous?.note ?? '', collapsed: previous?.collapsed ?? false, ...node,
      id, parentId: ids.get(node.parentId) ?? node.parentId };
    if (id === scopeRoot) { fields.parentId = root.parentId; fields.order = root.order; }
    return [id, fields];
  }));
  const title = scopeRoot === base.rootId ? output.title : base.title;
  const nodes = base.nodes.map(node => updates.get(node.id) ?? node);
  nodes.push(...[...updates.values()].filter(node => !existing.has(node.id)));
  const document = { ...base, title, nodes };
  const removals = output.removeIds ?? [];
  if (!Array.isArray(removals) || removals.some(id => id === scopeRoot || !scope.has(id))) {
    throw new GatewayError('INVALID_MODEL_OUTPUT', '只可删除范围内且非范围根的节点', 502);
  }
  if (removals.length) {
    const removed = new Set(removals.flatMap(id => [...subtreeIds(document, id)]));
    document.nodes = nodes.filter(node => !removed.has(node.id));
  }
  const fields = Object.keys(nodeProperties);
  if (title === base.title && document.nodes.length === base.nodes.length && document.nodes.every(node =>
    existing.has(node.id) && fields.every(key => existing.get(node.id)[key] === node[key]))) {
    throw new GatewayError('INVALID_MODEL_OUTPUT', '没有实际修改，请执行当前指令', 502);
  }
  return validateCandidate({ document, summary: output.summary }, request);
}

export async function callModel(config, messages, signal, onProgress, mode) {
  let response;
  try {
    const headers = { 'Content-Type': 'application/json', Accept: 'text/event-stream' };
    if (config.apiKey) headers.Authorization = `Bearer ${config.apiKey}`;
    const payload = { model: config.model, stream: true, messages, temperature: 0.2, max_tokens: 12000 };
    if (config.constrainOutput) payload.response_format = mode === 'create' ? { type: 'json_object' } : structuredResult;
    response = await fetch(config.endpoint, {
      method: 'POST', signal, headers,
      body: JSON.stringify(payload)
    });
  } catch (error) {
    if (signal.aborted) throw error;
    throw new GatewayError('UPSTREAM_UNAVAILABLE', '无法连接模型服务，请检查服务端地址与网络', 502);
  }
  if (!response.ok) {
    await response.body?.cancel();
    throw new GatewayError('UPSTREAM_ERROR', response.status === 401 || response.status === 403
      ? '模型服务鉴权失败，请检查服务端密钥配置' : `模型服务请求失败（HTTP ${response.status}）`, 502);
  }
  let total = 0, content = '', finished = false, lastProgress = 0;
  const decoder = new TextDecoder();
  const isSSE = (response.headers.get('content-type') || '').includes('text/event-stream');
  let buffer = '';
  function consumeEvent(frame) {
    const data = frame.split('\n').filter(line => line.startsWith('data:')).map(line => line.slice(5).trimStart()).join('\n');
    if (!data) return;
    if (data.trim() === '[DONE]') { finished = true; return; }
    let parsed;
    try { parsed = JSON.parse(data); } catch { throw new GatewayError('UPSTREAM_PROTOCOL', '模型返回了无法解析的数据流', 502); }
    if (parsed.error) throw new GatewayError('UPSTREAM_ERROR', '模型服务在生成时报告错误', 502);
    const delta = parsed.choices?.[0]?.delta?.content;
    if (typeof delta === 'string') content += delta;
    if (Date.now() - lastProgress > 700 && content.length) { lastProgress = Date.now(); onProgress('正在整理节点与层级…'); }
  }
  try {
    for await (const chunk of response.body) {
      total += chunk.byteLength;
      if (total > 2 * 1024 * 1024) throw new GatewayError('UPSTREAM_TOO_LARGE', '模型响应超过安全大小限制', 502);
      buffer += decoder.decode(chunk, { stream: true });
      if (isSSE) {
        // Normalize only complete CRLF pairs; a CR can straddle network chunks.
        buffer = buffer.replace(/\r\n/g, '\n');
        let boundary;
        while ((boundary = buffer.indexOf('\n\n')) >= 0) {
          const frame = buffer.slice(0, boundary); buffer = buffer.slice(boundary + 2); consumeEvent(frame);
        }
        if (finished) break;
      }
    }
  } catch (error) {
    if (signal.aborted || error instanceof GatewayError) throw error;
    throw new GatewayError('UPSTREAM_INTERRUPTED', '模型连接中断，请重试', 502);
  }
  if (isSSE) {
    buffer += decoder.decode();
    if (buffer.trim()) consumeEvent(buffer.replace(/\r\n/g, '\n'));
  } else {
    try {
      const parsed = JSON.parse(buffer + decoder.decode());
      content = parsed.choices?.[0]?.message?.content;
    } catch { throw new GatewayError('UPSTREAM_PROTOCOL', '模型服务没有返回兼容的数据格式', 502); }
  }
  if (typeof content !== 'string' || !content.trim()) throw new GatewayError('UPSTREAM_EMPTY', '模型未返回导图内容', 502);
  return content;
}

export function parseOutput(text) {
  const cleaned = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  try { return JSON.parse(cleaned); }
  catch { throw new GatewayError('INVALID_MODEL_OUTPUT', '模型输出不是有效 JSON', 502); }
}
