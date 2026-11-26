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

function runtime({ width = 390, height = 330, initialDocuments, osDark = false } = {}) {
  const elements = new Map(), saved = new Map(), urls = new Map(), downloads = [], listeners = new Map(), classes = new Set();
  const darkMedia = { matches: osDark, addEventListener(name, callback) { this.onChange = callback; } };
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
    addEventListener(name, callback) { listeners.set(name, callback); },
    documentElement: { dataset: {}, classList: { toggle(name, enabled) { if (enabled) classes.add(name); else classes.delete(name); } } },
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
    matchMedia: () => darkMedia,
    requestAnimationFrame: fn => fn(), setTimeout: () => 0, clearTimeout() {},
    console, URL: BlobURL, Blob, Date, Math, AbortController,
    fetch: async () => { networkCalls++; throw Error('Unexpected network request'); }
  });
  vm.runInContext(script, context, { filename: 'preview/index.html#script' });
  return {
    run: source => vm.runInContext(source, context),
    get: selector => document.querySelector(selector),
    saved, downloads, networkCalls: () => networkCalls,
    dispatch: (name, event) => listeners.get(name)?.(event),
    theme: () => document.documentElement.dataset.theme,
    hasClass: name => classes.has(name),
    setOSDark(value) { darkMedia.matches = value; darkMedia.onChange?.(); }
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

test('the example remains directly usable offline even after deleting all documents', async () => {
  const app = runtime({ initialDocuments: [] });
  app.run('openExample()');
  assert.equal(app.run('page'), 'diy');
  assert.equal(app.run('docs.length'), 1);
  assert.equal(app.run('current.nodes.length'), 10);
  assert.equal(app.run('current.title'), '信号与系统');
  app.run("applyEdit(()=>append(current,current.rootId,'本地编辑'))");
  assert.equal(app.run('current.nodes.length'), 11);
  app.run('undo()');
  assert.equal(app.run('current.nodes.length'), 10);
  await app.run("exportDoc('json')");
  assert.equal(JSON.parse(await app.downloads.at(-1).blob.text()).format, 'flowspace-mindmap');
  assert.equal(app.networkCalls(), 0);
});

test('the explicit example matches native data exactly and reopens edited or imported copies without duplication', async () => {
  const envelope = JSON.parse(readFileSync(new URL('../../entry/src/main/resources/rawfile/example-mindmap.json', import.meta.url), 'utf8').replace(/^\uFEFF/, ''));
  const app = runtime();
  const previous = app.run('JSON.stringify(docs)');
  app.run('openExample()');
  const opened = JSON.parse(app.run('JSON.stringify(current)'));
  assert.equal(opened.title, envelope.document.title);
  assert.equal(opened.rootId, envelope.document.rootId);
  assert.deepEqual(opened.nodes, envelope.document.nodes, 'IDs, text, note, parents, order and collapsed flags must match the rawfile');
  assert.equal(opened.sourceText, envelope.document.sourceText);
  assert.deepEqual(JSON.parse(app.run("JSON.stringify(docs.filter(d=>d.rootId!==NATIVE_EXAMPLE.rootId))")), JSON.parse(previous), 'Existing browser documents are retained unchanged');
  app.run("applyEdit(()=>{current.nodes[1].text='我的信号复习';current.title='重命名后的示例'})");
  const editedId = app.run('current.documentId'), count = app.run('docs.length');
  app.run('switchPage(\'home\');openExample()');
  assert.equal(app.run('current.documentId'), editedId);
  assert.equal(app.run('current.nodes[1].text'), '我的信号复习');
  assert.equal(app.run('docs.length'), count);
  await app.run("exportDoc('json')");
  const nativeRestored = nativeBackupService().parseBackup(await app.downloads.at(-1).blob.text());
  assert.equal(nativeRestored.nodes[1].text, '我的信号复习');
  const nativeText = nativeBackupService().serialize(envelope.document);
  await app.get('#import-file').onchange({ target: { value: 'native-example.json', files: [{ size: Buffer.byteLength(nativeText), text: async () => nativeText }] } });
  const importedId = app.run('current.documentId');
  app.run("applyEdit(()=>{current.nodes[1].note='导入后继续编辑';current.updatedAt='2099-01-01T00:00:00.000Z'})");
  // Give the imported copy a deterministic later saved timestamp for newest-copy selection.
  app.run("docs.find(d=>d.documentId===current.documentId).updatedAt='2099-01-01T00:00:00.000Z'");
  const afterImportCount = app.run('docs.length');
  app.run('openExample()');
  assert.equal(app.run('current.documentId'), importedId);
  assert.equal(app.run('current.nodes[1].note'), '导入后继续编辑');
  assert.equal(app.run('docs.length'), afterImportCount);
  assert.equal(app.networkCalls(), 0);
});

test('deleting the signal example keeps it absent through restart until the example button is pressed', () => {
  const app = runtime({ initialDocuments: [] });
  app.run('openExample();removeDoc(current.documentId)');
  app.get('#delete-doc').onclick();
  assert.equal(app.run('docs.length'), 0);
  const restarted = runtime({ initialDocuments: JSON.parse(app.saved.get('flowspace.preview.documents')) });
  assert.equal(restarted.run('docs.length'), 0);
  restarted.run('renderRecent();renderDocuments()');
  assert.equal(restarted.run('docs.length'), 0);
  restarted.run('openExample()');
  assert.equal(restarted.run('current.title'), '信号与系统');
  assert.equal(restarted.run('current.nodes.length'), 10);
  assert.equal(restarted.run('docs.length'), 1);
});

test('keyboard shortcuts run actual actions while preserving text editing and IME composition', () => {
  const app = runtime();
  let prevented = 0;
  const event = data => ({ key: '', target: { tagName: 'DIV' }, preventDefault() { prevented++; }, ...data });
  app.get('#prompt').value = '键盘创建导图';
  app.dispatch('keydown', event({ key: 'Enter', ctrlKey: true, target: { tagName: 'TEXTAREA', id: 'prompt' } }));
  assert.equal(app.run('page'), 'diy');
  const count = app.run('current.nodes.length');
  app.run("applyEdit(()=>append(current,current.rootId,'键盘撤销示例'))");
  app.dispatch('keydown', event({ key: 'z', ctrlKey: true, target: { tagName: 'INPUT' } }));
  assert.equal(app.run('current.nodes.length'), count + 1, 'Text fields retain their own native undo behavior');
  app.dispatch('keydown', event({ key: 'z', metaKey: true }));
  assert.equal(app.run('current.nodes.length'), count);
  app.dispatch('keydown', event({ key: 'z', metaKey: true, shiftKey: true }));
  assert.equal(app.run('current.nodes.length'), count + 1);
  app.get('#chat-input').value = '键盘修改';
  app.dispatch('keydown', event({ key: 'Enter', isComposing: true, target: { tagName: 'INPUT', id: 'chat-input' } }));
  assert.equal(app.run('candidate'), null, 'Chinese IME confirmation must not send a message');
  app.dispatch('keydown', event({ key: 'Enter', target: { tagName: 'INPUT', id: 'chat-input' } }));
  assert.equal(app.run('candidate.text'), '键盘修改');
  const revision = app.run('current.revision');
  app.run('openEditorMenu()');
  app.dispatch('keydown', event({ key: 'z', ctrlKey: true }));
  assert.equal(app.run('current.revision'), revision, 'An open modal owns keyboard input');
  assert.equal(prevented, 4);
});

test('theme selection, system dark changes and reduced motion update rendering and saved preferences', () => {
  const app = runtime({ osDark: true });
  assert.equal(app.theme(), 'dark');
  assert.match(app.get('#map-svg').innerHTML, /class="graph-node/);
  app.run("settings.themeMode='light';applyTheme()");
  assert.equal(app.theme(), 'light');
  app.run("page='diy';applyTheme()");
  assert.match(app.get('#map-svg').innerHTML, /class="graph-node/);
  app.run("settings.themeMode='system';applyTheme()");
  app.setOSDark(false);
  assert.equal(app.theme(), 'light');
  app.setOSDark(true);
  assert.equal(app.theme(), 'dark');
  app.run('toggleMotion()');
  assert.equal(app.hasClass('reduce-motion'), true);
  assert.equal(app.get('#reduce-motion').getAttribute('aria-checked'), 'true');
  assert.equal(JSON.parse(app.saved.get('flowspace.preview.settings')).reduceMotion, true);
  app.run('toggleMotion()');
  assert.equal(app.hasClass('reduce-motion'), false);
});

test('Apple-style page contracts remove promotional chrome and keep small-screen and desktop alternatives', () => {
  assert.match(html, /--bg:#F5F5F7;--surface:#FFFFFF;--text:#1D1D1F/);
  assert.match(html, /--accent:#5354C7/);
  assert.match(html, /html\[data-theme=dark\]\{--bg:#101114;--surface:#1C1D22/);
  assert.match(html, /--accent:#B1AEFF/);
  assert.match(html, /<h1>新建思维导图<\/h1>/);
  assert.doesNotMatch(html, /A LITTLE CLARITY|A GOOD PLACE TO BEGIN|让想法<br>|class="desktop-note"|class="screen-label"/);
  assert.match(html, /grid-template-columns:minmax\(0,1fr\) 300px/);
  assert.match(html, /@media\(max-width:760px\)/);
  assert.match(html, /\.editor-grid\{display:block\}/);
  assert.match(html, /\.chip\.active\{background:var\(--surface\)/);
  assert.match(html, /role="group" aria-roledescription="思维导图"/);
  const app = runtime({ width: 320, height: 260 });
  app.run('openExample();fitMap()');
  const fitted = JSON.parse(app.run('JSON.stringify({zoom,pan,bounds})'));
  assert.ok(fitted.pan.x + fitted.bounds.w * fitted.zoom <= 320);
  assert.ok(fitted.pan.y + fitted.bounds.h * fitted.zoom <= 260);
  app.run('openEditorMenu()');
  assert.match(app.get('#dialog-content').innerHTML, /删除选中分支/);
});

test('library search matches license and language with multiple terms and reset restores the full catalog', () => {
  const app = runtime();
  app.get('#resource-search').value = 'BSD 英语';
  app.run('renderResources()');
  assert.equal(app.get('#resource-count').textContent, '3 项资料');
  assert.match(app.get('#resource-list').innerHTML, /NumPy/);
  assert.doesNotMatch(app.get('#resource-list').innerHTML, /Think DSP/);
  app.run("filter='电子';renderResources()");
  assert.match(app.get('#resource-list').innerHTML, /没有匹配/);
  app.run('resetResources()');
  assert.equal(app.get('#resource-count').textContent, '13 项资料');
  assert.equal(app.get('#resource-reset').hidden, true);
});

test('library details show verification date, separate code license and title-only generation boundary', () => {
  const app = runtime();
  app.run("openResource('d2l')");
  assert.match(app.get('#dialog-content').innerHTML, /2026-11-23|资料详情/);
  const body = app.get('#dialog-content').innerHTML;
  assert.match(body, /LICENSE-SAMPLECODE/);
  assert.match(body, /不会读取原站全文/);
  app.get('#resource-topic').onclick();
  assert.equal(app.run('page'), 'home');
  assert.match(app.get('#prompt').value, /动手学深度学习/);
  assert.match(app.get('#prompt').value, /没有读取原站全文/);
});

test('free placement fields are optional, validated and never required by legacy documents', () => {
  const app = runtime();
  assert.equal(app.run('validate(current)'), true);
  assert.equal(app.run("(()=>{const d=clone(current);d.placement='free';d.positions={};d.nodes.forEach((n,i)=>d.positions[n.id]={x:i*10,y:i*20});return validate(d)})()"), true);
  for (const code of [
    "d.placement='manual'",
    "d.placement='free';d.positions={ghost:{x:1,y:2}}",
    "d.placement='free';d.positions={};d.positions[d.rootId]={x:'1',y:2}",
    "d.placement='free';d.positions={};d.positions[d.rootId]={x:100001,y:0}",
    "d.placement='free';d.positions=[]"
  ]) {
    assert.throws(() => app.run(`(()=>{const d=clone(current);${code};return validate(d)})()`), /位置|布局/);
  }
});

test('free coordinates drive the visible scene and missing nodes fall back to auto layout', () => {
  const app = runtime();
  app.run('openExample()');
  const ids = JSON.parse(app.run('JSON.stringify(current.nodes.map(n=>n.id))'));
  app.run("current.placement='free';current.positions={};current.nodes.forEach((n,i)=>current.positions[n.id]={x:i*300+5,y:i*200+7})");
  const coords = JSON.parse(app.run('JSON.stringify(sceneCoords(current,false).map(p=>[p.node.id,p.x,p.y]))'));
  assert.equal(coords.length, ids.length);
  for (const [id, x, y] of coords) {
    const index = ids.indexOf(id);
    assert.equal(x, index * 300 + 5);
    assert.equal(y, index * 200 + 7);
  }
  app.run("delete current.positions[current.nodes[2].id]");
  const fallback = JSON.parse(app.run('JSON.stringify(sceneCoords(current,false).map(p=>[p.node.id,p.x,p.y]))'));
  const missing = fallback.find(([id]) => id === ids[2]);
  assert.ok(missing, 'the node without coordinates must still be rendered');
  assert.ok(Number.isFinite(missing[1]) && Number.isFinite(missing[2]));
});

test('free placement snapshots every node, including collapsed descendants', () => {
  const app = runtime();
  app.run('openExample();current.nodes.find(n=>n.id===current.rootId).collapsed=true');
  assert.equal(JSON.parse(app.run('JSON.stringify(sceneCoords(current,true))')).length, 10);
  assert.equal(JSON.parse(app.run('JSON.stringify(sceneCoords(current,false))')).length, 1);
  const positions = JSON.parse(app.run('JSON.stringify(freePositions(current))'));
  assert.equal(Object.keys(positions).length, 10);
  for (const value of Object.values(positions)) {
    assert.ok(Number.isFinite(value.x) && Number.isFinite(value.y));
  }
});

test('dragging a branch moves its subtree rigidly and commits one undoable revision', () => {
  const app = runtime();
  app.run('openExample()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const before = JSON.parse(app.run('JSON.stringify(Object.fromEntries(sceneCoords(current,false).map(p=>[p.node.id,{x:p.x,y:p.y}])))'));
  const revision = app.run('current.revision');
  const start = before[branch.id];
  app.run(`beginNodeDrag('${branch.id}', ${start.x}, ${start.y})`);
  app.run(`moveNodeDrag(${start.x + 80}, ${start.y + 40})`);
  app.run('endNodeDrag(false)');
  assert.equal(app.run('current.placement'), 'free');
  assert.equal(app.run('selected'), branch.id);
  assert.equal(app.run('current.revision'), revision + 1);
  const after = JSON.parse(app.run('JSON.stringify(current.positions)'));
  const subtree = JSON.parse(app.run(`JSON.stringify([...subtreeIds(current,'${branch.id}')])`));
  for (const id of subtree) {
    assert.ok(after[id], `missing position for ${id}`);
    assert.equal(after[id].x, before[id].x + 80);
    assert.equal(after[id].y, before[id].y + 40);
  }
  app.run('undo()');
  assert.equal(app.run('Object.prototype.hasOwnProperty.call(current,"positions")'), false);
  assert.equal(app.run('Object.prototype.hasOwnProperty.call(current,"placement")'), false);
});

test('releasing a 2D drag stops immediately without inertia', () => {
  const app = runtime();
  app.run('openExample()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const before = JSON.parse(app.run(`JSON.stringify(sceneCoords(current,false).find(p=>p.node.id==='${branch.id}'))`));
  app.run(`beginNodeDrag('${branch.id}', ${before.x}, ${before.y});moveNodeDrag(${before.x + 60}, ${before.y + 30});endNodeDrag()`);
  const after = JSON.parse(app.run(`JSON.stringify(current.positions['${branch.id}'])`));
  assert.ok(Math.abs(after.x - (before.x + 60)) <= 2, `x drifted from ${before.x + 60} to ${after.x}`);
  assert.ok(Math.abs(after.y - (before.y + 30)) <= 2, `y drifted from ${before.y + 30} to ${after.y}`);
});

test('3D dragging follows the pointer one-to-one through the inverse projection', () => {
  const app = runtime();
  app.run('openExample();viewMode="3d";drawMap()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const item = JSON.parse(app.run(`JSON.stringify(projectedItems3D().find(i=>i.node.id==='${branch.id}'))`));
  app.run(`beginNodeDrag3D('${branch.id}', ${item.x}, ${item.y});moveNodeDragScreen(60, 30)`);
  const moved = JSON.parse(app.run(`(() => { const state=nodeDrag, item=state.items.find(i=>i.id==='${branch.id}'); return JSON.stringify(projectNode3D({node:current.nodes.find(n=>n.id==='${branch.id}'),x:item.x,y:item.y,depth:item.depth}, state.projection)); })()`));
  assert.ok(Math.abs(moved.x - item.x - 60) <= 1, `projected x moved ${moved.x - item.x}, expected 60`);
  assert.ok(Math.abs(moved.y - item.y - 30) <= 1, `projected y moved ${moved.y - item.y}, expected 30`);
});

test('3D releasing a drag keeps the node where it was dropped, including the root', () => {
  const app = runtime();
  app.run('openExample();viewMode="3d";drawMap()');
  const rootId = app.run('current.rootId');
  const root = JSON.parse(app.run(`JSON.stringify(projectedItems3D().find(i=>i.node.id==='${rootId}'))`));
  app.run(`beginNodeDrag3D('${rootId}', ${root.x}, ${root.y});moveNodeDragScreen(100, 50);endNodeDrag(false)`);
  const droppedRoot = JSON.parse(app.run(`JSON.stringify(projectedItems3D().find(i=>i.node.id==='${rootId}'))`));
  assert.ok(Math.abs(droppedRoot.x - (root.x + 100)) <= 1.5, `root snapped from ${root.x + 100} to ${droppedRoot.x}`);
  assert.ok(Math.abs(droppedRoot.y - (root.y + 50)) <= 1.5, `root snapped from ${root.y + 50} to ${droppedRoot.y}`);

  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const item = JSON.parse(app.run(`JSON.stringify(projectedItems3D().find(i=>i.node.id==='${branch.id}'))`));
  app.run(`beginNodeDrag3D('${branch.id}', ${item.x}, ${item.y});moveNodeDragScreen(200, 100);endNodeDrag(false)`);
  const droppedBranch = JSON.parse(app.run(`JSON.stringify(projectedItems3D().find(i=>i.node.id==='${branch.id}'))`));
  assert.ok(Math.abs(droppedBranch.x - (item.x + 200)) <= 1.5, `branch snapped from ${item.x + 200} to ${droppedBranch.x}`);
  assert.ok(Math.abs(droppedBranch.y - (item.y + 100)) <= 1.5, `branch snapped from ${item.y + 100} to ${droppedBranch.y}`);
});

test('3D rendering keeps the dragged node under the pointer during a large drag', () => {
  const app = runtime();
  app.run('openExample();viewMode="3d";drawMap()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const item = JSON.parse(app.run(`JSON.stringify(projectedItems3D().find(i=>i.node.id==='${branch.id}'))`));
  app.run(`beginNodeDrag3D('${branch.id}', ${item.x}, ${item.y});moveNodeDragScreen(300, 150)`);
  const rendered = JSON.parse(app.run(`JSON.stringify(projectedItems3D().find(i=>i.node.id==='${branch.id}'))`));
  assert.ok(Math.abs(rendered.x - (item.x + 300)) <= 1.5, `rendered x ${rendered.x}, expected ${item.x + 300}`);
  assert.ok(Math.abs(rendered.y - (item.y + 150)) <= 1.5, `rendered y ${rendered.y}, expected ${item.y + 150}`);
});

test('cancelling a drag restores coordinates without writing a revision', () => {
  const app = runtime();
  app.run('openExample()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const before = JSON.parse(app.run('JSON.stringify(Object.fromEntries(sceneCoords(current,false).map(p=>[p.node.id,{x:p.x,y:p.y}])))'));
  const revision = app.run('current.revision');
  app.run(`beginNodeDrag('${branch.id}', ${before[branch.id].x}, ${before[branch.id].y})`);
  app.run(`moveNodeDrag(${before[branch.id].x + 120}, ${before[branch.id].y + 60})`);
  app.run('cancelNodeDrag()');
  assert.equal(app.run('current.revision'), revision);
  assert.equal(app.run('Object.prototype.hasOwnProperty.call(current,"positions")'), false);
  const after = JSON.parse(app.run('JSON.stringify(Object.fromEntries(sceneCoords(current,false).map(p=>[p.node.id,{x:p.x,y:p.y}])))'));
  assert.deepEqual(after, before);
});

test('collision resolution separates overlapping nodes with the minimum gap and scales to 500 nodes', () => {
  const app = runtime();
  const items = JSON.parse(app.run("(()=>{const items=[{id:'a',x:0,y:0,w:150,h:44},{id:'b',x:20,y:10,w:150,h:44},{id:'c',x:400,y:300,w:150,h:44}];resolveCollisions(items,new Set(),8,12);return JSON.stringify(items)})()"));
  const separated = (p, q) => (p.w + q.w) / 2 + 12 - Math.abs((p.x + p.w / 2) - (q.x + q.w / 2)) <= 0.5 ||
    (p.h + q.h) / 2 + 12 - Math.abs((p.y + p.h / 2) - (q.y + q.h / 2)) <= 0.5;
  for (let i = 0; i < items.length; i++) {
    for (let j = i + 1; j < items.length; j++) {
      assert.ok(separated(items[i], items[j]), `${items[i].id}/${items[j].id} still overlaps`);
    }
  }
  const started = Date.now();
  const overlaps = app.run("(()=>{const items=[];for(let i=0;i<500;i++)items.push({id:'n'+String(i).padStart(3,'0'),x:(i%25)*220,y:Math.floor(i/25)*80,w:150,h:44});items[0].x=items[1].x+10;items[0].y=items[1].y+5;for(let frame=0;frame<10;frame++)resolveCollisions(items,new Set(),4,12);let bad=0;for(let i=0;i<items.length;i++)for(let j=i+1;j<items.length;j++){const p=items[i],q=items[j];if((p.w+q.w)/2+12-Math.abs((p.x+p.w/2)-(q.x+q.w/2))>0.5&&(p.h+q.h)/2+12-Math.abs((p.y+p.h/2)-(q.y+q.h/2))>0.5)bad++}return bad})()");
  assert.equal(overlaps, 0);
  assert.ok(Date.now() - started < 3000, 'collision resolution must stay usable at 500 nodes');
});

test('released drag settles within the frame budget and keeps coordinates finite', () => {
  const app = runtime();
  app.run('openExample()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const start = JSON.parse(app.run(`JSON.stringify(sceneCoords(current,false).find(p=>p.node.id==='${branch.id}'))`)).x;
  app.run(`beginNodeDrag('${branch.id}', ${start}, 0)`);
  app.run(`moveNodeDrag(${start + 400}, 200)`);
  app.run('endNodeDrag(false)');
  assert.ok(app.run('lastSettle.frames') <= 40);
  assert.equal(app.run('Object.values(current.positions).every(p=>Number.isFinite(p.x)&&Number.isFinite(p.y))'), true);
  assert.equal(app.run('Object.values(current.positions).every(p=>Math.abs(p.x)<=100000&&Math.abs(p.y)<=100000)'), true);
});

test('long-press menu exposes add, edit, reparent, delete and organize with root restrictions', () => {
  const app = runtime();
  app.run('openExample()');
  const rootId = app.run('current.rootId');
  const childId = app.run("current.nodes.find(n=>n.parentId===current.rootId).id");
  app.run(`openNodeMenu('${rootId}')`);
  let body = app.get('#dialog-content').innerHTML;
  assert.match(body, /添加子节点/);
  assert.match(body, /编辑/);
  assert.match(body, /整理布局/);
  assert.doesNotMatch(body, /删除分支/);
  assert.doesNotMatch(body, /改父级/);
  app.run(`openNodeMenu('${childId}')`);
  body = app.get('#dialog-content').innerHTML;
  assert.match(body, /添加同级节点/);
  assert.match(body, /改父级/);
  assert.match(body, /删除分支/);
});

test('adding a node in free mode places it beside its parent; reparenting keeps coordinates', () => {
  const app = runtime();
  app.run('openExample()');
  app.run("applyEdit(()=>{current.placement='free';current.positions=freePositions(current)})");
  const rootId = app.run('current.rootId');
  const childId = app.run("current.nodes.find(n=>n.parentId===current.rootId).id");
  const parentPosition = JSON.parse(app.run(`JSON.stringify(current.positions['${rootId}'])`));
  app.run(`selected='${rootId}';nodeDialog('addChild')`);
  app.get('#node-text').value = '自由模式新节点';
  app.get('#node-form').onsubmit({ preventDefault() {} });
  const added = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.text==='自由模式新节点'))"));
  const addedPosition = JSON.parse(app.run(`JSON.stringify(current.positions['${added.id}'])`));
  assert.ok(addedPosition.x > parentPosition.x);
  assert.ok(Number.isFinite(addedPosition.y));
  const before = JSON.parse(app.run(`JSON.stringify(current.positions['${childId}'])`));
  app.run(`moveNodeTo('${childId}','${added.id}')`);
  assert.equal(app.run(`current.nodes.find(n=>n.id==='${childId}').parentId`), added.id);
  assert.deepEqual(JSON.parse(app.run(`JSON.stringify(current.positions['${childId}'])`)), before);
});

test('3D centered layout keeps the root at the orbit center and spreads children to both sides', () => {
  const app = runtime();
  app.run('openExample();viewMode="3d";drawMap()');
  const projected = JSON.parse(app.run('JSON.stringify(projectedItems3D().map(i=>({id:i.node.id,parentId:i.node.parentId,x:i.x,y:i.y,z:i.z})))'));
  assert.equal(projected.length, 10);
  const rootId = app.run('current.rootId');
  const root = projected.find(p => p.id === rootId);
  assert.ok(Math.abs(root.x) <= 0.5 && Math.abs(root.y) <= 0.5, 'root must project to the orbit center');
  const children = projected.filter(p => p.parentId === rootId).map(p => p.x);
  assert.ok(children.some(x => x < 0) && children.some(x => x > 0), 'first-level branches must use both sides');
  assert.ok(projected.some(p => p.z !== 0), 'depth must vary by level');
});

test('2D/3D toggle opens a readable 3D view and fit still shows the whole graph', () => {
  const app = runtime();
  app.run('openExample()');
  assert.equal(app.run('viewMode'), '2d');
  app.run('toggleViewMode()');
  assert.equal(app.run('viewMode'), '3d');
  assert.equal(app.get('#view-toggle').textContent, '3D');
  assert.equal(app.get('#reset-view').hidden, false);
  const view = JSON.parse(app.run('JSON.stringify({zoom,pan,bounds})'));
  const fitZoom = Math.min(1.15, (390 - 25) / view.bounds.w, (330 - 65) / view.bounds.h);
  assert.ok(view.zoom > fitZoom + 0.02, '3D starts closer than fit so circles and labels stay readable');
  assert.ok(Math.abs(view.pan.x - 195) <= 2 && Math.abs(view.pan.y - 165) <= 2, 'the root stays centered');
  app.run('fitMap()');
  const fitted = JSON.parse(app.run('JSON.stringify({zoom,pan,bounds})'));
  assert.ok(fitted.pan.x + fitted.bounds.minX * fitted.zoom >= -1);
  assert.ok(fitted.pan.y + fitted.bounds.minY * fitted.zoom >= -1);
  assert.ok(fitted.pan.x + (fitted.bounds.minX + fitted.bounds.w) * fitted.zoom <= 391);
  assert.ok(fitted.pan.y + (fitted.bounds.minY + fitted.bounds.h) * fitted.zoom <= 331);
  app.run('toggleViewMode()');
  assert.equal(app.run('viewMode'), '2d');
  assert.equal(app.get('#view-toggle').textContent, '2D');
  assert.equal(app.get('#reset-view').hidden, true);
});

test('3D graph uses colored circles, relation labels and a faded depth layer', () => {
  const app = runtime();
  app.run('openExample();viewMode="3d";drawMap()');
  const svg = app.get('#map-svg').innerHTML;
  assert.match(svg, /class="graph-node/);
  assert.match(svg, /class="graph-link/);
  assert.match(svg, /包含/, 'tree edges carry a default relation label');
  assert.ok((svg.match(/class="ghost-node/g) || []).length >= 10, 'a faded duplicate layer supplies depth');
  const colors = JSON.parse(app.run('JSON.stringify([...new Set(current.nodes.filter(n=>n.parentId===current.rootId).map(n=>nodeColor(current,n.id)))])'));
  assert.ok(colors.length >= 2, 'first-level branches use different colors');
});

test('optional relation links are validated and drawn as labeled cross-links', () => {
  const app = runtime();
  assert.equal(app.run('validate(current)'), true);
  assert.equal(app.run("(()=>{const d=clone(current);d.links=[{from:d.rootId,to:d.nodes[1].id,label:'包含'}];return validate(d)})()"), true);
  for (const code of [
    "d.links=[{from:d.rootId,to:'missing',label:'关联'}]",
    "d.links=[{from:d.rootId,to:d.rootId,label:'关联'}]",
    "d.links=[{from:d.rootId,to:d.nodes[1].id,label:'x'.repeat(41)}]",
    "d.links={}"
  ]) {
    assert.throws(() => app.run(`(()=>{const d=clone(current);${code};return validate(d)})()`), /关系|links|链接/);
  }
  app.run('openExample()');
  const children = JSON.parse(app.run('JSON.stringify(current.nodes.filter(n=>n.parentId===current.rootId).map(n=>n.id))'));
  app.run(`current.links=[{from:'${children[0]}',to:'${children[1]}',label:'跨分支关系'}]`);
  app.run('viewMode="3d";drawMap()');
  const svg = app.get('#map-svg').innerHTML;
  assert.match(svg, /跨分支关系/);
  assert.match(svg, /graph-link extra/);
});

test('3D projection renders every node, hits the top card and stays within fit bounds', () => {
  const app = runtime();
  app.run('openExample();viewMode="3d";drawMap()');
  const items = JSON.parse(app.run('JSON.stringify(projectedItems3D().map(i=>({id:i.node.id,x:i.x,y:i.y,z:i.z,w:i.w,h:i.h,scale:i.scale})))'));
  assert.equal(items.length, 10);
  for (const item of items) assert.ok([item.x, item.y, item.z, item.w, item.h, item.scale].every(Number.isFinite));
  assert.ok(items.some(item => item.scale !== 1), 'perspective must produce depth-dependent scale');
  const root = items.find(item => item.id === app.run('current.rootId'));
  assert.equal(app.run(`hitTest3D(${root.x}, ${root.y})`), root.id);
  app.run('fitMap()');
  const fitted = JSON.parse(app.run('JSON.stringify({zoom,pan,bounds})'));
  assert.ok(fitted.pan.x + fitted.bounds.minX * fitted.zoom >= -1);
  assert.ok(fitted.pan.y + fitted.bounds.minY * fitted.zoom >= -1);
  assert.ok(fitted.pan.x + (fitted.bounds.minX + fitted.bounds.w) * fitted.zoom <= 391);
  assert.ok(fitted.pan.y + (fitted.bounds.minY + fitted.bounds.h) * fitted.zoom <= 331);
});

test('the editor can add a demo set of cross-links and undo it', () => {
  const app = runtime();
  app.run('openExample()');
  const revision = app.run('current.revision');
  app.run('addRelationDemo()');
  assert.equal(app.run('Array.isArray(current.links)&&current.links.length>=2'), true);
  assert.equal(app.run('viewMode'), '3d');
  assert.equal(app.run('current.revision'), revision + 1);
  app.run('undo()');
  assert.equal(app.run('Object.prototype.hasOwnProperty.call(current,"links")'), false);
});

test('3D dragging lets descendants follow with a spring and settle back to their offsets', () => {
  const app = runtime();
  app.run('openExample();viewMode="3d";drawMap()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const child = JSON.parse(app.run(`JSON.stringify(current.nodes.find(n=>n.parentId==='${branch.id}'))`));
  const start = JSON.parse(app.run(`JSON.stringify(Object.fromEntries(centeredCoords(current,false).map(p=>[p.node.id,{x:p.x,y:p.y}])))`));
  const item = JSON.parse(app.run(`JSON.stringify(projectedItems3D().find(i=>i.node.id==='${branch.id}'))`));
  app.run(`beginNodeDrag3D('${branch.id}', ${item.x}, ${item.y})`);
  app.run('moveNodeDragScreen(70,35)');
  const during = JSON.parse(app.run('JSON.stringify(nodeDrag.items.map(i=>({id:i.id,x:i.x,y:i.y})))'));
  const parentDelta = Math.hypot(during.find(i => i.id === branch.id).x - start[branch.id].x, during.find(i => i.id === branch.id).y - start[branch.id].y);
  const childDelta = Math.hypot(during.find(i => i.id === child.id).x - start[child.id].x, during.find(i => i.id === child.id).y - start[child.id].y);
  assert.ok(childDelta < parentDelta * 0.8, 'the descendant must lag behind the dragged node');
  assert.ok(childDelta > parentDelta * 0.5, 'the descendant must stay close enough to feel responsive');
  app.run('endNodeDrag(false)');
  const positions = JSON.parse(app.run('JSON.stringify(current.positions)'));
  const beforeOffset = { x: start[child.id].x - start[branch.id].x, y: start[child.id].y - start[branch.id].y };
  const afterOffset = { x: positions[child.id].x - positions[branch.id].x, y: positions[child.id].y - positions[branch.id].y };
  assert.ok(Math.abs(afterOffset.x - beforeOffset.x) <= 2 && Math.abs(afterOffset.y - beforeOffset.y) <= 2, `the spring must restore the original relative offset ${JSON.stringify({ beforeOffset, afterOffset })}`);
});

test('3D trackball rotation changes the orientation and reset restores the default', () => {
  const app = runtime();
  app.run('openExample();viewMode="3d";drawMap()');
  const before = app.run('JSON.stringify(rotation)');
  app.run('beginRotate3D();updateRotate3D(80,40)');
  assert.notEqual(app.run('JSON.stringify(rotation)'), before);
  app.run('resetView3D()');
  assert.equal(app.run('JSON.stringify(rotation)'), before);
});

test('dragging in 3D converts screen movement into plane coordinates and commits free positions', () => {
  const app = runtime();
  app.run('openExample();viewMode="3d";drawMap()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const item = JSON.parse(app.run(`JSON.stringify(projectedItems3D().find(i=>i.node.id==='${branch.id}'))`));
  const start = JSON.parse(app.run(`JSON.stringify(centeredCoords(current,false).find(p=>p.node.id==='${branch.id}'))`));
  const revision = app.run('current.revision');
  app.run(`beginNodeDrag3D('${branch.id}', ${item.x}, ${item.y})`);
  app.run('moveNodeDragScreen(70,35)');
  app.run('endNodeDrag(false)');
  assert.equal(app.run('current.placement'), 'free');
  assert.equal(app.run('current.revision'), revision + 1);
  const moved = JSON.parse(app.run(`JSON.stringify(current.positions['${branch.id}'])`));
  assert.ok(Number.isFinite(moved.x) && Number.isFinite(moved.y));
  assert.notEqual(moved.x, start.x);
  assert.notEqual(moved.y, start.y);
});

test('reduced motion commits the drag without running glide frames', () => {
  const app = runtime();
  app.run('openExample();settings.reduceMotion=true');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const start = JSON.parse(app.run(`JSON.stringify(sceneCoords(current,false).find(p=>p.node.id==='${branch.id}'))`)).x;
  app.run(`beginNodeDrag('${branch.id}', ${start}, 0);moveNodeDrag(${start + 130}, 40);endNodeDrag()`);
  assert.equal(app.run('lastSettle.frames'), 0);
  assert.equal(app.run('current.placement'), 'free');
});

test('organize clears free positions and one undo restores them', () => {
  const app = runtime();
  app.run('openExample()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const start = JSON.parse(app.run(`JSON.stringify(sceneCoords(current,false).find(p=>p.node.id==='${branch.id}'))`)).x;
  app.run(`beginNodeDrag('${branch.id}', ${start}, 0);moveNodeDrag(${start + 50}, 30);endNodeDrag(false)`);
  const saved = JSON.parse(app.run('JSON.stringify(current.positions)'));
  app.run('organizeLayout()');
  assert.equal(app.run('Object.prototype.hasOwnProperty.call(current,"positions")'), false);
  app.run('undo()');
  assert.deepEqual(JSON.parse(app.run('JSON.stringify(current.positions)')), saved);
});

test('JSON backups carry free positions through export and import, while legacy backups still open', async () => {
  const app = runtime();
  app.run('openExample()');
  const branch = JSON.parse(app.run("JSON.stringify(current.nodes.find(n=>n.parentId===current.rootId))"));
  const start = JSON.parse(app.run(`JSON.stringify(sceneCoords(current,false).find(p=>p.node.id==='${branch.id}'))`)).x;
  app.run(`beginNodeDrag('${branch.id}', ${start}, 0);moveNodeDrag(${start + 70}, 30);endNodeDrag(false)`);
  const saved = JSON.parse(app.run('JSON.stringify(current.positions)'));
  await app.run("exportDoc('json')");
  const backup = JSON.parse(await app.downloads.at(-1).blob.text());
  assert.deepEqual(backup.document.positions, saved);
  assert.equal(backup.document.placement, 'free');
  const before = app.run('docs.length');
  await app.get('#import-file').onchange({ target: { value: 'free.json', files: [{ size: 500, text: async () => JSON.stringify(backup) }] } });
  assert.equal(app.run('docs.length'), before + 1);
  assert.deepEqual(JSON.parse(app.run('JSON.stringify(current.positions)')), saved);
  const legacy = JSON.parse(JSON.stringify(backup));
  delete legacy.document.positions;
  delete legacy.document.placement;
  await app.get('#import-file').onchange({ target: { value: 'legacy.json', files: [{ size: 500, text: async () => JSON.stringify(legacy) }] } });
  assert.equal(app.run('Object.prototype.hasOwnProperty.call(current,"positions")'), false);
  assert.equal(app.run('validate(current)'), true);
});
