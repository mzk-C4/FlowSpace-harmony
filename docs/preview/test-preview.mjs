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
  assert.match(app.get('#map-svg').innerHTML, /fill="#B1AEFF"/);
  app.run("settings.themeMode='light';applyTheme()");
  assert.equal(app.theme(), 'light');
  app.run("page='diy';applyTheme()");
  assert.match(app.get('#map-svg').innerHTML, /fill="#5354C7"/);
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
