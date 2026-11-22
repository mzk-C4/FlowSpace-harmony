// Fetch only the registered entry/license URLs. No textbook downloads or crawling.
// Requires Node 24+ and curl; use: node tools/verify-resource-links.mjs [output.json]
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { stripTypeScriptTypes } from 'node:module';
const source = readFileSync(new URL('../entry/src/main/ets/data/ResourceCatalog.ets', import.meta.url), 'utf8').replace(/^import .*;\r?\n/, '');
const catalog = await import('data:text/javascript;base64,' + Buffer.from(stripTypeScriptTypes(source, { mode: 'transform' })).toString('base64'));
const jobs = catalog.OPEN_RESOURCES.flatMap(r => [
  { resourceId: r.id, purpose: 'entry', url: r.url },
  { resourceId: r.id, purpose: 'license', url: catalog.RESOURCE_LICENSE_URLS[r.id] },
  ...(catalog.RESOURCE_VERIFICATION[r.id].codeLicenseUrl ? [{ resourceId: r.id, purpose: 'code-license', url: catalog.RESOURCE_VERIFICATION[r.id].codeLicenseUrl }] : [])
]);
function check(job) {
  return new Promise(resolve => {
    const child = spawn('curl', ['-sS','-L','--proto','=https','--proto-redir','=https','--max-time','35','--max-filesize','8000000','-o',process.platform==='win32'?'NUL':'/dev/null','-w','%{http_code}\n%{url_effective}',job.url]);
    let stdout = '', stderr = '';
    child.stdout.on('data', b => stdout += b); child.stderr.on('data', b => stderr += b);
    child.once('error', error => resolve({ ...job, status: 0, error: error.message, checkedAt: new Date().toISOString() }));
    child.once('close', exitCode => {
      const [status, finalUrl] = stdout.split('\n');
      resolve({ ...job, status: Number(status)||0, finalUrl, exitCode, error: stderr.trim(), checkedAt: new Date().toISOString() });
    });
  });
}
const results=[];
for(let index=0;index<jobs.length;index+=5) results.push(...await Promise.all(jobs.slice(index,index+5).map(check)));
const day = new Intl.DateTimeFormat('sv-SE', {timeZone:'Asia/Shanghai'}).format(new Date());
const output=resolve(process.argv[2] || `artifacts/resource-links-${day}.json`);
mkdirSync(dirname(output),{recursive:true}); writeFileSync(output,JSON.stringify(results,null,2));
for(const row of results) console.log(`${row.status} ${row.resourceId} ${row.purpose} ${row.url}`);
console.log(output);
if(results.some(row=>row.status!==200||row.exitCode!==0))process.exitCode=1;
