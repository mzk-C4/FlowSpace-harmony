export class GatewayError extends Error {
  constructor(code, message, status = 400) { super(message); this.code = code; this.status = status; }
}
const fail = message => { throw new GatewayError('INVALID_DOCUMENT', message); };
const keysOnly = (value, allowed, name) => {
  if (Object.keys(value).some(key => !allowed.includes(key))) fail(`${name} 包含未定义字段`);
};
const string = (value, name, max, allowEmpty = false) => {
  if (typeof value !== 'string' || value.length > max || (!allowEmpty && !value.trim())) fail(`${name} 无效或超出长度限制`);
};
export function validateDocument(doc, maxNodes = 500) {
  if (!doc || typeof doc !== 'object' || Array.isArray(doc)) fail('缺少导图文档');
  keysOnly(doc, ['schemaVersion', 'documentId', 'title', 'revision', 'rootId', 'nodes', 'layout', 'sourceText', 'messages', 'createdAt', 'updatedAt'], 'document');
  if (doc.schemaVersion !== 1) fail('不支持的文档版本');
  string(doc.documentId, 'documentId', 128); string(doc.rootId, 'rootId', 128);
  string(doc.title, 'title', 200);
  if (!Number.isSafeInteger(doc.revision) || doc.revision < 0) fail('revision 必须为非负整数');
  if (!['right', 'down'].includes(doc.layout)) fail('layout 仅支持 right/down');
  string(doc.sourceText, 'sourceText', 20000, true);
  for (const field of ['createdAt', 'updatedAt']) {
    string(doc[field], field, 64);
    if (!Number.isFinite(Date.parse(doc[field]))) fail(`${field} 不是有效日期`);
  }
  validateMessages(doc.messages);
  if (!Array.isArray(doc.nodes) || !doc.nodes.length || doc.nodes.length > maxNodes) fail(`节点数必须为 1–${maxNodes}`);
  const nodes = new Map();
  for (const node of doc.nodes) {
    if (!node || typeof node !== 'object' || Array.isArray(node)) fail('节点结构错误');
    keysOnly(node, ['id', 'parentId', 'order', 'text', 'note', 'collapsed'], 'node');
    string(node.id, 'node.id', 128); string(node.parentId, 'node.parentId', 128, true);
    string(node.text, 'node.text', 500); string(node.note, 'node.note', 10000, true);
    if (!Number.isSafeInteger(node.order) || node.order < 0 || typeof node.collapsed !== 'boolean') fail('节点顺序或折叠状态无效');
    if (nodes.has(node.id)) fail('存在重复节点 ID');
    nodes.set(node.id, node);
  }
  const root = nodes.get(doc.rootId);
  if (!root || root.parentId !== '') fail('根节点缺失或根节点父 ID 非空');
  for (const node of nodes.values()) {
    if (node.id !== doc.rootId && !nodes.has(node.parentId)) fail('节点父 ID 不存在');
    const seen = new Set(); let current = node;
    while (current) {
      if (seen.has(current.id)) fail('导图存在循环');
      seen.add(current.id);
      if (seen.size > 8) fail('导图最多 8 层（含根）');
      current = current.parentId ? nodes.get(current.parentId) : null;
    }
    if (!seen.has(doc.rootId)) fail('节点不属于唯一根节点');
  }
  return doc;
}
export function validateMessages(messages) {
  if (!Array.isArray(messages) || messages.length > 100) fail('对话消息格式错误或超过 100 条');
  let total = 0;
  for (const message of messages) {
    if (!message || typeof message !== 'object') fail('对话消息格式错误');
    keysOnly(message, ['id', 'role', 'content', 'createdAt'], 'message');
    string(message.id, 'message.id', 128);
    if (!['user', 'assistant'].includes(message.role)) fail('对话角色仅支持 user/assistant');
    string(message.content, 'message.content', 20000, true); total += message.content.length;
    string(message.createdAt, 'message.createdAt', 64);
  }
  if (total > 100000) fail('对话历史总长度超过 100000 字符');
}
export function validateRequest(request) {
  if (!request || typeof request !== 'object' || Array.isArray(request)) throw new GatewayError('INVALID_REQUEST', '请求必须为 JSON 对象');
  string(request.requestId, 'requestId', 128); string(request.documentId, 'documentId', 128);
  string(request.instruction, 'instruction', 20000);
  string(request.scopeNodeId, 'scopeNodeId', 128, true);
  if (!['create', 'revise'].includes(request.mode)) throw new GatewayError('INVALID_REQUEST', 'mode 仅支持 create/revise');
  validateDocument(request.document); validateMessages(request.messages);
  if (request.documentId !== request.document.documentId || request.baseRevision !== request.document.revision) {
    throw new GatewayError('REVISION_CONFLICT', 'documentId/baseRevision 与提交文档不一致', 409);
  }
  if (request.mode === 'revise' && !request.document.nodes.some(n => n.id === request.scopeNodeId)) {
    throw new GatewayError('INVALID_SCOPE', '请选择存在的修改范围节点');
  }
  return request;
}
export function subtreeIds(doc, rootId) {
  const ids = new Set([rootId]); let changed = true;
  while (changed) { changed = false; for (const node of doc.nodes) { if (ids.has(node.parentId) && !ids.has(node.id)) { ids.add(node.id); changed = true; } } }
  return ids;
}
const nodeKeys = ['id', 'parentId', 'order', 'text', 'note', 'collapsed'];
const sameNode = (a, b) => !!b && nodeKeys.every(key => a[key] === b[key]);
export function validateCandidate(output, request) {
  if (!output || typeof output !== 'object' || !output.document) fail('模型必须输出 {document,summary}');
  keysOnly(output, ['document', 'summary'], '模型结果');
  string(output.summary, 'summary', 1000);
  const doc = validateDocument(output.document, request.mode === 'create' ? 200 : 500);
  const base = request.document;
  for (const key of ['schemaVersion', 'documentId', 'rootId', 'revision', 'layout', 'createdAt', 'updatedAt', 'sourceText']) {
    if (doc[key] !== base[key]) fail(`模型不可更改 ${key}`);
  }
  const messageKeys = ['id', 'role', 'content', 'createdAt'];
  if (doc.messages.length !== base.messages.length || doc.messages.some((message, index) =>
    messageKeys.some(key => message[key] !== base.messages[index][key]))) fail('模型不可更改文档对话历史');
  if (request.mode === 'revise') {
    const scope = subtreeIds(base, request.scopeNodeId);
    const candidateScope = subtreeIds(doc, request.scopeNodeId);
    const byId = new Map(doc.nodes.map(n => [n.id, n]));
    const originalById = new Map(base.nodes.map(n => [n.id, n]));
    const oldScopeRoot = originalById.get(request.scopeNodeId), newScopeRoot = byId.get(request.scopeNodeId);
    if (!newScopeRoot || newScopeRoot.parentId !== oldScopeRoot.parentId || newScopeRoot.order !== oldScopeRoot.order) fail('修改范围根节点必须保留 ID、父节点和顺序');
    if (request.scopeNodeId !== base.rootId && doc.title !== base.title) fail('局部修改不可更改文档标题');
    for (const original of base.nodes) {
      if (!scope.has(original.id) && !sameNode(original, byId.get(original.id))) fail('修改影响了选中子树外节点');
    }
    for (const node of doc.nodes) {
      if (!originalById.has(node.id) && !candidateScope.has(node.id)) fail('新增节点必须位于选中子树内');
      if (scope.has(node.id) && !candidateScope.has(node.id)) fail('原子树节点不能移出修改范围');
    }
    // Unchanged nodes retain their IDs even if the model reordered the nodes array.
    for (const oldNode of base.nodes.filter(n => scope.has(n.id))) {
      if (byId.has(oldNode.id)) continue;
      if (doc.nodes.some(n => !originalById.has(n.id) && ['parentId', 'order', 'text', 'note', 'collapsed'].every(k => n[k] === oldNode[k]))) fail('未变化节点不能被重新分配 ID');
    }
  }
  return { requestId: request.requestId, baseRevision: request.baseRevision, document: doc, summary: output.summary };
}
