import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { fileURLToPath } from 'node:url';
import { validateRequest } from '../../backend/validation.mjs';

const source = path => readFileSync(fileURLToPath(new URL('../../entry/src/main/ets/' + path + '.ets', import.meta.url)), 'utf8');
const dataModule = text => 'data:text/javascript;base64,' + Buffer.from(stripTypeScriptTypes(text, { mode: 'transform' })).toString('base64');
const mindMapModule = dataModule(source('domain/MindMap'));
const sessionModule = dataModule(source('domain/DocumentSession').replace(/^import .*;\r?\n/, `import {cloneDocument,newId} from '${mindMapModule}';\n`));
const builderModule = dataModule(source('domain/GenerationRequestBuilder').replace(/^import .*;\r?\n/, `import {cloneDocument,newId} from '${mindMapModule}';\n`));
const { createDocument, cloneDocument } = await import(mindMapModule);
let sequence = 0;
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; };
const tick = () => new Promise(resolve => setImmediate(resolve));

function repository(seed) {
  const repo = {
    docs: new Map(seed.map(doc => [doc.documentId, cloneDocument(doc)])),
    saved: [], failSave: false, pending: Promise.resolve(), getGate: null,
    async initialize() {}, async loadSettings() { return { backendUrl: 'http://localhost:8787', themeMode: 'system', reduceMotion: false }; },
    async saveSettings() {},
    async save(doc) {
      const snapshot = cloneDocument(doc); this.saved.push(snapshot);
      const job = this.pending.then(async () => {
        if (this.failSave) throw new Error('模拟磁盘写入失败');
        this.docs.set(snapshot.documentId, snapshot);
      });
      this.pending = job.catch(() => {}); return job;
    },
    async list() {
      await this.pending;
      return [...this.docs.values()].map(doc => ({ documentId: doc.documentId, title: doc.title, nodeCount: doc.nodes.length, updatedAt: doc.updatedAt }));
    },
    async get(id) { await this.pending; if (this.getGate) await this.getGate.promise; return this.docs.has(id) ? cloneDocument(this.docs.get(id)) : null; },
    async delete(id) { await this.pending; this.docs.delete(id); }
  };
  return repo;
}

async function appHarness({ seed, generate, imported } = {}) {
  const oldDoc = createDocument('已有导图');
  oldDoc.documentId = 'original-document'; oldDoc.nodes[0].text = '已有重要知识';
  const otherDoc = createDocument('另一份导图'); otherDoc.documentId = 'other-document';
  const repo = repository(seed || [oldDoc, otherDoc]);
  const calls = [];
  const client = {
    healthStatus: { configured: false, model: '', message: '尚未配置模型' },
    async health() { return this.healthStatus; },
    async generate(baseUrl, request, onProgress) {
      calls.push({ baseUrl, request: cloneDocument(request), onProgress });
      if (generate) return generate(request, onProgress, calls.length);
      return candidateFor(request);
    }, cancel() {}
  };
  const exports = { async importDocument() { if (!imported) throw new Error('模拟用户取消导入'); return cloneDocument(imported); }, async exportDocument() {} };
  globalThis.__workflowDependencies = { repo, client, exports };
  const nativeHeader = `
import {createDocument,defaultSettings,cloneDocument,newId} from '${mindMapModule}';
import {DocumentSession,validateDocument} from '${sessionModule}';
import {buildGenerationRequest} from '${builderModule}';
const {repo:documentRepository,client:generationClient,exports:exportService}=globalThis.__workflowDependencies;
const ConfigurationConstant={ColorMode:{COLOR_MODE_NOT_SET:0,COLOR_MODE_LIGHT:1,COLOR_MODE_DARK:2}};
class NavPathStack {}
`;
  const indexSource = source('pages/Index');
  const methods = indexSource.slice(0, indexSource.indexOf('  @Builder'))
    .replace(/^import [\s\S]*?;\r?\n/gm, '')
    .replace(/^@Entry\r?\n|^@ComponentV2\r?\n/gm, '')
    .replace(/\bstruct Index\b/, 'class Index')
    .replace(/@Local\s+/g, '');
  // Only ArkUI rendering/decorators are removed; all production workflow methods
  // (including storage, candidate handling and request construction) run intact.
  const { default: App } = await import(dataModule(nativeHeader + methods + `\n}\nexport default Index;\nexport const testInstance=${++sequence};`));
  App.prototype.getUIContext = () => ({ getHostContext: () => ({ getApplicationContext: () => ({ setColorMode() {} }), async startAbility() {} }) });
  const app = new App(); app.ready = true; app.loading = false;
  app.useDocument(seed?.[0] || oldDoc); app.saveStatus = '已保存';
  return { app, repo, client, calls, oldDoc, otherDoc };
}
function candidateFor(request) {
  const doc = cloneDocument(request.document);
  doc.nodes[0].text = 'AI整理后的知识';
  return { requestId: request.requestId, baseRevision: request.baseRevision, document: doc, summary: '已整理结构' };
}
function edit(app, text) {
  app.action({ kind: 'edit', nodeId: app.document.rootId, parentId: '', text, note: '' });
}
test.after(() => { delete globalThis.__workflowDependencies; });

test('save failure blocks switching without losing edits; successful retry flushes the old document', async () => {
  const { app, repo, otherDoc, oldDoc } = await appHarness();
  repo.failSave = true;
  edit(app, '必须保留的未落盘编辑');
  await app.openDocument(otherDoc.documentId);
  assert.equal(app.document.documentId, oldDoc.documentId);
  assert.equal(app.document.nodes[0].text, '必须保留的未落盘编辑');
  assert.match(app.saveStatus, /^未保存/); assert.equal(app.changingDocument, false);
  assert.equal(repo.docs.get(oldDoc.documentId).nodes[0].text, '已有重要知识');
  repo.failSave = false;
  await app.openDocument(otherDoc.documentId);
  assert.equal(app.document.documentId, otherDoc.documentId);
  assert.equal(repo.docs.get(oldDoc.documentId).nodes[0].text, '必须保留的未落盘编辑');
  assert.equal(app.saveStatus, '已保存');
});

test('failed flush blocks new/create/import/rename/delete, preserving the only in-memory draft', async () => {
  for (const operation of ['new', 'generate', 'import', 'rename', 'delete']) {
    const { app, repo, oldDoc, calls } = await appHarness();
    repo.failSave = true; edit(app, '失败时仍保留');
    if (operation === 'new') await app.newMap();
    if (operation === 'generate') await app.generate('新主题', true);
    if (operation === 'import') await app.importDocument();
    if (operation === 'rename') await app.renameDocument(oldDoc.documentId, '新标题');
    if (operation === 'delete') await app.deleteDocument(oldDoc.documentId);
    assert.equal(app.document.documentId, oldDoc.documentId, operation);
    assert.equal(app.document.nodes[0].text, '失败时仍保留', operation);
    assert.equal(repo.docs.size, 2, operation); assert.equal(calls.length, 0, operation);
    assert.equal(app.changingDocument, false, operation);
  }
});

test('document transition lock blocks concurrent navigation, imports, deletion, rename and editing', async () => {
  const { app, repo, otherDoc } = await appHarness();
  repo.getGate = deferred();
  const opening = app.openDocument(otherDoc.documentId);
  await tick(); assert.equal(app.changingDocument, true);
  const current = cloneDocument(app.document);
  await app.newMap(); await app.importDocument(); await app.deleteDocument(current.documentId);
  await app.renameDocument(current.documentId, '不应重命名'); await app.openDocument(current.documentId);
  edit(app, '不应写入');
  assert.deepEqual(app.document, current); assert.equal(repo.docs.size, 2);
  repo.getGate.resolve(); await opening;
  assert.equal(app.document.documentId, otherDoc.documentId); assert.equal(app.changingDocument, false);
});

test('successful first generation saves a new map, preserves old map and deduplicates the same completed input', async () => {
  const { app, repo, calls, oldDoc } = await appHarness();
  await app.generate('整理电路知识', true);
  const id = app.document.documentId;
  assert.notEqual(id, oldDoc.documentId); assert.equal(app.document.nodes[0].text, 'AI整理后的知识');
  assert.equal(app.document.revision, 1); assert.equal(app.document.sourceText, '整理电路知识');
  assert.equal(repo.docs.get(id).nodes[0].text, 'AI整理后的知识');
  assert.equal(repo.docs.get(oldDoc.documentId).nodes[0].text, '已有重要知识');
  assert.equal(app.busy, false); assert.equal(app.saveStatus, '已保存');
  await app.generate('整理电路知识', true);
  assert.equal(calls.length, 1); assert.equal(app.document.documentId, id); assert.equal(repo.docs.size, 3);
});

test('failed first generation preserves the original saved map and saves a retryable source draft with reused documentId', async () => {
  const { app, repo, calls, oldDoc } = await appHarness({ generate: async (request, _progress, attempt) => {
    if (attempt === 1) throw new Error('AI 服务未配置'); return candidateFor(request);
  } });
  await app.generate('整理信号与系统', true);
  const draftId = app.document.documentId;
  assert.notEqual(draftId, oldDoc.documentId); assert.equal(app.document.revision, 0);
  assert.equal(app.document.sourceText, '整理信号与系统'); assert.match(app.message, /未配置/);
  assert.equal(repo.docs.get(draftId).sourceText, '整理信号与系统');
  assert.equal(repo.docs.get(oldDoc.documentId).nodes[0].text, '已有重要知识');
  await app.generate('整理信号与系统', true);
  assert.equal(app.document.documentId, draftId); assert.equal(calls.length, 2); assert.equal(repo.docs.size, 3);
  assert.equal(app.document.nodes[0].text, 'AI整理后的知识');
});

test('hand edits during generation make candidate stale; applying it cannot overwrite the new graph', async () => {
  const gate = deferred();
  const { app, calls } = await appHarness({ generate: async request => { await gate.promise; return candidateFor(request); } });
  const work = app.generate('扩充中心主题');
  await tick(); assert.equal(app.busy, true);
  edit(app, '生成过程中手动修改');
  const revision = app.document.revision;
  gate.resolve(); await work;
  assert.equal(app.candidate.baseRevision, calls[0].request.baseRevision);
  assert.match(app.message, /候选已过期/);
  app.applyCandidate();
  assert.equal(app.document.nodes[0].text, '生成过程中手动修改'); assert.equal(app.document.revision, revision);
  assert.match(app.message, /重新生成候选/); assert.ok(app.candidate !== null);
  app.discardCandidate(); assert.equal(app.candidate, null); assert.equal(app.document.nodes[0].text, '生成过程中手动修改');
});

test('failed create then hand edits then same-input retry requires confirmation and remains undoable', async () => {
  const { app, repo, calls } = await appHarness({ generate: async (request, _progress, attempt) => {
    if (attempt === 1) throw new Error('首次上游暂不可用');
    return candidateFor(request);
  } });
  await app.generate('同一个创建主题', true);
  const draftId = app.document.documentId;
  edit(app, '失败后自己补充的重要知识');
  await app.persist();
  const editedRevision = app.document.revision;
  assert.ok(editedRevision > 0);
  await app.generate('同一个创建主题', true);
  assert.equal(calls.length, 2); assert.equal(app.document.documentId, draftId);
  assert.equal(calls[1].request.baseRevision, editedRevision);
  assert.equal(app.document.nodes[0].text, '失败后自己补充的重要知识');
  assert.equal(repo.docs.get(draftId).nodes[0].text, '失败后自己补充的重要知识');
  assert.equal(app.candidate.document.nodes[0].text, 'AI整理后的知识');
  assert.equal(app.document.revision, editedRevision);
  app.applyCandidate(); await app.persist();
  assert.equal(app.candidate, null); assert.equal(app.document.nodes[0].text, 'AI整理后的知识');
  assert.equal(app.document.revision, editedRevision + 1);
  app.action({ kind: 'undo', nodeId: '', parentId: '', text: '', note: '' });
  await app.persist();
  assert.equal(app.document.nodes[0].text, '失败后自己补充的重要知识');
  assert.equal(app.document.revision, editedRevision + 2);
  await app.generate('同一个创建主题', true);
  assert.equal(calls.length, 2, 'confirmed create retries are marked complete and do not issue another provider call');
  assert.equal(app.document.documentId, draftId); assert.equal(repo.docs.size, 3);
});

test('matching revision candidate remains a single undo unit and ignores duplicate generation while busy', async () => {
  const gate = deferred();
  const { app, calls } = await appHarness({ generate: async request => { await gate.promise; return candidateFor(request); } });
  const before = cloneDocument(app.document);
  const work = app.generate('完善中心主题');
  await tick(); await app.generate('不应产生第二次并发提交'); assert.equal(calls.length, 1);
  gate.resolve(); await work;
  assert.equal(app.document.nodes[0].text, before.nodes[0].text); assert.ok(app.candidate !== null);
  app.applyCandidate(); assert.equal(app.document.revision, before.revision + 1);
  assert.equal(app.document.nodes[0].text, 'AI整理后的知识');
  app.action({ kind: 'undo', nodeId: '', parentId: '', text: '', note: '' });
  assert.equal(app.document.nodes[0].text, before.nodes[0].text); assert.equal(app.document.revision, before.revision + 2);
});

test('actual request builder scopes selected branch/default root and crops context without mutating local history', async () => {
  for (const selected of ['', 'branch']) {
    const doc = createDocument('长历史导图');
    doc.nodes.push({ id: 'branch', parentId: doc.rootId, order: 0, text: '分支', note: '', collapsed: false });
    doc.messages = Array.from({ length: 50 }, (_, i) => ({ id: 'history-' + i, role: i % 2 ? 'assistant' : 'user',
      content: '中'.repeat(1500), createdAt: doc.createdAt }));
    const { app, calls } = await appHarness({ seed: [doc] });
    app.selectedNodeId = selected;
    await app.generate('继续扩充');
    const request = calls[0].request;
    assert.equal(request.scopeNodeId, selected || doc.rootId);
    assert.ok(request.messages.length <= 20);
    assert.ok(request.messages.reduce((sum, message) => sum + message.content.length, 0) <= 24000);
    assert.deepEqual(request.messages, request.document.messages);
    validateRequest(request);
    assert.equal(app.session.document.messages.length, 51);
    assert.deepEqual(app.session.document.messages.slice(0, 50), doc.messages);
    assert.equal(app.session.document.sourceText, doc.sourceText);
    assert.equal(app.session.document.documentId, doc.documentId);
  }
});

test('connection status distinguishes unconfigured gateway, configuration-only success and unreachable service', async () => {
  const { app, client } = await appHarness();
  await app.checkConnection(); assert.match(app.connectionMessage, /尚未配置/);
  client.healthStatus = { configured: true, model: 'configured-only-model', message: '尚未验证真实供应商' };
  await app.checkConnection(); assert.match(app.connectionMessage, /configured-only-model/); assert.match(app.connectionMessage, /实际调用将在生成时验证/);
  client.health = async () => { throw new Error('后端不可达'); };
  await app.checkConnection(); assert.match(app.connectionMessage, /连接失败.*后端不可达/);
});
