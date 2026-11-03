import { MindMapDocument, MindMapNode, GenerationCandidate, cloneDocument, newId } from './MindMap';

function requireText(value: string, name: string, limit: number, empty: boolean = false): void {
  if (typeof value !== 'string' || value.length > limit || (!empty && value.trim().length === 0)) {
    throw new Error(name + '格式无效');
  }
}

export function validateDocument(doc: MindMapDocument): void {
  if (!doc || typeof doc !== 'object' || doc.schemaVersion !== 1) throw new Error('不支持的导图版本');
  requireText(doc.documentId, '文档 ID', 128);
  requireText(doc.title, '文档标题', 200);
  requireText(doc.rootId, '根节点 ID', 128);
  if (!Number.isSafeInteger(doc.revision) || doc.revision < 0) throw new Error('文档版本无效');
  if (doc.layout !== 'right' && doc.layout !== 'down') throw new Error('布局无效');
  requireText(doc.sourceText, '原文', 20000, true);
  requireText(doc.createdAt, '创建日期', 64);
  requireText(doc.updatedAt, '修改日期', 64);
  if (!Number.isFinite(Date.parse(doc.createdAt)) || !Number.isFinite(Date.parse(doc.updatedAt))) throw new Error('日期无效');
  if (!Array.isArray(doc.nodes) || doc.nodes.length < 1 || doc.nodes.length > 500) throw new Error('导图需要 1–500 个节点');
  if (!Array.isArray(doc.messages) || doc.messages.length > 1000) throw new Error('对话格式无效');
  const ids: Set<string> = new Set<string>();
  const nodes: Map<string, MindMapNode> = new Map<string, MindMapNode>();
  let rootCount: number = 0;
  for (const node of doc.nodes) {
    if (!node || typeof node !== 'object') throw new Error('节点格式无效');
    requireText(node.id, '节点 ID', 128);
    requireText(node.parentId, '父节点 ID', 128, true);
    requireText(node.text, '节点文字', 500);
    requireText(node.note, '节点备注', 10000, true);
    if (!Number.isSafeInteger(node.order) || node.order < 0 || typeof node.collapsed !== 'boolean') throw new Error('节点属性无效');
    if (ids.has(node.id)) throw new Error('节点 ID 重复');
    ids.add(node.id);
    nodes.set(node.id, node);
    if (node.parentId === '') {
      rootCount++;
      if (node.id !== doc.rootId) throw new Error('根节点不一致');
    }
  }
  if (rootCount !== 1 || !nodes.has(doc.rootId)) throw new Error('必须有唯一根节点');
  for (const node of doc.nodes) {
    const seen: Set<string> = new Set<string>();
    let current: MindMapNode | undefined = node;
    let depth: number = 0;
    while (current !== undefined) {
      if (seen.has(current.id)) throw new Error('节点形成循环');
      seen.add(current.id);
      depth++;
      if (depth > 8) throw new Error('最多支持 8 层节点');
      if (current.parentId === '') break;
      const parent: MindMapNode | undefined = nodes.get(current.parentId);
      if (parent === undefined) throw new Error('父节点不存在');
      current = parent;
    }
  }
  const messageIds: Set<string> = new Set<string>();
  for (const message of doc.messages) {
    if (!message || typeof message !== 'object') throw new Error('对话格式无效');
    requireText(message.id, '消息 ID', 128);
    requireText(message.content, '消息内容', 20000, true);
    requireText(message.createdAt, '消息日期', 64);
    if (message.role !== 'user' && message.role !== 'assistant') throw new Error('消息角色无效');
    if (messageIds.has(message.id) || !Number.isFinite(Date.parse(message.createdAt))) throw new Error('消息 ID 或日期无效');
    messageIds.add(message.id);
  }
}

export class DocumentSession {
  document: MindMapDocument;
  private past: MindMapDocument[] = [];
  private future: MindMapDocument[] = [];

  constructor(doc: MindMapDocument) {
    validateDocument(doc);
    this.document = cloneDocument(doc);
  }

  canUndo(): boolean { return this.past.length > 0; }
  canRedo(): boolean { return this.future.length > 0; }

  private node(doc: MindMapDocument, id: string): MindMapNode {
    const found: MindMapNode | undefined = doc.nodes.find((item: MindMapNode) => item.id === id);
    if (found === undefined) throw new Error('节点不存在');
    return found;
  }

  private commit(next: MindMapDocument): void {
    next.documentId = this.document.documentId;
    next.revision = this.document.revision + 1;
    next.createdAt = this.document.createdAt;
    next.updatedAt = new Date().toISOString();
    validateDocument(next);
    this.past.push(cloneDocument(this.document));
    if (this.past.length > 100) this.past.shift();
    this.future = [];
    this.document = next;
  }

  private preserveConversation(next: MindMapDocument): void {
    next.messages = cloneDocument(this.document).messages;
    next.sourceText = this.document.sourceText;
  }

  addNode(parentId: string, text: string): string {
    const next: MindMapDocument = cloneDocument(this.document);
    this.node(next, parentId);
    const siblings: MindMapNode[] = next.nodes.filter((n: MindMapNode) => n.parentId === parentId);
    const order: number = siblings.reduce((max: number, n: MindMapNode) => Math.max(max, n.order + 1), 0);
    const id: string = newId('node');
    const node: MindMapNode = { id: id, parentId: parentId, order: order, text: text.trim(), note: '', collapsed: false };
    next.nodes.push(node);
    this.node(next, parentId).collapsed = false;
    this.commit(next);
    return id;
  }

  addSibling(nodeId: string, text: string): string {
    const original: MindMapNode = this.node(this.document, nodeId);
    if (original.parentId === '') throw new Error('根节点不能添加同级节点');
    const next: MindMapDocument = cloneDocument(this.document);
    for (const item of next.nodes) {
      if (item.parentId === original.parentId && item.order > original.order) item.order++;
    }
    const id: string = newId('node');
    const node: MindMapNode = { id: id, parentId: original.parentId, order: original.order + 1, text: text.trim(), note: '', collapsed: false };
    next.nodes.push(node);
    this.commit(next);
    return id;
  }

  editNode(nodeId: string, text: string, note: string): void {
    const next: MindMapDocument = cloneDocument(this.document);
    const node: MindMapNode = this.node(next, nodeId);
    node.text = text.trim();
    node.note = note;
    this.commit(next);
  }

  removeNode(nodeId: string): void {
    if (nodeId === this.document.rootId) throw new Error('根节点不能删除');
    this.node(this.document, nodeId);
    const removed: Set<string> = new Set<string>();
    removed.add(nodeId);
    let changed: boolean = true;
    while (changed) {
      changed = false;
      for (const node of this.document.nodes) {
        if (removed.has(node.parentId) && !removed.has(node.id)) { removed.add(node.id); changed = true; }
      }
    }
    const next: MindMapDocument = cloneDocument(this.document);
    next.nodes = next.nodes.filter((node: MindMapNode) => !removed.has(node.id));
    this.commit(next);
  }

  moveNode(nodeId: string, parentId: string): void {
    if (nodeId === this.document.rootId) throw new Error('根节点不能移动');
    const next: MindMapDocument = cloneDocument(this.document);
    const node: MindMapNode = this.node(next, nodeId);
    this.node(next, parentId);
    node.parentId = parentId;
    node.order = next.nodes.filter((item: MindMapNode) => item.parentId === parentId)
      .reduce((max: number, item: MindMapNode) => Math.max(max, item.order + 1), 0);
    this.node(next, parentId).collapsed = false;
    this.commit(next);
  }

  toggleCollapsed(nodeId: string): void {
    const next: MindMapDocument = cloneDocument(this.document);
    const node: MindMapNode = this.node(next, nodeId);
    node.collapsed = !node.collapsed;
    this.commit(next);
  }

  setLayout(layout: string): void {
    const next: MindMapDocument = cloneDocument(this.document);
    next.layout = layout;
    this.commit(next);
  }

  rename(title: string): void {
    const next: MindMapDocument = cloneDocument(this.document);
    next.title = title.trim();
    this.commit(next);
  }

  applyCandidate(candidate: GenerationCandidate): void {
    if (!candidate || candidate.baseRevision !== this.document.revision) throw new Error('导图已修改，请重新生成候选');
    if (candidate.document.documentId !== this.document.documentId) throw new Error('候选属于其他导图');
    validateDocument(candidate.document);
    const next: MindMapDocument = cloneDocument(candidate.document);
    this.preserveConversation(next);
    this.commit(next);
  }

  undo(): void {
    if (!this.canUndo()) return;
    const next: MindMapDocument = cloneDocument(this.past[this.past.length - 1]);
    this.preserveConversation(next);
    next.revision = this.document.revision + 1;
    next.updatedAt = new Date().toISOString();
    validateDocument(next);
    this.future.push(cloneDocument(this.document));
    this.past.pop();
    this.document = next;
  }

  redo(): void {
    if (!this.canRedo()) return;
    const next: MindMapDocument = cloneDocument(this.future[this.future.length - 1]);
    this.preserveConversation(next);
    next.revision = this.document.revision + 1;
    next.updatedAt = new Date().toISOString();
    validateDocument(next);
    this.past.push(cloneDocument(this.document));
    this.future.pop();
    this.document = next;
  }
}
