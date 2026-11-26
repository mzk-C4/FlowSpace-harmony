// Execute the real native video catalog and HomePage methods. ArkUI rendering, real AI
// requests and phone playback are verified separately; these tests never touch the network.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
const root = new URL('../../', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');
const moduleURL = text => 'data:text/javascript;base64,' + Buffer.from(stripTypeScriptTypes(text, { mode: 'transform' })).toString('base64');
const catalogSource = read('entry/src/main/ets/data/VideoCatalog.ets').replace(/^import .*;\r?\n/, '');
const catalogURL = moduleURL(catalogSource);
const { VIDEO_RESOURCES, VIDEO_CATEGORIES, VIDEO_VERIFICATION, findVideos } =
  await import(catalogURL);
const pageSource = read('entry/src/main/ets/ui/HomePage.ets');
const indexSource = read('entry/src/main/ets/pages/Index.ets');
const methods = pageSource.slice(0, pageSource.indexOf('  @Builder'))
  .replace(/^import .*;\r?\n/gm, '').replace('@ComponentV2', '').replace('export struct HomePage', 'export class HomePage')
  .replace(/@(Local|Param|Event)\s+/g, '');
const header = `import {VIDEO_RESOURCES,VIDEO_CATEGORIES,VIDEO_VERIFICATION,findVideos} from '${catalogURL}';\nconst $r = value => value;\nclass Scroller {scrollTo() {}}\n`;
const { HomePage, HomeVideoSource } = await import(moduleURL(header + methods + '\n}\nexport { HomeVideoSource };\n'));
function page() {
  const app = new HomePage(), generated = [], opened = [], focus = [];
  app.getUIContext = () => ({ getFocusController: () => ({ clearFocus() { focus.push('cleared'); } }) });
  app.onGenerate = text => generated.push(text);
  app.onOpenDocument = id => opened.push(id);
  return { app, generated, opened, focus };
}

test('8 engineering videos keep stable fields plus independent source, instructor, access and verification records', () => {
  assert.equal(VIDEO_RESOURCES.length, 8);
  assert.equal(new Set(VIDEO_RESOURCES.map(r => r.id)).size, 8);
  assert.deepEqual(VIDEO_CATEGORIES, ['全部', '数学基础', '算法', '电路', '信号', '控制']);
  assert.equal(Object.keys(VIDEO_VERIFICATION).length, 8);
  const covered = new Set(VIDEO_RESOURCES.map(r => r.category));
  for (const category of VIDEO_CATEGORIES.slice(1)) assert.ok(covered.has(category), `缺少方向 ${category}`);
  for (const r of VIDEO_RESOURCES) {
    for (const key of ['id', 'title', 'category', 'description', 'url', 'source', 'language', 'kind', 'license']) {
      assert.ok(typeof r[key] === 'string' && r[key].trim(), `${r.id}.${key} 为空`);
    }
    assert.match(r.source, /^MIT OpenCourseWare · /, `${r.id} 提供机构`);
    assert.equal(new URL(r.url).protocol, 'https:');
    assert.match(r.language, /英语/, `${r.id} 语言`);
    const meta = VIDEO_VERIFICATION[r.id];
    assert.ok(meta, `${r.id} 缺少核验登记`);
    assert.equal(meta.videoId, r.id);
    for (const key of ['provider', 'instructor', 'access', 'fitFor']) {
      assert.ok(typeof meta[key] === 'string' && meta[key].trim(), `${r.id}.${key} 为空`);
    }
    assert.equal(meta.verifiedAt, '2026-11-24');
    assert.match(meta.access, /免费/, `${r.id} 访问条件需说明免费公开`);
  }
});

test('every direction keeps at least one video and filtering returns independent copies', () => {
  const expected = { '数学基础': 3, '算法': 2, '电路': 1, '信号': 1, '控制': 1 };
  for (const [category, count] of Object.entries(expected)) assert.equal(findVideos(category).length, count, category);
  assert.equal(findVideos('全部').length, 8);
  assert.deepEqual(findVideos('不存在的方向'), []);
  const copy = findVideos('全部');
  copy.pop();
  assert.equal(VIDEO_RESOURCES.length, 8, 'filter 不得改动共享目录');
  assert.equal(findVideos('控制')[0].id, 'video-mit-feedback');
});

test('HomePage reads categories from the catalog and never fabricates missing verification fields', () => {
  const { app } = page();
  assert.deepEqual(app.categories, VIDEO_CATEGORIES);
  assert.equal(app.videoDirectionCount(), 5);
  assert.equal(app.videoCountFor('全部'), 8);
  assert.equal(app.videoCountFor('算法'), 2);
  assert.equal(app.videoCountFor('不存在的方向'), 0);
  const known = app.videoVerification(VIDEO_RESOURCES[0]);
  assert.equal(known.provider, VIDEO_VERIFICATION[VIDEO_RESOURCES[0].id].provider);
  assert.deepEqual(app.videoVerification({ id: 'video-unregistered', source: '来源待补', description: '简介' }), {
    videoId: 'video-unregistered', provider: '来源待补', instructor: '以官方课程页为准',
    access: '以官方课程页的访问说明为准', fitFor: '简介', verifiedAt: '未登记'
  });
});


test('recent maps show at most three newest documents by documentId without mutating the input', () => {
  const { app } = page();
  assert.deepEqual(app.recentDocuments(), []);
  const documents = [
    { documentId: 'doc-b', title: 'B', nodeCount: 4, updatedAt: '2026-11-20T08:00:00.000Z' },
    { documentId: 'doc-a', title: 'A', nodeCount: 6, updatedAt: '2026-11-23T08:00:00.000Z' },
    { documentId: 'doc-d', title: 'D', nodeCount: 2, updatedAt: '2026-11-18T08:00:00.000Z' },
    { documentId: 'doc-c', title: 'C', nodeCount: 9, updatedAt: '2026-11-21T08:00:00.000Z' }
  ];
  app.documents = documents;
  assert.deepEqual(app.recentDocuments().map(d => d.documentId), ['doc-a', 'doc-c', 'doc-b']);
  assert.deepEqual(documents.map(d => d.documentId), ['doc-b', 'doc-a', 'doc-d', 'doc-c'], '排序不得就地改写入参');
  assert.match(app.dateLabel('2026-11-23T08:00:00.000Z'), /^11月2[23]日更新$/);
  assert.equal(app.dateLabel('不是日期'), '最近更新');
});

test('generate blocks blank, busy and over-limit input while keeping the draft intact', () => {
  const { app, generated, focus } = page();
  app.draft = '';
  app.generate();
  app.draft = '   \n  ';
  app.generate();
  assert.equal(generated.length, 0, '空白输入不可提交');
  app.draft = '信号与系统的复习提纲';
  app.busy = true;
  app.generate();
  assert.equal(generated.length, 0, '生成中不可重复提交');
  app.busy = false;
  app.draft = ' ' + 'x'.repeat(20000);
  app.generate();
  assert.equal(generated.length, 0, '超过 20,000 字不可提交');
  assert.equal(app.overLimit(), 1);
  assert.equal(app.draft.length, 20001, '超长提示不得清空或截断输入');
  app.draft = '  信号与系统的复习提纲  ';
  assert.equal(app.overLimit(), 0);
  app.generate();
  assert.deepEqual(generated, ['  信号与系统的复习提纲  '], '由外壳接收原始草稿');
  assert.equal(app.draft, '  信号与系统的复习提纲  ', '提交后保留草稿');
  assert.equal(focus.length, 1, '提交前释放输入焦点');
});

test('video data source filters in place and notifies the lazy list to reload', () => {
  const source = new HomeVideoSource();
  let reloads = 0;
  const listener = { onDataReloaded() { reloads++; }, onDataAdded() {}, onDataDeleted() {}, onDataChanged() {}, onDataMoved() {} };
  source.registerDataChangeListener(listener);
  source.registerDataChangeListener(listener);
  assert.equal(source.totalCount(), 8);
  source.filter('算法');
  assert.equal(source.totalCount(), 2);
  assert.equal(source.getData(0).category, '算法');
  assert.equal(reloads, 1, '重复注册只通知一次');
  source.filter('全部');
  assert.equal(source.totalCount(), 8);
  source.unregisterDataChangeListener(listener);
  source.filter('电路');
  assert.equal(reloads, 2, '注销后不再通知');
});

test('details expose the required verification labels and keep the official link action', () => {
  for (const label of ['提供机构', '主讲', '学科', '语言', '访问条件', '使用条件', '原始链接', '核验日期']) {
    assert.ok(pageSource.includes(`this.infoRow('${label}'`), `详情缺少信息行 ${label}`);
  }
  assert.ok(pageSource.includes('private categories: string[] = VIDEO_CATEGORIES;'));
  assert.ok(pageSource.includes('this.videoSource.filter(item)'));
  assert.ok(pageSource.includes('onClick(() => this.onOpenResource(resource))'));
  assert.match(pageSource, /20,000 字以内再生成/);
  assert.ok(pageSource.includes('已保留这段输入'));
});

test('home shows its own generation progress, recoverable errors and cancellation controls from the shell', () => {
  const status = pageSource.slice(pageSource.indexOf('private generationStatus()'), pageSource.indexOf('private inputMode('));
  assert.match(status, /if \(this\.generating\)/, '只显示首次生成的进度');
  assert.match(status, /Text\(this\.generationProgress \|\| '正在生成导图…'\)/);
  assert.match(status, /id\('home-cancel'\)\.onClick\(\(\) => this\.onCancel\(\)\)/);
  assert.match(status, /Text\(this\.generationError\)/, '失败需显示原因');
  assert.match(status, /startsWith\('已取消生成'\) \? \$r\('app\.color\.fs_muted'\)/, '取消需使用普通提示');
  assert.match(status, /草稿已保留，可以重新生成/);
  assert.match(status, /onClick\(\(\) => this\.onDismissGenerationFeedback\(\)\)/);
  assert.match(status, /onClick\(\(\) => this\.onConnectionSettings\(\)\)/);
  const composer = pageSource.slice(pageSource.indexOf('private composer()'), pageSource.indexOf('private examples()'));
  assert.ok(composer.includes('this.generationStatus()'), '状态条需放进输入区');
  assert.ok(composer.includes('this.onDraftChange(value)'), '输入区需更新外壳草稿');
  const call = indexSource.slice(indexSource.indexOf('HomePage({'), indexSource.indexOf("}.tabBar(this.tabLabel('首页'"));
  assert.ok(call.includes('draft: this.homeDraft'), '首页需恢复外壳草稿');
  assert.ok(call.includes('generating: this.creating, generationProgress: this.progress, generationError: this.homeError'));
  assert.ok(call.includes('onDismissGenerationFeedback: () => { this.homeError = \'\'; }'), '关闭提示需清理当前状态');
});

test('home keeps the 9.1 hierarchy, emphasized generate button and denser recent cards', () => {
  assert.match(pageSource, /Text\('新建思维导图'\)\.fontSize\(35\)\.fontWeight\(FontWeight\.Bold\)/);
  assert.ok(pageSource.includes("Text('输入主题或粘贴长文，生成可编辑、可导出的思维导图')"), '缺少定位说明');
  assert.ok(pageSource.includes('padding({ top: 16, bottom: 2 })'), '主标题留白');
  assert.ok(pageSource.includes('constraintSize({ minHeight: 56 })'), '生成按钮需更高');
  assert.ok(pageSource.includes("fontSize(17).fontWeight(FontWeight.Bold)"), '生成按钮文字需强调');
  assert.ok(pageSource.includes('this.longText ? 180 : 104'), '输入框高度');
  assert.ok(pageSource.includes("Text('点一下填入输入框')"), '示例需说明点击即填入');
  const recents = pageSource.slice(pageSource.indexOf('private recent()'), pageSource.indexOf('private videoHeader()'));
  assert.ok(recents.includes('.width(36).height(36).borderRadius(10)'), '最近导图卡片图标需收紧');
  assert.ok(recents.includes(".padding(12).backgroundColor(Color.Transparent)"), '最近导图卡片内边距需收紧');
});
