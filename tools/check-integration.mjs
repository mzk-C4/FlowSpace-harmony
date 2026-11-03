import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(path, 'utf8').replace(/^\uFEFF/, '');
const walk = dir => readdirSync(dir, { withFileTypes: true }).flatMap(e =>
  e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)]);
const routes = JSON.parse(read(join(root, 'entry/src/main/resources/base/profile/router_map.json'))).routerMap;
assert.equal(new Set(routes.map(r => r.name)).size, routes.length, '重复路由名');
const byName = new Map(routes.map(r => [r.name, r]));
for (const route of routes) {
  const source = read(join(root, 'entry', route.pageSourceFile));
  assert.ok(source.includes(`export function ${route.buildFunction}(`), `缺少 builder: ${route.name}`);
}
for (const name of ['actionWorkbench', 'conceptCompare', 'compareResult', 'practiceFeedback', 'learningRecords',
  'scheduleOverview', 'timeline', 'taskDetail', 'adjustPreview', 'reviewList', 'knowledgeProjects']) {
  assert.ok(byName.has(name), `缺少成员路由 ${name}`);
  assert.ok(!byName.get(name).pageSourceFile.includes('Placeholder'), `成员路由仍为占位 ${name}`);
}
const files = walk(join(root, 'entry/src/main/ets')).filter(f => f.endsWith('.ets'));
const colors = new Set(JSON.parse(read(join(root, 'entry/src/main/resources/base/element/color.json'))).color.map(c => c.name));
for (const file of files) {
  const text = read(file);
  assert.ok(!/^(<<<<<<< |=======\s*$|>>>>>>> )/m.test(text), `残留冲突: ${file}`);
  for (const [, target] of text.matchAll(/from\s+['"]([^'"]+)['"]/g)) {
    if (target.startsWith('.')) assert.ok(existsSync(resolve(dirname(file), target + '.ets')), `无效导入 ${file}: ${target}`);
  }
  for (const [, name] of text.matchAll(/pushPathByName\(\s*['"]([^'"]+)['"]/g)) {
    assert.ok(byName.has(name), `未注册路由 ${file}: ${name}`);
  }
  for (const [, name] of text.matchAll(/\$r\(['"]app\.color\.([^'"]+)['"]\)/g)) {
    assert.ok(colors.has(name), `缺少颜色 ${file}: ${name}`);
  }
}
console.log(`静态集成检查通过：${routes.length} 个路由、${files.length} 个 ArkTS 文件。此检查不代替 SDK 编译和设备验收。`);
