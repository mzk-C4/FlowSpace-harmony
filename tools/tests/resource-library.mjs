// Execute the real native catalog and LibraryPage event methods. ArkUI rendering is
// verified separately in SDK Previewer; these tests do not emulate a browser/device.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
const root = new URL('../../', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');
const moduleURL = text => 'data:text/javascript;base64,' + Buffer.from(stripTypeScriptTypes(text, { mode: 'transform' })).toString('base64');
const catalogURL = moduleURL(read('entry/src/main/ets/data/ResourceCatalog.ets').replace(/^import .*;\r?\n/, ''));
const { OPEN_RESOURCES, RESOURCE_CATEGORIES, RESOURCE_LICENSE_URLS, RESOURCE_VERIFICATION, findOpenResources, resourceTopic } = await import(catalogURL);
function byId(id) { return OPEN_RESOURCES.find(r => r.id === id); }
const componentSource = read('entry/src/main/ets/ui/LibraryPage.ets');
const methods = componentSource.slice(0, componentSource.indexOf('  @Builder'))
  .replace(/^import .*;\r?\n/gm, '').replace('@ComponentV2', '').replace('export struct LibraryPage', 'export class LibraryPage')
  .replace(/@(Local|Param|Event)\s+/g, '');
const header = `import {OPEN_RESOURCES,RESOURCE_LICENSE_URLS,RESOURCE_VERIFICATION,findOpenResources,resourceTopic} from '${catalogURL}';
const $r = value => value;\nclass Scroller {scrollTo() {}}\n`;
const { LibraryPage } = await import(moduleURL(header + methods + '\n}'));
function page({ choice = 0, cancelled = false } = {}) {
  const app = new LibraryPage(), opened = [], topics = [], menus = [];
  app.getUIContext = () => ({ getFocusController: () => ({ clearFocus() {} }), getPromptAction: () => ({
    async showActionMenu(options) { menus.push(options); if (cancelled) throw Error('cancel'); return { index: choice }; }
  }) });
  app.onOpenResource = r => opened.push(r);
  app.onUseTopic = text => topics.push(text);
  return { app, opened, topics, menus };
}

test('13 stable resourceIds have complete independent verification metadata and official HTTPS license links', () => {
  assert.equal(OPEN_RESOURCES.length, 13);
  assert.equal(new Set(OPEN_RESOURCES.map(r => r.id)).size, 13);
  for (const r of OPEN_RESOURCES) {
    for (const key of ['id','title','category','description','url','source','language','kind','license']) assert.ok(r[key]?.trim(), `${r.id}.${key}`);
    const meta = RESOURCE_VERIFICATION[r.id];
    assert.equal(meta.resourceId, r.id);
    assert.equal(meta.verifiedAt, '2026-11-23');
    assert.ok(meta.resourceType && meta.access);
    assert.ok(RESOURCE_CATEGORIES.includes(r.category));
    for (const url of [r.url, RESOURCE_LICENSE_URLS[r.id], meta.codeLicenseUrl].filter(Boolean)) assert.equal(new URL(url).protocol, 'https:');
  }
  assert.equal(RESOURCE_VERIFICATION.ostep.resourceType, '公开阅读资料');
  assert.match(byId('ostep').license, /未据此认定/);
  assert.match(byId('thinkdsp').license, /CC BY-NC-SA 4.0.*MIT/);
  assert.match(byId('d2l').license, /modified MIT.*非标准 MIT/);
});

test('search combines category with case-insensitive multiple terms across source, license, language and URL', () => {
  assert.equal(findOpenResources('   ', '全部').length, 13);
  assert.deepEqual(findOpenResources('D2L modified', '开放教材').map(r => r.id), ['d2l']);
  assert.deepEqual(findOpenResources(' MIT 英语 ', '电子').map(r => r.id), ['freertos']);
  assert.equal(findOpenResources('https://github.com/numpy/numpy', '全部')[0].id, 'numpy');
  assert.equal(findOpenResources('不存在的关键词', '全部').length, 0);
  assert.equal(findOpenResources('D2L', '电子').length, 0);
  assert.equal(findOpenResources('', '数值方法').length, 3);
});

test('native filtering resets result count and lazy datasource for empty, matched and reset states', () => {
  const { app } = page();
  app.category = '开放教材'; app.filterResources();
  assert.equal(app.resultCount, 2); assert.equal(app.dataSource.totalCount(), 2);
  app.query = '不存在的资料'; app.filterResources();
  assert.equal(app.resultCount, 0); assert.equal(app.dataSource.totalCount(), 0);
  app.query = ''; app.category = '全部'; app.filterResources();
  assert.equal(app.resultCount, 13);
});

test('details and content/code license actions retain the exact selected resource and callback contract', async () => {
  const { app, opened, menus } = page({ choice: 1 });
  app.openDetails(byId('d2l'));
  assert.equal(app.showingDetails, true);
  assert.equal(app.selectedResource.id, 'd2l');
  await app.chooseLicense();
  assert.equal(menus.length, 1);
  assert.equal(opened[0].url, RESOURCE_VERIFICATION.d2l.codeLicenseUrl);
  assert.equal(opened[0].id, 'd2l-license');
  app.openDetails(byId('ostep')); await app.chooseLicense();
  assert.equal(menus.length, 1);
  assert.equal(opened[1].url, RESOURCE_LICENSE_URLS.ostep);
});

test('dismissing details or the native license menu produces no topic or source side effect', async () => {
  const { app, opened, topics } = page({ cancelled: true });
  app.openDetails(byId('thinkdsp')); await app.chooseLicense();
  assert.equal(opened.length, 0);
  app.detailClosed(); assert.equal(topics.length, 0);
});

test('theme creation delivers one title/intro-only prompt after sheet dismissal and retains filtering', () => {
  const { app, topics } = page();
  app.category = '系统'; app.query = 'xv6'; app.filterResources();
  app.openDetails(byId('xv6')); app.useTopic(); app.useTopic();
  assert.equal(app.showingDetails, false); assert.equal(topics.length, 0);
  app.detailClosed(); app.detailClosed();
  assert.equal(topics.length, 1);
  assert.equal(topics[0], resourceTopic(byId('xv6')));
  assert.match(topics[0], /没有读取原站全文/);
  assert.match(topics[0], /不要声称已阅读、总结或引用原站具体章节/);
  assert.equal(app.category, '系统'); assert.equal(app.query, 'xv6');
});
