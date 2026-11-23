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
const diy = read(join(root, 'entry/src/main/ets/ui/DIYPage.ets'));
assert.ok(diy.includes('viewMode: this.canvasMode'), 'DIY 未把 2D/3D 模式传给画布');
assert.ok(diy.includes("@Local canvasMode: string = '2d'"), 'DIY 缺少 2D/3D 视图状态');
const canvas = read(join(root, 'entry/src/main/ets/canvas/MindMapCanvas.ets'));
assert.ok(canvas.includes("@Param viewMode: string = '2d'"), '画布缺少 viewMode 参数');
assert.ok(canvas.includes('paint3D('), '画布缺少 3D 绘制入口');
assert.ok(canvas.includes('beginRotate('), '画布缺少 3D 旋转手势');
assert.ok(diy.includes('resetViewSignal: this.resetViewSignal'), 'DIY 未接入 3D 复位');
const build = read(join(root, 'build-profile.json5'));
assert.ok(build.includes('6.1.1(24)'), '工程未使用 API 24');
assert.ok(!build.includes('6.1.1(26)'), '仍引用旧 API');
const files = walk(join(root, 'entry/src/main/ets')).filter(f => f.endsWith('.ets'));
const palette = mode => Object.fromEntries(JSON.parse(read(join(root, 'entry/src/main/resources', mode, 'element/color.json'))).color.map(c => [c.name, c.value]));
const light = palette('base'), dark = palette('dark');
const colors = new Set(Object.keys(light));
assert.deepEqual(Object.keys(light).sort(), Object.keys(dark).sort(), '浅色与深色资源需一一对应');
function luminance(hex) {
  const channels = hex.slice(1).match(/../g).map(channel => parseInt(channel, 16) / 255)
    .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}
for (const theme of [light, dark]) {
  for (const [fg, bg] of [['fs_text', 'fs_surface'], ['fs_muted', 'fs_bg'], ['fs_muted', 'fs_group'],
    ['fs_accent', 'fs_soft'], ['fs_on_accent', 'fs_accent'], ['fs_danger', 'fs_surface']]) {
    const values = [luminance(theme[fg]), luminance(theme[bg])].sort((a, b) => b - a);
    assert.ok((values[0] + 0.05) / (values[1] + 0.05) >= 4.5, `正文对比度不足 ${fg}/${bg}`);
  }
}
for (const file of files) {
  const text = read(file);
  assert.ok(!/^(<<<<<<< |=======\s*$|>>>>>>> )/m.test(text), `残留冲突: ${file}`);
  for (const [, target] of text.matchAll(/from\s+['"]([^'"]+)['"]/g)) {
    if (target.startsWith('.')) assert.ok(existsSync(resolve(dirname(file), target.endsWith('.json') ? target : target + '.ets')), `无效导入 ${file}: ${target}`);
  }
  for (const [, name] of text.matchAll(/pushPathByName\(\s*['"]([^'"]+)['"]/g)) {
    assert.ok(byName.has(name), `未注册路由 ${file}: ${name}`);
  }
  for (const [, name] of text.matchAll(/\$r\(['"]app\.color\.([^'"]+)['"]\)/g)) {
    assert.ok(colors.has(name), `缺少颜色 ${file}: ${name}`);
  }
}
console.log(`静态集成检查通过：4个已接入页面、${files.length}个ArkTS文件、有效导入及双主题文字对比。此检查不代替SDK编译和设备验收。`);
