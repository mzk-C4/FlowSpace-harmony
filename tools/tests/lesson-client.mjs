import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
const root=new URL('../../entry/src/main/ets/learning/',import.meta.url);
const text=name=>readFileSync(new URL(name+'.ets',root),'utf8');
const js=source=>stripTypeScriptTypes(source,{mode:'transform'});
const moduleURL=source=>'data:text/javascript;base64,'+Buffer.from(source).toString('base64');
const schemaURL=moduleURL(js(text('LessonScript')));
const source=text('LessonClient').replace(/^import .*;\r?\n/gm,'');
const header=`import {validateLesson} from '${schemaURL}';\nconst http=globalThis.__lessonHTTP;\n`;
let seq=0;
async function harness(){
 const requests=[];globalThis.__lessonHTTP={RequestMethod:{POST:'POST'},HttpDataType:{STRING:0},createHttp(){
  const obj={destroyed:false,destroy(){this.destroyed=true},request(url,options){this.url=url;this.options=options;return new Promise((resolve,reject)=>{this.resolve=resolve;this.reject=reject})}};requests.push(obj);return obj}};
 const {lessonClient}=await import(moduleURL(js(header+source)+`\n//${++seq}`));return {client:lessonClient,requests};
}
const request={requestId:'req',documentId:'doc',nodeId:'node',baseRevision:2,topic:'任何主题',instruction:'',context:'',code:'',links:[]};
const script={id:'generated',kind:'compare',title:'复利与单利',summary:'比较再投资的不同',invariant:'实际收益不保证',sourceTitle:'',sourceUrl:'',code:[],steps:[{title:'第一期',explanation:'相同本金',operation:'',cells:['100','100'],active:0,start:-1,end:-1,codeLine:-1},{title:'第二期',explanation:'收益再投资会有差异',operation:'',cells:['121','120'],active:0,start:-1,end:-1,codeLine:-1}]};
const response=(overrides={})=>({...request,script,...overrides});
test('native client posts context to the configured lesson endpoint and validates bound results',async()=>{
 const {client,requests}=await harness();const pending=client.generate('http://127.0.0.1:8787/',request);assert.equal(requests[0].url,'http://127.0.0.1:8787/api/lessons/generate');assert.deepEqual(JSON.parse(requests[0].options.extraData),request);
 requests[0].resolve({responseCode:200,result:JSON.stringify(response())});assert.deepEqual(await pending,script);assert.equal(requests[0].destroyed,true);
});
test('native client rejects stale node bindings, invented sources and malformed responses',async()=>{
 for(const body of [response({nodeId:'other'}),response({baseRevision:1}),response({script:{...script,sourceUrl:'https://invented.example.com'}}),{script:{}}]){
  const {client,requests}=await harness(),pending=client.generate('http://127.0.0.1:8787',request);requests[0].resolve({responseCode:200,result:JSON.stringify(body)});await assert.rejects(pending);assert.equal(requests[0].destroyed,true);
 }
});
test('cancel immediately rejects and destroys the request; late results do not poison a fresh request',async()=>{
 const {client,requests}=await harness();const first=client.generate('http://localhost:8787',request);await assert.rejects(client.generate('http://localhost:8787',request),/已有/);
 client.cancel();await assert.rejects(first,/取消/);const second=client.generate('http://localhost:8787',request);
 requests[0].resolve({responseCode:200,result:JSON.stringify(response())});requests[1].resolve({responseCode:503,result:JSON.stringify({message:'服务未配置'})});await assert.rejects(second,/未配置/);
});
test.after(()=>delete globalThis.__lessonHTTP);
