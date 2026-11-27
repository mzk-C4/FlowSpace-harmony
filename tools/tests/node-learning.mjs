import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import {validateLesson as backendValidate} from '../../backend/lessons.mjs';
const source=name=>readFileSync(new URL('../../entry/src/main/ets/learning/'+name+'.ets',import.meta.url),'utf8');
const url=text=>'data:text/javascript;base64,'+Buffer.from(stripTypeScriptTypes(text,{mode:'transform'})).toString('base64');
const schemaURL=url(source('LessonScript'));
const noteURL=url(source('NodeLearning').replace(/^import .*;\r?\n/gm,`import {validateLesson} from '${schemaURL}';\n`));
const {validateLesson}=await import(schemaURL);
const {decodeStudyNote,encodeStudyNote,emptyStudy,validStudyUrl}=await import(noteURL);
const catalog=source('LessonCatalog').replace(/^import .*;\r?\n/gm,'').replace(/^export \{.*;\r?\n/gm,'');
const {VISUAL_LESSONS,lessonFrame}=await import(url(catalog));
const script=()=>({...structuredClone(VISUAL_LESSONS[0]),id:'generated'});
test('legacy notes and code/link/generated lesson survive a canonical note roundtrip without a document migration',()=>{
 const old='已有备注\n```cpp\nint a = 1;\n```';assert.equal(decodeStudyNote(old).text,old);assert.equal(encodeStudyNote(old,emptyStudy()),old);
 const study={...emptyStudy(),links:[{title:'文档',url:'https://en.cppreference.com/w/cpp/container/queue.html'}],code:'<script>not executed</script>\n```',generated:script()};
 const note=encodeStudyNote(old,study);assert.deepEqual(decodeStudyNote(note),{text:old,study});assert.ok(note.length<=10000);
 assert.deepEqual(decodeStudyNote(JSON.parse(JSON.stringify({note})).note).study.generated,study.generated);
});
test('malformed or future metadata never silently replaces the original note; caps and HTTPS destinations enforced',()=>{
 for(const note of ['note\n\n```flowspace-learning-v1\n{}','note\n\n```flowspace-learning-v1\n{bad}\n```','note\n\n```flowspace-learning-v1\n{"version":2}\n```'])assert.throws(()=>decodeStudyNote(note));
 for(const address of ['file:///x','javascript:alert(1)','https://u:p@example.com','https://x/"a','https://x/\nabc'])assert.equal(validStudyUrl(address),false);
 assert.equal(validStudyUrl('https://example.com/article?q=1#x'),true);
 assert.throws(()=>encodeStudyNote('x'.repeat(10001),emptyStudy()));assert.throws(()=>encodeStudyNote('',{...emptyStudy(),code:'x'.repeat(6001)}));
 assert.throws(()=>encodeStudyNote('',{...emptyStudy(),links:Array(9).fill({title:'x',url:'https://x.com'})}));
});
test('native and backend lesson validators agree on real scripts and invalid indices',()=>{
 const good=script();assert.doesNotThrow(()=>validateLesson(good));assert.doesNotThrow(()=>backendValidate(good));
 for(const mutate of [s=>s.steps[0].active=99,s=>s.steps[0].codeLine=99,s=>s.steps[0].cells=['x'.repeat(81)],s=>s.kind='executable',s=>s.steps=[],s=>s.steps[0]=null]){
  const s=script();mutate(s);assert.throws(()=>validateLesson(s));assert.throws(()=>backendValidate(s));
 }
});
test('ring wrap, FIFO, LIFO, source distinction and playback boundaries match the actual teaching scripts',()=>{
 assert.equal(lessonFrame('ring',2).start,5);assert.equal(lessonFrame('ring',3).cells[5],'5');assert.equal(lessonFrame('ring',5).end,3);
 assert.deepEqual(lessonFrame('queue',99).cells,['2','3']);assert.deepEqual(lessonFrame('stack',99).cells,['1','2']);
 assert.equal(lessonFrame('ring',-99),VISUAL_LESSONS[0].steps[0]);
 for(const lesson of VISUAL_LESSONS)backendValidate({...lesson,id:'generated'});
});

const cleanComponent = name => source(name).slice(0,source(name).indexOf('  @Builder'))
 .replace(/^import .*;\r?\n/gm,'').replace(/^@ComponentV2\r?\n/gm,'')
 .replace(/export struct (\w+)/,'export class $1').replace(/@(Param|Event|Local)\s+/g,'').replace(/^\s*@Monitor\([^\n]+\)\s*\n/gm,'\n');
const catalogURL=url(catalog);
const {NodeLearningPage}=await import(url(`import {emptyStudy,decodeStudyNote,encodeStudyNote,validStudyUrl} from '${noteURL}';\nimport {visualLesson} from '${catalogURL}';\n`+cleanComponent('NodeLearningPage')+'\n}'));
function page(){
 const app=new NodeLearningPage();app.title='复利';app.nodeId='n';app.documentId='d';app.note='笔记';app.revision=3;
 app.getUIContext=()=>({getPromptAction:()=>({showDialog:async()=>({index:0})})});app.aboutToAppear();
 const writes=[];app.onSave=(note,revision)=>{writes.push({note,revision});return true};return {app,writes};
}
test('native learning form preserves unsaved links and refuses partial input; cancelled edits retain original',()=>{
 const {app,writes}=page();app.beginEdit();app.linkTitle='reference';app.saveEdit();assert.equal(writes.length,0);assert.match(app.error,/未添加/);
 app.linkUrl='javascript:alert(1)';app.addLink();assert.equal(app.draftLinks.length,0);
 app.linkUrl='https://example.com';app.addLink();assert.equal(app.draftLinks.length,1);
 app.draftCode='print(1)';app.saveEdit();assert.equal(writes.length,1);assert.equal(decodeStudyNote(writes[0].note).study.code,'print(1)');assert.equal(writes[0].revision,3);
});
test('native AI results remain a candidate until explicit apply, then persist once at the generation revision',async()=>{
 const {app,writes}=page();app.onGenerate=async r=>{assert.equal(r.topic,'复利');assert.equal(r.baseRevision,3);return script()};
 await app.generate();assert.equal(writes.length,0);assert.ok(app.candidate);app.applyCandidate();assert.equal(writes.length,1);assert.equal(writes[0].revision,3);assert.ok(decodeStudyNote(writes[0].note).study.generated);app.applyCandidate();assert.equal(writes.length,1);
});
test('late and cancelled native AI responses cannot restore a dismissed candidate or overwrite a newer revision',async()=>{
 const {app,writes}=page();let resolve;let cancelled=0;app.onGenerate=()=>new Promise(r=>resolve=r);app.onCancelGeneration=()=>cancelled++;
 const pending=app.generate();app.cancel();resolve(script());await pending;assert.equal(app.candidate,null);assert.equal(cancelled,1);
 app.onGenerate=async()=>script();await app.generate();app.revision=4;app.applyCandidate();assert.equal(writes.length,0);assert.match(app.error,/版本/);
});
test('native model errors preserve the existing node data and expose a retryable message',async()=>{
 const {app,writes}=page();app.onGenerate=async()=>{throw Error('网关未配置')};await app.generate();assert.equal(app.generating,false);assert.match(app.error,/未配置/);assert.equal(app.explanation,'笔记');assert.equal(writes.length,0);
});
const {LessonPlayer}=await import(url(`import {visualLesson} from '${catalogURL}';\n`+cleanComponent('LessonPlayer')+'\n}'));
test('native playback is bounded and reduced-motion or leaving the page stops its timer',()=>{
 const player=new LessonPlayer();player.advance(-1);assert.equal(player.step,0);player.advance(999);assert.equal(player.step,player.lesson.steps.length-1);
 player.reduceMotion=true;player.toggle();assert.equal(player.playing,false);
 player.reduceMotion=false;player.toggle();assert.equal(player.step,0);assert.equal(player.playing,true);player.aboutToDisappear();assert.equal(player.playing,false);assert.equal(player.timer,-1);
});
