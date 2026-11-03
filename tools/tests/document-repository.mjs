import test from 'node:test';
import assert from 'node:assert/strict';
import { stripTypeScriptTypes } from 'node:module';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { setImmediate as tick } from 'node:timers/promises';

// This test runs the actual repository source. The replacements below model
// only the declared SDK boundary; they do not contain a repository algorithm.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const stage = mkdtempSync(join(tmpdir(), 'flowspace-repository-test-'));
writeFileSync(join(stage, 'sdk.mjs'), `
export const relationalStore = {
  SecurityLevel:{S1:1},
  getRdbStore:async(context,config) => {
    if(config.name !== 'mindmaps.db' || config.securityLevel !== 1) throw Error('unexpected store config');
    context.store.opens++; await Promise.resolve(); return context.store;
  }
};
export const preferences = {
  getPreferences:async(context,name) => {
    if(name !== 'mindmap_settings') throw Error('unexpected preference name');
    context.prefs.opens++; return context.prefs;
  }
};
`);
for (const [source, target] of [['domain/MindMap','MindMap'], ['domain/DocumentSession','DocumentSession'], ['storage/DocumentRepository','DocumentRepository']]) {
  const text = readFileSync(join(root, 'entry/src/main/ets', source + '.ets'), 'utf8')
    .replace(/^import common .*\r?\n/gm,'')
    .replace(/^import (relationalStore|preferences) from '@ohos[^']+';/gm, "import {$1} from './sdk.mjs';")
    .replace(/from '(?:\.\/|\.\.\/domain\/)(MindMap|DocumentSession)'/g, "from './$1.mjs'")
    .replace(/import \{([^}]+)\} from '\.\/(MindMap|DocumentSession)\.mjs'/g, (_,names,module) =>
      'import {' + names.split(',').map(n => n.trim())
        .filter(n => ['cloneDocument','newId','validateDocument','createDocument','defaultSettings'].includes(n)).join(',') + "} from './" + module + ".mjs'");
  writeFileSync(join(stage,target+'.mjs'),stripTypeScriptTypes(text,{mode:'transform'}));
}
const {createDocument,cloneDocument,defaultSettings} = await import(pathToFileURL(join(stage,'MindMap.mjs')));
const {documentRepository} = await import(pathToFileURL(join(stage,'DocumentRepository.mjs')));
test.after(() => rmSync(stage,{recursive:true,force:true}));

const compact = sql => sql.replace(/\s+/g,' ').trim();
class StrictResultSet {
  constructor(store,rows) { this.store=store; this.rows=rows; this.position=-1; this.closed=false; store.resultSets++; }
  live() { assert.equal(this.closed,false,'closed result set reused'); }
  goToFirstRow() { this.live(); this.position=0; return this.rows.length>0; }
  goToNextRow() { this.live(); return ++this.position<this.rows.length; }
  value(index) {
    this.live(); assert.ok(this.position>=0 && this.position<this.rows.length,'invalid result-set cursor');
    assert.ok(index>=0 && index<this.rows[this.position].length,'invalid column index');
    return this.rows[this.position][index];
  }
  getString(index) { const value=this.value(index); assert.equal(typeof value,'string'); return value; }
  getLong(index) { const value=this.value(index); assert.ok(Number.isInteger(value)); return value; }
  close() { this.live(); this.closed=true; this.store.resultSets--; }
}

class StrictRdb {
  constructor() {
    this.version=0; this.opens=0; this.resultSets=0; this.documents=new Map(); this.recovery=new Map();
    this.transaction=null; this.busy=false; this.trace=[]; this.commits=0; this.rollbacks=0; this.failure='';
  }
  get tables() { return this.transaction || this; }
  async operation(sql,args,action) {
    assert.equal(this.busy,false,'SQL operations overlapped'); this.busy=true;
    try {
      await tick(); this.trace.push({sql,args:structuredClone(args)});
      if (this.failure && sql.startsWith(this.failure)) { this.failure=''; throw Error('injected disk failure'); }
      return action();
    } finally { this.busy=false; }
  }
  async querySql(raw,args=[]) {
    const sql=compact(raw);
    return this.operation(sql,args,() => {
      const {documents,recovery}=this.tables;
      let rows;
      if (sql==='SELECT revision, payload FROM documents WHERE id = ?') {
        assert.equal(args.length,1); const row=documents.get(args[0]); rows=row?[[row.revision,row.payload]]:[];
      } else if(sql==='SELECT payload FROM documents WHERE id = ?') {
        assert.equal(args.length,1); const row=documents.get(args[0]); rows=row?[[row.payload]]:[];
      } else if(sql==='SELECT payload FROM recovery WHERE id = ?') {
        assert.equal(args.length,1); rows=recovery.has(args[0])?[[recovery.get(args[0])]]:[];
      } else if(sql==='SELECT id, title, node_count, updated_at FROM documents WHERE title LIKE ? ORDER BY updated_at DESC') {
        assert.equal(args.length,1);
        const pattern=new RegExp('^'+args[0].split('').map(c => c==='%'?'.*':c==='_'?'.':c.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')).join('')+'$','iu');
        rows=[...documents.values()].filter(r => pattern.test(r.title))
          .sort((a,b)=>b.updated_at.localeCompare(a.updated_at)).map(r=>[r.id,r.title,r.node_count,r.updated_at]);
      } else throw Error('unrecognized SQL query: '+sql);
      return new StrictResultSet(this,rows);
    });
  }
  async executeSql(raw,args=[]) {
    const sql=compact(raw);
    return this.operation(sql,args,() => {
      const {documents,recovery}=this.tables;
      if(sql.startsWith('CREATE TABLE IF NOT EXISTS ')) {
        assert.ok(/^CREATE TABLE IF NOT EXISTS (documents|recovery) \(/.test(sql)); return;
      }
      assert.ok(this.transaction,'writes must be inside transaction');
      if(sql==='INSERT OR REPLACE INTO recovery (id, payload) SELECT id, payload FROM documents WHERE id = ?') {
        assert.equal(args.length,1); const row=documents.get(args[0]); if(row) recovery.set(row.id,row.payload);
      } else if(sql==='INSERT OR REPLACE INTO documents (id, title, revision, node_count, updated_at, payload) VALUES (?, ?, ?, ?, ?, ?)') {
        assert.equal(args.length,6);
        documents.set(args[0],{id:args[0],title:args[1],revision:args[2],node_count:args[3],updated_at:args[4],payload:args[5]});
      } else if(sql==='INSERT OR IGNORE INTO recovery (id, payload) VALUES (?, ?)') {
        assert.equal(args.length,2); if(!recovery.has(args[0])) recovery.set(args[0],args[1]);
      } else if(sql==='DELETE FROM recovery WHERE id = ?') { assert.equal(args.length,1); recovery.delete(args[0]); }
      else if(sql==='DELETE FROM documents WHERE id = ?') { assert.equal(args.length,1); documents.delete(args[0]); }
      else throw Error('unrecognized SQL write: '+sql);
    });
  }
  beginTransaction() {
    assert.equal(this.busy,false); assert.equal(this.resultSets,0,'cursor not closed before transaction');
    assert.equal(this.transaction,null,'nested transaction');
    this.transaction={documents:structuredClone(this.documents),recovery:structuredClone(this.recovery)};
  }
  commit() {
    assert.equal(this.busy,false); assert.ok(this.transaction);
    this.documents=this.transaction.documents; this.recovery=this.transaction.recovery;
    this.transaction=null; this.commits++;
  }
  rollBack() { assert.equal(this.busy,false); assert.ok(this.transaction); this.transaction=null; this.rollbacks++; }
}

class StrictPreferences {
  constructor(disk=new Map()) {this.disk=disk; this.memory=new Map(disk); this.opens=0; this.flushes=0; this.failFlush=false;}
  async get(key,fallback) { assert.equal(key,'settings'); return this.memory.get(key) ?? fallback; }
  async put(key,value) { assert.equal(key,'settings'); assert.equal(typeof value,'string'); this.memory.set(key,value); }
  async flush() {
    this.flushes++;
    if(this.failFlush) {this.failFlush=false; throw Error('injected preferences flush failure');}
    this.disk.clear(); for(const [k,v] of this.memory) this.disk.set(k,v);
  }
}

async function fresh(t,{store=new StrictRdb(),prefs=new StrictPreferences()}={}) {
  const repo=new documentRepository.constructor();
  await repo.initialize({store,prefs});
  t.after(()=>{assert.equal(store.resultSets,0,'result set leaked'); assert.equal(store.transaction,null,'transaction leaked'); assert.equal(store.busy,false);});
  return {repo,store,prefs};
}
function revision(doc,value,title=doc.title) {
  const copy=cloneDocument(doc); copy.revision=value; copy.title=title;
  copy.updatedAt=new Date(Date.parse(doc.createdAt)+value*1000).toISOString(); return copy;
}

test('initialize is idempotent and coalesces simultaneous RDB/preferences opens',async t=>{
  const repo=new documentRepository.constructor(),store=new StrictRdb(),prefs=new StrictPreferences();
  const context={store,prefs};
  await Promise.all([repo.initialize(context),repo.initialize(context),repo.initialize(context)]);
  await repo.initialize(context);
  assert.equal(store.opens,1); assert.equal(prefs.opens,1); assert.equal(store.version,1);
  assert.deepEqual(await repo.list(),[]);
  assert.equal(await repo.get('missing'),null); assert.deepEqual(await repo.loadSettings(),defaultSettings());
});

test('concurrent saves execute serially and capture immutable invocation snapshots',async t=>{
  const {repo,store}=await fresh(t),doc=createDocument('初始');
  const next=revision(doc,1,'第一版'),last=revision(doc,2,'第二版');
  const saves=[repo.save(doc),repo.save(next),repo.save(last)];
  next.title='调用之后外部改动'; last.title='不应持久化';
  await Promise.all(saves);
  assert.equal((await repo.get(doc.documentId)).title,'第二版');
  assert.equal(store.commits,3);
  assert.equal(JSON.parse(store.recovery.get(doc.documentId)).title,'第一版');
});

test('reads await queued writes and stale revisions reject without poisoning queue',async t=>{
  const {repo,store}=await fresh(t),doc=createDocument();
  const p=repo.save(revision(doc,4,'最新'));
  const found=repo.get(doc.documentId);
  await p; assert.equal((await found).revision,4);
  const snapshot=structuredClone(store.recovery);
  await assert.rejects(repo.save(revision(doc,3,'过时')),/较新/);
  assert.equal((await repo.get(doc.documentId)).revision,4);
  assert.deepEqual(store.recovery,snapshot);
  await repo.save(revision(doc,5,'重试成功')); assert.equal((await repo.get(doc.documentId)).revision,5);
});

test('transaction failure after document update rolls back document and recovery; retry succeeds',async t=>{
  const {repo,store}=await fresh(t),doc=createDocument('原稿');
  await repo.save(doc); await repo.save(revision(doc,1,'已保存'));
  const documents=structuredClone(store.documents),recovery=structuredClone(store.recovery);
  store.failure='INSERT OR IGNORE INTO recovery';
  await assert.rejects(repo.save(revision(doc,2,'失败版本')),/disk failure/);
  assert.deepEqual(store.documents,documents); assert.deepEqual(store.recovery,recovery);
  assert.equal(store.rollbacks,1);
  await repo.save(revision(doc,2,'重新保存')); assert.equal((await repo.get(doc.documentId)).title,'重新保存');
});

test('malformed, empty and structurally invalid payloads recover previous validated snapshot',async t=>{
  const {repo,store}=await fresh(t),doc=createDocument('恢复点');
  await repo.save(doc); await repo.save(revision(doc,1,'较新稿'));
  for(const corrupt of ['{broken','',JSON.stringify({...doc,nodes:[]}),JSON.stringify(createDocument('另一文档'))]) {
    store.documents.get(doc.documentId).payload=corrupt;
    const recovered=await repo.get(doc.documentId);
    assert.equal(recovered.title,'恢复点'); assert.equal(recovered.documentId,doc.documentId);
  }
  store.recovery.set(doc.documentId,'{bad recovery');
  await assert.rejects(repo.get(doc.documentId));
  store.recovery.delete(doc.documentId); await assert.rejects(repo.get(doc.documentId),/没有恢复快照/);
});

test('repairing corrupted current payload preserves existing valid recovery snapshot',async t=>{
  const {repo,store}=await fresh(t),doc=createDocument('可用备份');
  await repo.save(doc); await repo.save(revision(doc,1,'当前稿'));
  store.documents.get(doc.documentId).payload='{broken';
  const recovered=await repo.get(doc.documentId);
  await repo.save(revision(recovered,2,'修复稿'));
  assert.equal(JSON.parse(store.recovery.get(doc.documentId)).title,'可用备份');
  store.documents.get(doc.documentId).payload='{broken again';
  assert.equal((await repo.get(doc.documentId)).title,'可用备份');
});

test('search uses bound parameters, sorts updates and delete removes both tables',async t=>{
  const {repo,store}=await fresh(t),a=createDocument('电路基础'),b=createDocument('电路进阶'),c=createDocument("特殊 ' OR 1=1 --");
  await repo.save(revision(a,1)); await repo.save(revision(b,3)); await repo.save(c);
  assert.deepEqual((await repo.list('电路')).map(d=>d.documentId),[b.documentId,a.documentId]);
  assert.equal((await repo.list("' OR 1=1 --")).length,1);
  const query=store.trace.filter(q=>q.sql.includes('LIKE')).at(-1);
  assert.deepEqual(query.args,["%' OR 1=1 --%"]); assert.ok(!query.sql.includes('OR 1=1'));
  await repo.delete(a.documentId);
  assert.equal(store.documents.has(a.documentId),false); assert.equal(store.recovery.has(a.documentId),false);
  assert.equal(await repo.get(a.documentId),null); assert.equal((await repo.list('电路')).length,1);
});

test('delete transaction rollback restores both tables and later delete can retry',async t=>{
  const {repo,store}=await fresh(t),doc=createDocument(); await repo.save(doc);
  store.failure='DELETE FROM documents'; await assert.rejects(repo.delete(doc.documentId),/disk failure/);
  assert.equal(store.documents.has(doc.documentId),true); assert.equal(store.recovery.has(doc.documentId),true);
  await repo.delete(doc.documentId); assert.equal(store.documents.size,0); assert.equal(store.recovery.size,0);
});

test('settings flush persists through repository recreation; failures propagate and can retry',async t=>{
  const {repo,store,prefs}=await fresh(t);
  const settings={backendUrl:'https://example.test/api',themeMode:'dark',reduceMotion:true};
  await repo.saveSettings(settings); assert.equal(prefs.flushes,1);
  const restart=await fresh(t,{store,prefs:new StrictPreferences(prefs.disk)});
  assert.deepEqual(await restart.repo.loadSettings(),settings);
  prefs.failFlush=true; await assert.rejects(repo.saveSettings({...settings,themeMode:'light'}),/flush failure/);
  assert.equal(JSON.parse(prefs.disk.get('settings')).themeMode,'dark');
  await repo.saveSettings({...settings,themeMode:'light'});
  assert.equal(JSON.parse(prefs.disk.get('settings')).themeMode,'light');
  await assert.rejects(repo.saveSettings({...settings,backendUrl:'file:///bad'}));
});

test('invalid documents are rejected before any write or snapshot change',async t=>{
  const {repo,store}=await fresh(t),doc=createDocument();
  doc.nodes[0].parentId='absent'; const before=store.trace.length;
  await assert.rejects(repo.save(doc));
  assert.equal(store.trace.length,before); assert.equal(store.documents.size,0); assert.equal(store.recovery.size,0);
});
