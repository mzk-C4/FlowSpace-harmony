import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {createGateway} from '../server.mjs';
import {validateLesson,validateLessonRequest,lessonMessages} from '../lessons.mjs';
const sample=()=>({id:'generated',kind:'flow',title:'复利增长',summary:'本金和收益一起参与下一期计息。',invariant:'假设每期利率固定且收益继续投入；实际收益不保证。',sourceTitle:'',sourceUrl:'',code:[],steps:[
 {title:'初始本金',explanation:'从100元开始。',operation:'P = 100',cells:['本金 100'],active:0,start:-1,end:-1,codeLine:-1},
 {title:'第一期',explanation:'假设利率为10%，期末变为110元。',operation:'100 × 1.1 = 110',cells:['期初 100','收益 10','期末 110'],active:2,start:-1,end:-1,codeLine:-1}
]});
const request=()=>({requestId:'lesson-test',documentId:'doc-test',nodeId:'node-test',baseRevision:3,topic:'解释复利而非计算机算法',instruction:'用两步展示',context:'学习复利与单利的区别',code:'',links:[]});
async function listen(server){server.listen(0,'127.0.0.1');await once(server,'listening');return `http://127.0.0.1:${server.address().port}`}
async function close(server){server.closeAllConnections();await new Promise(resolve=>server.close(resolve))}
async function setup(t,handler,options={}){
 let calls=0,seen=[];
 const upstream=createServer(async(req,res)=>{let body='';for await(const part of req)body+=part;const payload=JSON.parse(body);seen.push(payload);await handler(req,res,payload,++calls)});
 const base=await listen(upstream),gateway=createGateway({env:{LLM_BASE_URL:base+'/v1',LLM_MODEL:'controlled-test'},...options}),url=await listen(gateway);
 t.after(async()=>{await close(gateway);await close(upstream)});return {url,seen,calls:()=>calls};
}
const send=(res,value)=>{res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({choices:[{message:{content:typeof value==='string'?value:JSON.stringify(value)}}]}))};
const post=(url,input=request(),signal)=>fetch(url+'/api/lessons/generate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(input),signal});
test('schema accepts arbitrary conceptual topics and rejects invalid layouts, bounds and oversized content',()=>{
 assert.equal(validateLesson(sample()).title,'复利增长');assert.equal(validateLessonRequest(request()).topic,'解释复利而非计算机算法');
 for(const change of [s=>s.kind='html',s=>s.steps[0].active=3,s=>s.steps[0].codeLine=0,s=>s.steps=[],s=>s.code=['x'.repeat(201)],s=>s.sourceUrl='javascript:alert(1)']){const s=sample();change(s);assert.throws(()=>validateLesson(s))}
 for(const url of ['javascript:alert(1)','file:///tmp/x','https://user:pass@example.com','https://example.com/"x'])assert.throws(()=>validateLessonRequest({...request(),links:[{title:'bad',url}]}));
 assert.match(lessonMessages(request())[0].content,/尚未读取内容/);
});
test('unconfigured gateway returns an explicit 503 without any scripted fallback',async t=>{
 const server=createGateway({env:{}}),url=await listen(server);t.after(()=>close(server));const res=await post(url);assert.equal(res.status,503);assert.match((await res.json()).message,/配置模型/);
});
test('real gateway invokes controlled model and binds arbitrary-topic script to exact node/revision',async t=>{
 const app=await setup(t,(_req,res)=>send(res,sample()));const res=await post(app.url),out=await res.json();assert.equal(res.status,200);assert.equal(out.script.title,'复利增长');
 for(const k of ['requestId','documentId','nodeId','baseRevision'])assert.equal(out[k],request()[k]);assert.equal(app.calls(),1);assert.equal(app.seen[0].stream,true);assert.match(app.seen[0].messages[1].content,/复利/);
});
test('invalid indices or invented sources are repaired once; repeated invalid output fails',async t=>{
 const app=await setup(t,(_req,res,_payload,n)=>{const s=sample();if(n===1){s.sourceUrl='https://invented.example.com';s.sourceTitle='捏造来源'}send(res,s)});
 assert.equal((await post(app.url)).status,200);assert.equal(app.calls(),2);
 const bad=await setup(t,(_req,res)=>{const s=sample();s.steps[0].active=99;send(res,s)});
 const result=await post(bad.url);assert.equal(result.status,502);assert.equal(bad.calls(),2);assert.match((await result.json()).message,/原节点保持不变/);
});
test('same-document requests are locked and cancellation releases upstream work',async t=>{
 let release;const gate=new Promise(r=>release=r);t.after(()=>release());
 const app=await setup(t,async(_req,res)=>{await gate;if(!res.destroyed)send(res,sample())});
 const controller=new AbortController(),first=post(app.url,request(),controller.signal);first.catch(()=>{});
 while(app.calls()===0)await new Promise(r=>setTimeout(r,5));
 assert.equal((await post(app.url,{...request(),requestId:'second'})).status,409);
 controller.abort();await assert.rejects(first);release();
 let result;for(let i=0;i<20;i++){await new Promise(r=>setTimeout(r,10));result=await post(app.url,{...request(),requestId:'after'});if(result.status!==409)break}
 assert.equal(result.status,200);
});
test('timeout, provider error, malformed request and media type are explicit',async t=>{
 const app=await setup(t,()=>{}, {timeoutMs:30});const res=await post(app.url);assert.equal(res.status,502);assert.match((await res.json()).message,/超时/);
 assert.equal((await post(app.url,{...request(),topic:''})).status,400);
 assert.equal((await fetch(app.url+'/api/lessons/generate',{method:'POST',body:'{}'})).status,415);
 const bad=await setup(t,(_req,res)=>{res.writeHead(401);res.end()});const error=await post(bad.url);assert.equal(error.status,502);assert.match((await error.json()).message,/鉴权/);
});

test('normal AI map edits preserve separately confirmed node study metadata while allowing narrative changes',async()=>{
 const {preserveNodeStudy}=await import('../node-study.mjs');
 const block='\n\n```flowspace-learning-v1\n'+JSON.stringify({version:1,code:'int x=1;',links:[]})+'\n```';
 assert.equal(preserveNodeStudy('旧说明'+block,'新说明'),'新说明'+block);
 assert.equal(preserveNodeStudy('旧说明'+block,'新说明'+block),'新说明'+block);
 assert.equal(preserveNodeStudy('普通备注','新备注'),'新备注');
 const {assembleCandidate}=await import('../llm.mjs');
 const now='2026-11-27T00:00:00.000Z';
 const document={schemaVersion:1,documentId:'map',title:'root',revision:0,rootId:'root',nodes:[{id:'root',parentId:'',order:0,text:'root',note:'旧说明'+block,collapsed:false}],layout:'right',sourceText:'',messages:[],createdAt:now,updatedAt:now};
 const result=assembleCandidate({title:'root',nodes:[{id:'root',parentId:'',order:0,text:'root',note:'新说明'}],summary:'备注更新'}, {requestId:'r',documentId:'map',baseRevision:0,mode:'revise',scopeNodeId:'root',document,messages:[],instruction:'完善说明'});
 assert.equal(result.document.nodes[0].note,'新说明'+block);
});
