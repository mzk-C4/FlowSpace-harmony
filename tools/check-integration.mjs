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
const entry = read(join(root, 'entry/src/main/ets/pages/Index.ets'));
for (const name of ['HomePage', 'DIYPage', 'LibraryPage', 'ProfilePage']) {
  assert.ok(entry.includes(name + '({'), `未接入页面 ${name}`);
}
const build = read(join(root, 'build-profile.json5'));
assert.ok(build.includes('6.1.1(24)'), '工程未使用 API 24');
assert.ok(!build.includes('6.1.1(26)'), '仍引用旧 API');
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
console.log(`静态集成检查通过：4个已接入页面、${files.length}个ArkTS文件、有效导入和颜色。此检查不代替SDK编译和设备验收。`);
