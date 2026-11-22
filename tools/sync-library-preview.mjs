// The catalog and pure search/topic functions have one authoritative ArkTS source.
import { readFileSync, writeFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
const root = new URL('../', import.meta.url);
const source = readFileSync(new URL('entry/src/main/ets/data/ResourceCatalog.ets', root), 'utf8').replace(/^import .*;\r?\n/, '');
const js = stripTypeScriptTypes(source, { mode: 'transform' });
const catalog = await import('data:text/javascript;base64,' + Buffer.from(js).toString('base64'));
const file = new URL('docs/preview/index.html', root);
let html = readFileSync(file, 'utf8');
const start = html.indexOf('const resources=');
const end = html.indexOf('\n];', start) + 3;
if (start < 0 || end < 3) throw new Error('Missing preview catalog');
html = html.slice(0, start) + 'const resources=' + JSON.stringify(catalog.OPEN_RESOURCES, null, 2) + ';' + html.slice(end);
const markerStart = '// BEGIN GENERATED LIBRARY HELPERS';
const markerEnd = '// END GENERATED LIBRARY HELPERS';
const generated = markerStart + '\nconst resourceVerification=' + JSON.stringify(catalog.RESOURCE_VERIFICATION) + ';\nconst resourceLicenseUrls=' + JSON.stringify(catalog.RESOURCE_LICENSE_URLS) + ';\n' + catalog.findOpenResources.toString().replaceAll('OPEN_RESOURCES', 'resources') + '\n' + catalog.resourceTopic.toString() + '\n' + markerEnd;
if (html.includes(markerStart)) {
  const a = html.indexOf(markerStart), b = html.indexOf(markerEnd, a) + markerEnd.length;
  html = html.slice(0, a) + generated + html.slice(b);
} else html = html.replace('const resources=', generated + '\nconst resources=');
writeFileSync(file, html);
console.log('Synced 13 native resources, verification metadata, license links, search and topic helpers.');
