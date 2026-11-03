import test from 'node:test';
import assert from 'node:assert/strict';
import { stripTypeScriptTypes } from 'node:module';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const stage = mkdtempSync(join(tmpdir(), 'flowspace-domain-test-'));
for (const [source, target] of [['domain/MindMap', 'MindMap'], ['domain/DocumentSession', 'DocumentSession'], ['storage/ExportService', 'ExportService']]) {
  const text = readFileSync(join(root, 'entry/src/main/ets', source + '.ets'), 'utf8')
    .replace(/^import .* from '@ohos[^']+';\r?\n/gm, '')
    .replace(/from '(?:\.\/|\.\.\/domain\/)(MindMap|DocumentSession)'/g, "from './$1.mjs'")
    .replace(/import \{([^}]+)\}/g, (_, names) => 'import {' + names.split(',').map(n => n.trim())
      .filter(n => ['cloneDocument', 'newId', 'validateDocument', 'createDocument', 'defaultSettings'].includes(n)).join(',') + '}');
  writeFileSync(join(stage, target + '.mjs'), stripTypeScriptTypes(text, { mode: 'transform' }));
}
const { createDocument, cloneDocument } = await import(pathToFileURL(join(stage, 'MindMap.mjs')));
const { DocumentSession, validateDocument } = await import(pathToFileURL(join(stage, 'DocumentSession.mjs')));
const { exportService } = await import(pathToFileURL(join(stage, 'ExportService.mjs')));
test.after(() => rmSync(stage, { recursive: true, force: true }));

test('commands preserve immutable snapshots and undo/redo always increase revision', () => {
  const original = createDocument('中心');
  const s = new DocumentSession(original);
  const a = s.addNode(original.rootId, '分支一');
  assert.equal(original.nodes.length, 1);
  const before = cloneDocument(s.document);
  s.editNode(a, '更名', '备注');
  assert.equal(before.nodes[1].text, '分支一');
  s.undo(); assert.equal(s.document.revision, 3); assert.equal(s.document.nodes[1].text, '分支一');
  s.redo(); assert.equal(s.document.revision, 4); assert.equal(s.document.nodes[1].note, '备注');
  s.undo(); s.rename('新标题'); assert.equal(s.canRedo(), false);
});

test('subtree delete, sibling insertion and cycle rejection are atomic', () => {
  const s = new DocumentSession(createDocument());
  const a = s.addNode(s.document.rootId, 'A');
  const b = s.addNode(a, 'B');
  const sibling = s.addSibling(a, '同级');
  assert.equal(s.document.nodes.find(n => n.id === sibling).parentId, s.document.rootId);
  const before = JSON.stringify(s.document);
  assert.throws(() => s.moveNode(a, b), /循环/);
  assert.equal(JSON.stringify(s.document), before);
  assert.throws(() => s.removeNode(s.document.rootId));
  assert.throws(() => s.moveNode(s.document.rootId, a));
  s.removeNode(a); assert.equal(s.document.nodes.length, 2);
  s.undo(); assert.equal(s.document.nodes.length, 4);
});

test('reject ninth level and 501st node without changing document', () => {
  const s = new DocumentSession(createDocument());
  let parent = s.document.rootId;
  for (let i = 1; i < 8; i++) parent = s.addNode(parent, '层' + i);
  const before = JSON.stringify(s.document);
  assert.throws(() => s.addNode(parent, '第九层'), /8/);
  assert.equal(JSON.stringify(s.document), before);
  const large = createDocument();
  for (let i = 1; i < 500; i++) large.nodes.push({ id:'n' + i, parentId:large.rootId, order:i, text:'节点', note:'', collapsed:false });
  const full = new DocumentSession(large);
  assert.throws(() => full.addNode(large.rootId, '溢出'), /500/);
  assert.equal(full.document.nodes.length, 500);
});

test('invalid duplicate, missing parent, wrong root and malformed messages rejected', () => {
  for (const mutate of [
    d => d.nodes.push({...d.nodes[0]}),
    d => d.nodes[0].parentId = 'missing',
    d => d.rootId = 'missing',
    d => d.nodes[0].text = '',
    d => d.messages = [null],
    d => d.revision = 0.5,
    d => d.nodes = null,
  ]) {
    const doc = createDocument(); mutate(doc); assert.throws(() => validateDocument(doc));
  }
});

test('AI candidate validates base revision and groups all changes into one undo', () => {
  const s = new DocumentSession(createDocument());
  const candidate = cloneDocument(s.document);
  candidate.nodes.push({id:'ai', parentId:candidate.rootId, order:0,text:'AI分支',note:'',collapsed:false});
  s.applyCandidate({requestId:'request',baseRevision:0,document:candidate,summary:'新增分支'});
  assert.equal(s.document.revision,1);
  assert.throws(() => s.applyCandidate({requestId:'old',baseRevision:0,document:candidate,summary:''}), /已修改/);
  s.undo(); assert.equal(s.document.nodes.length, 1); assert.equal(s.document.revision,2);
  const wrong = cloneDocument(s.document); wrong.documentId = 'another';
  assert.throws(() => s.applyCandidate({requestId:'wrong',baseRevision:2,document:wrong,summary:''}), /其他导图/);
});

test('undo/redo and cropped AI candidates retain complete current conversations and source', () => {
  const s = new DocumentSession(createDocument('对话保留'));
  s.document.sourceText = '最初原文';
  const a = s.addNode(s.document.rootId, '第一分支');
  const now = new Date().toISOString();
  s.document.messages = Array.from({length:120}, (_,i) => ({id:'msg'+i,role:i%2 ? 'assistant' : 'user',content:'对话'+i,createdAt:now}));
  s.document.sourceText = '当前原文';
  s.editNode(a,'第二版','');
  const messages = structuredClone(s.document.messages);
  s.undo(); assert.deepEqual(s.document.messages,messages); assert.equal(s.document.sourceText,'当前原文');
  s.redo(); assert.deepEqual(s.document.messages,messages); assert.equal(s.document.sourceText,'当前原文');
  const candidate = cloneDocument(s.document);
  candidate.messages = candidate.messages.slice(-20);
  candidate.nodes[1].text = 'AI修改';
  s.applyCandidate({requestId:'cropped',baseRevision:s.document.revision,document:candidate,summary:'修改文字'});
  assert.equal(s.document.nodes[1].text,'AI修改');
  assert.deepEqual(s.document.messages,messages);
  s.undo(); assert.equal(s.document.nodes[1].text,'第二版'); assert.deepEqual(s.document.messages,messages);
  s.redo(); assert.equal(s.document.nodes[1].text,'AI修改'); assert.deepEqual(s.document.messages,messages);
});

test('local limits match AI-compatible fields while supporting long local conversation histories', () => {
  const accepted = createDocument();
  accepted.documentId = 'd'.repeat(128);
  accepted.nodes[0].text = '字'.repeat(500);
  accepted.sourceText = '文'.repeat(20000);
  accepted.messages = Array.from({length:1000}, (_,i) => ({id:'msg'+i,role:'user',content:'历史',createdAt:accepted.createdAt}));
  validateDocument(accepted);
  for (const mutate of [
    d => d.documentId = 'd'.repeat(129),
    d => d.nodes[0].text = '字'.repeat(501),
    d => d.nodes[0].id = 'n'.repeat(129),
    d => d.sourceText = '文'.repeat(20001),
    d => d.messages[0].content = '话'.repeat(20001),
    d => d.messages[0].role = 'system',
  ]) {
    const invalid=cloneDocument(accepted); mutate(invalid); assert.throws(() => validateDocument(invalid));
  }
});

test('JSON backup roundtrip creates new document ID and preserves content; malformed backups rejected', () => {
  const s = new DocumentSession(createDocument('测试备份'));
  s.addNode(s.document.rootId, '折叠分支');
  s.toggleCollapsed(s.document.rootId);
  const restored = exportService.parseBackup(exportService.serialize(s.document));
  assert.notEqual(restored.documentId, s.document.documentId);
  assert.equal(restored.revision,0);
  assert.deepEqual(restored.nodes,s.document.nodes);
  assert.throws(() => exportService.parseBackup('{}'));
  assert.throws(() => exportService.parseBackup('{invalid'));
  const corrupt = JSON.parse(exportService.serialize(s.document)); corrupt.document.nodes[1].parentId = 'missing';
  assert.throws(() => exportService.parseBackup(JSON.stringify(corrupt)));
});

test('Markdown contains all nodes despite collapsed state and preserves notes/source', () => {
  const s = new DocumentSession(createDocument('标题'));
  const a = s.addNode(s.document.rootId, '子节点');
  s.editNode(a, '子节点', '备注'); s.toggleCollapsed(s.document.rootId);
  s.document.sourceText = '原始长文';
  const text = exportService.markdown(s.document);
  assert.match(text, /子节点/); assert.match(text, /备注/); assert.match(text, /原始长文/);
});

test('PNG draws entire collapsed/offscreen graph in both layouts and caps raster at 4096', async () => {
  const drawn = [];
  let raster;
  let pixelReleased = false;
  let packerReleased = false;
  class Brush { setAntiAlias() {} setColor() {} }
  class Pen extends Brush { setStrokeWidth() {} }
  class Font { setSize() {} }
  class Canvas {
    clear() {} scale() {} attachPen() {} detachPen() {} attachBrush() {} detachBrush() {} drawRect() {} drawLine() {}
    drawTextBlob(blob) { drawn.push(blob); }
  }
  globalThis.drawing = {Brush, Pen, Font, Canvas, TextBlob:{makeFromString:text => text}};
  globalThis.image = {
    PixelMapFormat:{RGBA_8888:3},
    createPixelMap:async (_, options) => {raster = options.size; return {release:async () => {pixelReleased = true;}}},
    createImagePacker:() => ({packing:async () => new ArrayBuffer(8), release:async () => {packerReleased = true;}}),
  };
  const doc = createDocument('全图导出');
  doc.nodes[0].collapsed = true;
  for (let i=1;i<500;i++) doc.nodes.push({id:'wide'+i,parentId:doc.rootId,order:i,text:'节点'+i,note:'',collapsed:false});
  for (const orientation of ['right','down']) {
    doc.layout=orientation; drawn.length=0;
    await exportService.png(doc);
    assert.equal(drawn.length,501);
    assert.equal(Math.max(raster.width,raster.height),4096);
    assert.ok(drawn.includes('节点499'));
  }
  assert.ok(pixelReleased && packerReleased);
  delete globalThis.drawing; delete globalThis.image;
});
