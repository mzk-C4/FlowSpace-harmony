// Executes the script embedded in the delivered preview, not a second editor implementation.
// DOM stubs cannot validate browser layout, pointer feel, PNG encoding or native file pickers.
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';
import { validateDocument as validateContractDocument } from '../../backend/validation.mjs';

const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
assert.ok(script, 'The delivered single HTML file must contain its own script');

function runtime({ width = 390, height = 330, initialDocuments } = {}) {
  const elements = new Map(), saved = new Map(), urls = new Map(), downloads = [];
  let networkCalls = 0;
  if (initialDocuments) saved.set('flowspace.preview.documents', JSON.stringify(initialDocuments));
  const element = () => ({
    value: '', textContent: '', innerHTML: '', hidden: false, open: false, disabled: false,
    style: {}, dataset: {}, attributes: {}, classList: { toggle() {} },
    setAttribute(name, value) { this.attributes[name] = value; },
    getAttribute(name) { return this.attributes[name] ?? ''; },
    addEventListener() {}, querySelectorAll() { return []; }, focus() {},
    close() { this.open = false; }, showModal() { this.open = true; },
    click() {}, getBoundingClientRect() { return { width, height }; }, setPointerCapture() {}
  });
  const document = {
    querySelector(selector) {
      if (!elements.has(selector)) elements.set(selector, element());
      return elements.get(selector);
    },
    querySelectorAll() { return []; },
    documentElement: { dataset: {}, classList: { toggle() {} } },
    createElement(tag) {
      const node = element();
      if (tag === 'a') node.click = () => downloads.push({ name: node.download, blob: urls.get(node.href) });
      return node;
    }
  };
  class BlobURL extends URL {
    static createObjectURL(blob) { const url = `blob:test-${urls.size}`; urls.set(url, blob); return url; }
    static revokeObjectURL(url) { urls.delete(url); }
  }
  const context = vm.createContext({
    document, window: { scrollTo() {}, addEventListener() {} },
    localStorage: { getItem: key => saved.get(key) ?? null, setItem: (key, value) => saved.set(key, value) },
    matchMedia: () => ({ matches: false, addEventListener() {} }),
    requestAnimationFrame: fn => fn(), setTimeout: () => 0, clearTimeout() {},
    console, URL: BlobURL, Blob, Date, Math, AbortController,
    fetch: async () => { networkCalls++; throw Error('Unexpected network request'); }
  });
  vm.runInContext(script, context, { filename: 'preview/index.html#script' });
  return {
    run: source => vm.runInContext(source, context),
    get: selector => document.querySelector(selector),
    saved, downloads, networkCalls: () => networkCalls
  };
}

function nativeCatalog(relativePath, name) {
  const source = readFileSync(new URL(relativePath, import.meta.url), 'utf8');
  const array = source.match(new RegExp('export const ' + name + ':[^=]+= (\\[[\\s\\S]*?\\n\\]);'))?.[1];
  assert.ok(array, `Missing native catalog ${name}`);
  const ocw = source.match(/const OCW_LICENSE: string = ('[^']*');/);
  const data = vm.runInNewContext(array, ocw ? { OCW_LICENSE: vm.runInNewContext(ocw[1]) } : {});
  return JSON.parse(JSON.stringify(data));
}

// Execute the native service's actual pure backup methods. Only their ArkTS type
// annotations are removed; no separate copy of the envelope/restore algorithm is used.
function nativeBackupService() {
  const source = readFileSync(new URL('../../entry/src/main/ets/storage/ExportService.ets', import.meta.url), 'utf8');
  const start = source.indexOf('  serialize(doc:');
  const end = source.indexOf('\n  private async write(', start);
  assert.ok(start >= 0 && end > start, 'Native backup methods must be available for interoperability checks');
  const methods = source.slice(start, end).replaceAll(': MindMapDocument', '')
    .replaceAll(': BackupEnvelope', '').replaceAll(': string', '').replaceAll(' as BackupEnvelope', '');
  return vm.runInNewContext(`new (class { ${methods} })()`, {
    validateDocument: validateContractDocument,
    cloneDocument: doc => JSON.parse(JSON.stringify(doc)),
    newId: prefix => prefix + '_native_restored',
    backupBytes: text => Buffer.byteLength(text, 'utf8'),
    Date, JSON, Error
  });
}

test('offline preview starts without network and embeds the final native resource and video catalogs', () => {
  const app = runtime();
  assert.equal(app.networkCalls(), 0);
  assert.doesNotMatch(html, /<script[^>]+src=|<link[^>]+href=/i);
  assert.deepEqual(JSON.parse(app.run('JSON.stringify(resources)')),
    nativeCatalog('../../entry/src/main/ets/data/ResourceCatalog.ets', 'OPEN_RESOURCES'));
  assert.deepEqual(JSON.parse(app.run('JSON.stringify(videos)')),
    nativeCatalog('../../entry/src/main/ets/data/VideoCatalog.ets', 'VIDEO_RESOURCES'));
  assert.equal(app.run('resources.length'), 13);
  assert.equal(app.run('videos.length'), 8);
  assert.match(html, /离线演示/);
  assert.match(html, /不调用真实 AI/);
});

test('text input creates an explicitly identified demo document and survives browser storage serialization', () => {
  const app = runtime();
  app.get('#prompt').value = '线性代数\n向量空间\n矩阵变换';
  app.run('generateDemo()');
  assert.equal(app.run('page'), 'diy');
  assert.equal(app.run('current.nodes.length'), 4);
  assert.equal(app.run('current.sourceText'), '线性代数\n向量空间\n矩阵变换');
  assert.equal(app.run('validate(current)'), true);
  assert.match(app.run('current.messages[0].content'), /没有调用 AI/);
  const persisted = JSON.parse(app.saved.get('flowspace.preview.documents'));
  assert.equal(persisted[0].title, '线性代数');
  assert.equal(persisted[0].schemaVersion, 1);
  app.get('#prompt').value = '';
  const count = app.run('docs.length');
  app.run('generateDemo()');
  assert.equal(app.run('docs.length'), count, 'Empty input must not create a document');
});

test('actual editor actions, undo and redo preserve the tree and increase revisions monotonically', () => {
  const app = runtime();
  const original = app.run('JSON.stringify(current.nodes)');
  app.run("applyEdit(()=>append(current,current.rootId,'手工添加'))");
  assert.equal(app.run('current.nodes.length'), 11);
  assert.equal(app.run('current.revision'), 1);
  app.run('undo()');
  assert.equal(app.run('JSON.stringify(current.nodes)'), original);
  assert.equal(app.run('current.revision'), 2);
  app.run('redo()');
  assert.equal(app.run('current.nodes.length'), 11);
  assert.equal(app.run('current.revision'), 3);
  app.run('selected=current.rootId;toggleCollapse()');
  assert.equal(app.run('layoutTree().length'), 1);
  app.run('toggleCollapse();changeLayout()');
  assert.equal(app.run('layoutTree().length'), 11);
  assert.equal(app.run('current.layout'), 'down');
  assert.equal(app.run('validate(current)'), true);
});

test('conversation candidates require confirmation and stale candidates cannot overwrite later edits', () => {
  const app = runtime();
  app.get('#chat-input').value = '补充工程应用';
  app.run('chatDemo()');
  assert.equal(app.run('current.nodes.length'), 10, 'Preview alone must not mutate the diagram');
  assert.equal(app.run('candidate.text'), '补充工程应用');
  app.run('applyCandidate()');
  assert.equal(app.run('current.nodes.length'), 11);
  assert.equal(app.run('candidate'), null);
  app.run('undo()');
  assert.equal(app.run('current.nodes.length'), 10);
  app.get('#chat-input').value = '这条候选已经过期';
  app.run('chatDemo();current.revision++;applyCandidate()');
  assert.equal(app.run('current.nodes.length'), 10);
  assert.equal(app.run('candidate'), null);
  assert.match(app.get('#toast').textContent, /重新发起/);
});

test('actual JSON and Markdown exporters contain the full hierarchy, including collapsed nodes', async () => {
  const app = runtime();
  app.run('selected=current.rootId;toggleCollapse()');
  await app.run("exportDoc('json')");
  const jsonDownload = app.downloads.at(-1);
  assert.match(jsonDownload.name, /\.json$/);
  const backup = JSON.parse(await jsonDownload.blob.text());
  assert.equal(backup.format, 'flowspace-mindmap');
  assert.equal(backup.version, 1);
  assert.equal(backup.document.nodes.length, 10);
  assert.equal(backup.document.schemaVersion, 1);
  assert.ok(backup.document.nodes.some(node => node.text === '按下标访问'));
  const restoredByNative = nativeBackupService().parseBackup(await jsonDownload.blob.text());
  assert.equal(restoredByNative.nodes.length, 10);
  assert.notEqual(restoredByNative.documentId, backup.document.documentId);
  assert.equal(restoredByNative.revision, 0);
  await app.run("exportDoc('markdown')");
  const markdown = await app.downloads.at(-1).blob.text();
  assert.match(markdown, /^# 数据结构 · 线性结构/m);
  assert.match(markdown, /  - 按下标访问/);
  assert.match(markdown, /队列：先进先出/);
});

test('preview restores native wrapped backups, preserves legacy bare documents and rejects unknown envelope versions', async () => {
  const app = runtime(), native = nativeBackupService();
  const original = JSON.parse(app.run('JSON.stringify(current)'));
  original.nodes[1].text = '中'.repeat(500);
  original.revision = 17;
  const wrapped = native.serialize(original);
  await app.get('#import-file').onchange({ target: { value: 'native.json', files: [{ size: Buffer.byteLength(wrapped), text: async () => wrapped }] } });
  assert.equal(app.run('current.nodes[1].text.length'), 500);
  assert.equal(app.run('current.revision'), 0);
  assert.notEqual(app.run('current.documentId'), original.documentId);
  validateContractDocument(JSON.parse(app.run('JSON.stringify(current)')));
  const count = app.run('docs.length');
  const legacy = JSON.stringify(original);
  await app.get('#import-file').onchange({ target: { value: 'old.json', files: [{ size: Buffer.byteLength(legacy), text: async () => legacy }] } });
  assert.equal(app.run('docs.length'), count + 1);
  const invalid = JSON.stringify({ format: 'flowspace-mindmap', version: 2, document: original });
  await app.get('#import-file').onchange({ target: { value: 'future.json', files: [{ size: invalid.length, text: async () => invalid }] } });
  assert.equal(app.run('docs.length'), count + 1, 'Unknown envelope versions cannot be silently imported');
  assert.match(app.get('#toast').textContent, /不支持/);
});

test('manual node editing accepts 500 characters and exports a valid native document', async () => {
  const app = runtime();
  app.run("nodeDialog('edit')");
  assert.match(app.get('#dialog-content').innerHTML, /id="node-text" maxlength="500"/);
  app.get('#node-text').value = '中'.repeat(500);
  app.get('#node-note').value = '长节点说明';
  app.get('#node-form').onsubmit({ preventDefault() {} });
  assert.equal(app.run('selectedNode().text.length'), 500);
  assert.equal(app.run('current.title.length'), 200, 'The separate native document-title limit remains 200');
  validateContractDocument(JSON.parse(app.run('JSON.stringify(current)')));
  await app.run("exportDoc('json')");
  const restoredByNative = nativeBackupService().parseBackup(await app.downloads.at(-1).blob.text());
  assert.equal(restoredByNative.nodes.find(node => node.id === restoredByNative.rootId).text.length, 500);
  assert.throws(() => app.run("(()=>{const tooLong=clone(current);tooLong.nodes[0].text='中'.repeat(501);validate(tooLong)})()"), /节点格式/);
});

test('oversized JSON backups are stopped before download using the same native 8MB limit', async () => {
  const app = runtime();
  app.run("current=makeDoc('超大备注');for(let i=0;i<499;i++)append(current,current.rootId,'节点');current.nodes.forEach(node=>node.note='中'.repeat(10000))");
  await app.run("exportDoc('json')");
  assert.equal(app.downloads.length, 0);
  assert.match(app.get('#toast').textContent, /超过 8MB/);
  assert.throws(() => nativeBackupService().serialize(JSON.parse(app.run('JSON.stringify(current)'))), /超过 8MB/);
});

test('JSON restore validates before saving, allocates a fresh document ID and keeps original documents', async () => {
  const app = runtime();
  const backup = app.run('JSON.stringify(current)'), oldId = app.run('current.documentId');
  const oldCount = app.run('docs.length');
  await app.get('#import-file').onchange({ target: { value: 'backup.json', files: [{ size: backup.length, text: async () => backup }] } });
  assert.notEqual(app.run('current.documentId'), oldId);
  assert.equal(app.run('docs.length'), oldCount + 1);
  assert.equal(app.run('current.nodes.length'), 10);
  const stable = app.run('JSON.stringify(docs)');
  const invalid = JSON.parse(backup);
  invalid.nodes[1].parentId = invalid.nodes[1].id;
  const event = { target: { value: 'bad.json', files: [{ size: 400, text: async () => JSON.stringify(invalid) }] } };
  await app.get('#import-file').onchange(event);
  assert.equal(app.run('JSON.stringify(docs)'), stable);
  assert.equal(event.target.value, '');
  assert.match(app.get('#toast').textContent, /恢复失败/);
  assert.throws(() => app.run("(()=>{const bad=clone(current);bad.nodes[1].id='bad'+String.fromCharCode(34)+'id';validate(bad)})()"), /节点格式/);
});

test('empty user libraries remain empty after startup instead of restoring sample documents', () => {
  const app = runtime({ initialDocuments: [] });
  assert.equal(app.run('docs.length'), 0);
  assert.match(app.get('#recent-list').innerHTML, /还没有导图/);
  assert.deepEqual(JSON.parse(app.saved.get('flowspace.preview.documents')), []);
});

test('resource search filters actual entries and all public resource destinations use HTTPS', () => {
  const app = runtime();
  app.get('#resource-search').value = 'FreeRTOS';
  app.run('renderResources()');
  assert.match(app.get('#resource-list').innerHTML, /FreeRTOS/);
  assert.doesNotMatch(app.get('#resource-list').innerHTML, /Think DSP/);
  app.get('#resource-search').value = '没有这个资源';
  app.run('renderResources()');
  assert.match(app.get('#resource-list').innerHTML, /没有匹配/);
  assert.equal(app.run("[...resources,...videos].every(r=>new URL(r.url).protocol==='https:')"), true);
});

test('fit-to-canvas keeps 500 nodes of 500 Chinese characters and eight levels inside mobile bounds', () => {
  for (const width of [320, 360, 390, 480]) {
    for (const layout of ['right', 'down']) {
      const app = runtime({ width, height: 330 });
      app.run("current=makeDoc('最大合法导图');current.nodes[0].text='中'.repeat(500);let parent=current.rootId;for(let i=0;i<6;i++)parent=append(current,parent,'中'.repeat(500));for(let i=0;i<493;i++)append(current,parent,'中'.repeat(500))");
      app.run(`current.layout='${layout}';renderEditor();fitMap()`);
      assert.equal(app.run('validate(current)'), true);
      validateContractDocument(JSON.parse(app.run('JSON.stringify(current)')));
      assert.equal(app.run('current.nodes.length'), 500);
      assert.equal(app.run('current.nodes.every(node=>node.text.length===500)'), true);
      const result = JSON.parse(app.run('JSON.stringify({zoom,pan,bounds})'));
      assert.ok(result.zoom > 0 && Number.isFinite(result.zoom));
      assert.ok(result.pan.x >= 0, `${width}px / ${layout}: left edge`);
      assert.ok(result.pan.y >= 0, `${width}px / ${layout}: top edge`);
      assert.ok(result.pan.x + result.bounds.w * result.zoom <= width, `${width}px / ${layout}: right edge`);
      assert.ok(result.pan.y + result.bounds.h * result.zoom <= 330, `${width}px / ${layout}: bottom edge`);
      assert.notEqual(app.get('#zoom-label').textContent, '0%');
      app.run('zoom=.000001;updateTransform();zoomBy(.1)');
      assert.equal(app.run('zoom'), .000001);
      assert.equal(app.get('#zoom-label').textContent, '<0.1%');
    }
  }
});

test('static mobile contracts include four tabs, keyboard-safe controls and no zoom prohibition', () => {
  assert.equal([...html.matchAll(/class="nav-item[^\"]*" data-page=/g)].length, 4);
  assert.match(html, /viewport-fit=cover/);
  assert.doesNotMatch(html, /user-scalable\s*=\s*no|maximum-scale\s*=\s*1/i);
  assert.match(html, /@media\(max-width:360px\)/);
  assert.match(html, /@media\(pointer:coarse\)\{input,textarea,select\{font-size:16px!important;min-height:44px\}/);
  assert.match(html, /max-height:85dvh/);
  assert.match(html, /env\(safe-area-inset-bottom\)/);
  assert.match(html, /prefers-reduced-motion:reduce/);
});
