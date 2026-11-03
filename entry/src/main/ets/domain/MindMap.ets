export interface MindMapNode {
  id: string;
  parentId: string;
  order: number;
  text: string;
  note: string;
  collapsed: boolean;
}

export interface ChatMessage {
  id: string;
  role: string;
  content: string;
  createdAt: string;
}

export interface MindMapDocument {
  schemaVersion: number;
  documentId: string;
  title: string;
  revision: number;
  rootId: string;
  nodes: MindMapNode[];
  layout: string;
  sourceText: string;
  messages: ChatMessage[];
  createdAt: string;
  updatedAt: string;
}

export interface DocumentSummary {
  documentId: string;
  title: string;
  nodeCount: number;
  updatedAt: string;
}

export interface AppSettings {
  backendUrl: string;
  themeMode: string;
  reduceMotion: boolean;
}

export interface GenerationRequest {
  requestId: string;
  documentId: string;
  baseRevision: number;
  mode: string;
  instruction: string;
  scopeNodeId: string;
  document: MindMapDocument;
  messages: ChatMessage[];
}

export interface GenerationCandidate {
  requestId: string;
  baseRevision: number;
  document: MindMapDocument;
  summary: string;
}

export interface HealthStatus {
  configured: boolean;
  model: string;
  message: string;
}

export interface EditorAction {
  kind: string;
  nodeId: string;
  parentId: string;
  text: string;
  note: string;
}

export interface LearningResource {
  id: string;
  title: string;
  category: string;
  description: string;
  url: string;
  source: string;
  license: string;
  language: string;
  kind: string;
}

export function newId(prefix: string = 'map'): string {
  return prefix + '_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 10);
}

export function createDocument(title: string = '新的想法'): MindMapDocument {
  const now: string = new Date().toISOString();
  const rootId: string = newId('node');
  const root: MindMapNode = { id: rootId, parentId: '', order: 0, text: title, note: '', collapsed: false };
  const doc: MindMapDocument = { schemaVersion: 1, documentId: newId(), title: title, revision: 0,
    rootId: rootId, nodes: [root], layout: 'right', sourceText: '', messages: [], createdAt: now, updatedAt: now };
  return doc;
}

export function defaultSettings(): AppSettings {
  return { backendUrl: 'http://127.0.0.1:8787', themeMode: 'system', reduceMotion: false };
}

export function cloneDocument(doc: MindMapDocument): MindMapDocument {
  return JSON.parse(JSON.stringify(doc)) as MindMapDocument;
}
