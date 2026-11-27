// Included by tools/sync-learning-preview.mjs; same schema and built-ins as native.
let studyState=null, studyTimer=0, studyController=null;
function stopStudy(){if(studyTimer)clearInterval(studyTimer);studyTimer=0}
function studyIsReduced(){return !!settings.reduceMotion||matchMedia('(prefers-reduced-motion: reduce)').matches}
function openStudy(rid=''){
  stopStudy();
  const node=rid?null:current.nodes.find(n=>n.id===selected);
  if(activeGeneration||candidate){toast('请先完成或放弃当前导图生成。');return}if(!rid&&!node){toast('先选择一个节点');return}
  let parsed={text:'',study:emptyStudy()},error='';
  try{if(node)parsed=decodeStudyNote(node.note)}catch(e){error=e.message}
  studyState={nodeId:node?.id||'',documentId:current.documentId,revision:current.revision,title:node?.text||'知识动态讲解',note:parsed,step:0,builtIn:rid,candidate:null,generationRevision:-1,error,damaged:!!error,returnPage:page,editing:false};
  $('#study-overlay').hidden=false;document.querySelector('.app').inert=true;renderStudy();
}
function closeStudy(){
  if(studyState?.candidate||studyController||studyState?.editing){
    if(!confirm('离开会放弃未保存的资料/候选并取消生成，是否继续？'))return;
  }
  stopStudy();studyController?.abort();studyController=null;$('#study-overlay').hidden=true;document.querySelector('.app').inert=false;studyState=null;
}
function studyActive(){return studyState.candidate||(studyState.builtIn?visualLesson(studyState.builtIn):studyState.note.study.generated)||visualLesson(studyState.note.study.lessonId)}
function studyStep(delta){stopStudy();const lesson=studyActive();studyState.step=Math.max(0,Math.min(lesson.steps.length-1,studyState.step+delta));renderStudy()}
function playStudy(){
  if(studyTimer){stopStudy();renderStudy();return}
  if(studyIsReduced())return;
  if(studyState.step===studyActive().steps.length-1)studyState.step=0;
  studyTimer=setInterval(()=>{if(!studyState){stopStudy();return}if(studyState.step<studyActive().steps.length-1)studyState.step++;if(studyState.step===studyActive().steps.length-1)stopStudy();renderStudy()},2200);renderStudy();
}
function selectStudyDemo(id){stopStudy();studyState.builtIn=id;studyState.step=0;renderStudy()}
function renderStudy(){
 const s=studyState;if(!s)return;const meta=s.note.study;
 const has=!!(s.candidate||s.builtIn||meta.generated||meta.lessonId),lesson=studyActive(),frame=lesson.steps[s.step]||lesson.steps[0];
 const e=esc;let diagram='';
 const cells=frame.cells.map((text,i)=>({text,i}));if(lesson.kind==='stack')cells.reverse();
 diagram=cells.map(({text,i})=>`<div class="study-cell-wrap">${lesson.kind==='array'?`<small>${i}</small>`:''}<div class="study-cell ${i===frame.active?'active':''}">${e(text)}</div>${['array','stack'].includes(lesson.kind)?`<small class="study-pointer">${frame.start===i?(lesson.kind==='stack'?'top':'start'):''}${frame.end===i?' end':''}</small>`:''}</div>${lesson.kind==='flow'&&i<cells.length-1?'<span class="study-flow-arrow">↓</span>':''}`).join('');
 $('#study-heading').textContent=s.title;
 $('#study-body').innerHTML=`${s.error?`<p class="study-error" role="alert">${e(s.error)}</p>`:''}${s.nodeId?`<div class="study-intro">${e(s.note.text||'为这个节点添加知识说明、资料链接或代码，再生成分步讲解。')}</div><button class="secondary" onclick="editStudy()" ${s.damaged||s.candidate||studyController?'disabled':''}>编辑说明、链接与代码</button><div class="study-block"><h2>AI 动态讲解</h2><p>按当前节点生成，可覆盖任意主题。链接未读取全文；代码仅展示，不执行。生成结果先预览，确认后保存。</p><textarea id="study-instruction" maxlength="2000" placeholder="补充讲解要求：类比、推导、例子、反例…">${e(s.instruction||'')}</textarea><div class="row wrap"><button class="primary" onclick="generateStudy()" ${s.damaged||s.candidate||studyController?'disabled':''}>${studyController?'正在生成…':meta.generated?'重新生成讲解':'生成动态讲解'}</button>${studyController?'<button class="secondary" onclick="cancelStudyGeneration()">取消生成</button>':''}</div><p class="muted">通过当前页面的真实模型网关生成；离线或未配置时显示错误。</p></div>`:'<p class="muted">内置教学演示。给任意节点生成 AI 讲解，请在 DIY 选中节点后打开“学习详情”。</p>'}
 ${s.candidate?`<div class="study-candidate"><strong>AI 候选 · 尚未保存，请核对知识与步骤</strong><div class="row"><button class="secondary" onclick="discardStudyCandidate()">放弃</button><button class="primary" onclick="applyStudyCandidate()">应用并保存</button></div></div>`:''}
 ${has?`<section class="study-block"><div class="row spread"><h2>${e(lesson.title)}</h2><span class="muted">${s.step+1}/${lesson.steps.length}</span></div><progress max="${lesson.steps.length}" value="${s.step+1}"></progress><p class="muted">${e(lesson.summary)}</p><p class="study-origin">${s.candidate||(!s.builtIn&&meta.generated)?'AI 生成 · 请核对事实与来源':'内置演示 · 非本次 AI 生成'}</p><div class="study-scene"><h3>${e(frame.title)}</h3><div class="study-diagram ${e(lesson.kind)}">${diagram||'<p class="muted">空结构 · 暂无元素</p>'}</div><div class="study-operation">${e(frame.operation)}</div><p>${e(frame.explanation)}</p></div><div class="study-controls"><button class="secondary" onclick="studyStep(-1)" ${s.step===0?'disabled':''}>上一步</button><button class="primary" onclick="playStudy()" ${studyIsReduced()?'disabled':''}>${studyTimer?'暂停':s.step===lesson.steps.length-1?'重播':'播放'}</button><button class="secondary" onclick="studyStep(1)" ${s.step===lesson.steps.length-1?'disabled':''}>下一步</button></div>${studyIsReduced()?'<p class="muted">减少动效已开启，请手动切换步骤。</p>':''}<h3>关键规律 / 注意事项</h3><p>${e(lesson.invariant)}</p>${lesson.code.length?`<h3>逐行代码 · 与步骤对应</h3><pre class="study-code">${lesson.code.map((line,i)=>`<span class="${i===frame.codeLine?'current':''}">${i+1}  ${e(line)}</span>`).join('')}</pre>`:''}${lesson.sourceUrl?`<a class="external-resource secondary" href="${e(lesson.sourceUrl)}" target="_blank" rel="noopener noreferrer">${e(lesson.sourceTitle||'参考来源')} ↗</a>`:''}</section>`:''}
 ${meta.links.length?`<section class="study-block"><h2>节点资料</h2>${meta.links.map(l=>`<a class="external-resource secondary" href="${e(l.url)}" target="_blank" rel="noopener noreferrer">${e(l.title)} ↗</a>`).join('')}</section>`:''}
 ${meta.code?`<section class="study-block"><h2>附带代码 · ${e(meta.language)}</h2><pre class="study-code">${e(meta.code)}</pre></section>`:''}
 <section class="study-block"><h3>内置演示 · 切换不修改节点</h3><div class="row wrap">${VISUAL_LESSONS.map(l=>`<button class="${s.builtIn===l.id?'primary':'secondary'}" onclick="selectStudyDemo('${l.id}')">${e(l.title)}</button>`).join('')}${meta.generated||s.candidate?'<button class="secondary" onclick="selectStudyDemo(\'\')">返回 AI 讲解</button>':''}</div></section>`;
}
function saveStudy(note,revision){
 const s=studyState;if(!s||s.documentId!==current.documentId||revision!==current.revision||candidate)return false;
 const node=current.nodes.find(n=>n.id===s.nodeId);if(!node)return false;
 decodeStudyNote(note);if(activeGeneration||!applyEdit(()=>{current.nodes.find(n=>n.id===s.nodeId).note=note}))return false;s.revision=current.revision;s.note=decodeStudyNote(note);return true;
}
function editStudy(){
 const s=studyState;if(!s||!s.nodeId||s.damaged)return;stopStudy();s.editing=true;s.editRevision=current.revision;
 $('#study-body').innerHTML=`<form id="study-edit" onsubmit="event.preventDefault();saveStudyForm()"><h2>编辑节点资料</h2><label>知识说明<textarea id="study-note-text" maxlength="10000">${esc(s.note.text)}</textarea></label><label>链接，每行“标题 | https://地址”，最多8条<textarea id="study-links" rows="4">${esc(s.note.study.links.map(l=>l.title+' | '+l.url).join('\n'))}</textarea></label><label>代码语言<input id="study-language" maxlength="30" value="${esc(s.note.study.language)}"></label><label>代码（只展示，不执行）<textarea id="study-code-input" maxlength="6000" rows="10">${esc(s.note.study.code)}</textarea></label><p id="study-form-error" class="study-error" role="alert"></p><div class="row"><button type="button" class="secondary" onclick="cancelStudyEdit()">取消</button><button type="submit" class="primary">保存资料</button></div></form>`;
}
function cancelStudyEdit(){if(!confirm('放弃未保存的编辑？'))return;studyState.editing=false;renderStudy()}
function saveStudyForm(){
 try{const links=$('#study-links').value.split('\n').filter(l=>l.trim()).map(line=>{const i=line.indexOf('|');if(i<0)throw Error('链接格式应为 标题 | https://地址');return {title:line.slice(0,i).trim(),url:line.slice(i+1).trim()}});
 const meta={...studyState.note.study,links,language:$('#study-language').value.trim(),code:$('#study-code-input').value};
 const note=encodeStudyNote($('#study-note-text').value,meta);
 if(!saveStudy(note,studyState.editRevision))throw Error('节点版本已变化，输入已保留，请返回确认。');studyState.editing=false;renderStudy();toast('节点资料已保存，可撤销');
 }catch(e){$('#study-form-error').textContent=e.message}
}
async function generateStudy(){
 const s=studyState;if(!s||studyController||s.candidate)return;
 s.instruction=$('#study-instruction').value;s.generationRevision=current.revision;
 const base=gatewayOrigin;
 if(!/^https?:\/\/[^\s]+$/.test(base)){s.error='请先启动模型网关，并从网关页面打开应用。';renderStudy();return}
 const controller=new AbortController();studyController=controller;s.error='';renderStudy();
 const request={requestId:'lesson-'+id(),documentId:s.documentId,nodeId:s.nodeId,baseRevision:s.generationRevision,topic:s.title,instruction:s.instruction,context:s.note.text,code:s.note.study.code,links:s.note.study.links};
 const timeout=setTimeout(()=>controller.abort(),180000);
 try{const response=await fetch('/api/lessons/generate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(request),signal:controller.signal});
 const raw=await response.text();if(raw.length>131072)throw Error('讲解响应过大');const data=JSON.parse(raw);
 if(!response.ok)throw Error(data.message||'生成失败：HTTP '+response.status);
 if(data.requestId!==request.requestId||data.documentId!==request.documentId||data.nodeId!==request.nodeId||data.baseRevision!==request.baseRevision)throw Error('返回结果不属于当前节点版本');
 validateLesson(data.script);if(data.script.sourceUrl&&!request.links.some(l=>l.url===data.script.sourceUrl))throw Error('讲解来源未在提供的链接中');
 if(studyState!==s||controller.signal.aborted)return;s.candidate=data.script;s.step=0;s.builtIn='';
 }catch(e){if(studyState===s)s.error=controller.signal.aborted?'讲解生成已取消或超时，节点资料保留。':e.message}
 finally{clearTimeout(timeout);if(studyController===controller)studyController=null;if(studyState===s)renderStudy()}
}
function cancelStudyGeneration(){studyController?.abort()}
function discardStudyCandidate(){stopStudy();studyState.candidate=null;studyState.step=0;renderStudy()}
function applyStudyCandidate(){
 try{const s=studyState;if(!s.candidate)return;
 const note=encodeStudyNote(s.note.text,{...s.note.study,generated:s.candidate});
 if(!saveStudy(note,s.generationRevision))throw Error('节点已有修改，旧候选不能覆盖新版本，请放弃后重新生成。');s.candidate=null;s.builtIn='';s.step=0;renderStudy();toast('动态讲解已保存，可撤销');
 }catch(e){studyState.error=e.message;renderStudy()}
}

matchMedia('(prefers-reduced-motion: reduce)').addEventListener('change',()=>{if(studyIsReduced())stopStudy();if(studyState&&!studyState.editing)renderStudy()});
