import test from 'node:test';
import assert from 'node:assert/strict';
import { stripTypeScriptTypes } from 'node:module';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const stage=mkdtempSync(join(tmpdir(),'flowspace-canvas-test-'));
for(const [source,target] of [['domain/MindMap','MindMap'],['canvas/MapLayout','MapLayout'],['canvas/MindMapCanvas','MindMapCanvas']]) {
  let text=readFileSync(join(root,'entry/src/main/ets',source+'.ets'),'utf8');
  text=text.replace(/^import .* from '@(?:kit|ohos)[^']+';\r?\n/gm,'');
  if(target==='MindMapCanvas') {
    // Remove only declarative ArkUI syntax. Keep all actual fit, pan/zoom,
    // selection, document refresh and painting method implementations.
    const build=text.indexOf('  build() {');
    assert.ok(build>0,'component build() signature changed: review test adapter');
    text=text.slice(0,build)+'\n}\n';
    text=text.replace(/^@ComponentV2\r?\n/gm,'').replace('export struct MindMapCanvas','export class MindMapCanvas')
      .replace(/^  @(?:Param|Event) /gm,'  ').replace(/^  @Monitor\([^\n]+\)\r?\n/gm,'');
  }
  text=text.replace(/from '(?:\.\/|\.\.\/domain\/)(MindMap|MapLayout)'/g,"from './$1.mjs'")
    .replace(/import \{([^}]+)\} from '\.\/(MindMap|MapLayout)\.mjs'/g,(_,names,module)=>
      'import {'+names.split(',').map(n=>n.trim()).filter(n=>['createDocument','cloneDocument','newId','layoutMap','nodeLines'].includes(n)).join(',')+"} from './"+module+".mjs'");
  writeFileSync(join(stage,target+'.mjs'),stripTypeScriptTypes(text,{mode:'transform'}));
}
// Native constructors are the sole adapter for component instantiation.
// ready remains false, so paint() exits before invoking native drawing APIs.
globalThis.RenderingContextSettings=class {};
globalThis.CanvasRenderingContext2D=class {};
globalThis.ConfigurationConstant={ColorMode:{COLOR_MODE_DARK:0,COLOR_MODE_LIGHT:1}};
const {createDocument}=await import(pathToFileURL(join(stage,'MindMap.mjs')));
const {layoutMap,nodeLines}=await import(pathToFileURL(join(stage,'MapLayout.mjs')));
const {MindMapCanvas}=await import(pathToFileURL(join(stage,'MindMapCanvas.mjs')));
test.after(()=>{
  rmSync(stage,{recursive:true,force:true});
  delete globalThis.RenderingContextSettings; delete globalThis.CanvasRenderingContext2D; delete globalThis.ConfigurationConstant;
});

function document(count,layout='right',shape='balanced',long=false) {
  const doc=createDocument('自然语言导图'); doc.layout=layout;
  if(long) doc.nodes[0].text='中'.repeat(500);
  for(let i=1;i<count;i++) doc.nodes.push({id:'n'+i,parentId:shape==='star'||i<=4?doc.rootId:'n'+Math.floor((i-1)/4),
    order:i,text:long?'中'.repeat(500):'节点'+i+'：整理关键概念与逻辑',note:'',collapsed:false});
  return doc;
}
function assertNoOverlap(scene) {
  for(let i=0;i<scene.nodes.length;i++) {
    const a=scene.nodes[i];
    assert.ok(a.x>=0&&a.y>=0&&a.width>0&&a.height>0);
    assert.ok(a.x+a.width<=scene.width&&a.y+a.height<=scene.height,'scene bounds clip node '+a.id);
    for(let j=i+1;j<scene.nodes.length;j++) {
      const b=scene.nodes[j];
      const overlap=Math.min(a.x+a.width,b.x+b.width)>Math.max(a.x,b.x)+1e-8 &&
        Math.min(a.y+a.height,b.y+b.height)>Math.max(a.y,b.y)+1e-8;
      assert.equal(overlap,false,`intersecting rectangles ${a.id} and ${b.id}`);
    }
  }
}
function controller(doc,width=390,height=440) {
  const c=new MindMapCanvas(); c.document=doc; c.rebuildScene();
  c.viewportWidth=width; c.viewportHeight=height;
  c.fit(); return c;
}
function assertFits(c) {
  assert.ok(Number.isFinite(c.zoom)&&c.zoom>0);
  for(const n of c.scene.nodes) {
    const left=n.x*c.zoom+c.panX,top=n.y*c.zoom+c.panY;
    const right=(n.x+n.width)*c.zoom+c.panX,bottom=(n.y+n.height)*c.zoom+c.panY;
    assert.ok(left>=-1e-6&&top>=-1e-6&&right<=c.viewportWidth+1e-6&&bottom<=c.viewportHeight+1e-6,
      `fit clips ${n.id}, viewport ${c.viewportWidth}×${c.viewportHeight}, bounds ${[left,top,right,bottom]}, zoom ${c.zoom}`);
  }
}

for(const count of [200,500]) for(const orientation of ['right','down']) {
  test(`${count} ${orientation} balanced nodes have disjoint rectangles and leave input unchanged`,t=>{
    const doc=document(count,orientation),before=structuredClone(doc);
    doc.nodes.forEach(Object.freeze); Object.freeze(doc.nodes); Object.freeze(doc);
    const start=performance.now(),scene=layoutMap(doc),elapsed=performance.now()-start;
    assert.equal(scene.nodes.length,count); assertNoOverlap(scene); assert.deepEqual(doc,before);
    t.diagnostic(`Node-only layout calculation: ${elapsed.toFixed(3)} ms; not device drawing/FPS evidence.`);
  });
}

test('long Chinese labels wrap without lost characters and node height contains every line',()=>{
  const text='自然语言生成思维导图'.repeat(38).slice(0,500);
  const wrapped=nodeLines(text);
  assert.equal(wrapped.join(''),text); assert.ok(wrapped.every(line=>line.length<=10));
  assert.equal(nodeLines('中文\n换行').join('|'),'中文|换行');
  const doc=document(200,'right'); doc.nodes[50].text=text;
  const scene=layoutMap(doc),node=scene.nodes.find(n=>n.id==='n50');
  assert.ok(node.height>=node.lines.length*22+26); assertNoOverlap(scene);
});

test('line wrapping never splits an emoji surrogate pair between Canvas drawText lines',()=>{
  const text='中'.repeat(9)+'🙂尾';
  const wrapped=nodeLines(text);
  assert.equal(wrapped.join(''),text);
  for(const line of wrapped) {
    assert.ok(!/[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(line),
      'line contains isolated UTF16 surrogate: '+JSON.stringify(line));
  }
});

test('collapsed branches hide only descendants and preserve immutable domain data',()=>{
  const doc=document(200,'down'); doc.nodes.find(n=>n.id==='n1').collapsed=true;
  const before=structuredClone(doc),hidden=new Set(['n1']);
  for(let pass=0;pass<8;pass++) for(const n of doc.nodes) if(hidden.has(n.parentId)) hidden.add(n.id);
  const scene=layoutMap(doc);
  assert.equal(scene.nodes.length,200-hidden.size+1); assert.ok(scene.nodes.some(n=>n.id==='n1'));
  assert.ok(scene.nodes.filter(n=>n.id!=='n1').every(n=>!hidden.has(n.id)));
  assert.equal(scene.nodes.find(n=>n.id==='n1').childCount,4); assert.deepEqual(doc,before);
  doc.nodes[0].collapsed=true; assert.equal(layoutMap(doc).nodes.length,1);
});

for(const width of [320,360,390,480]) {
  test(`actual fit() includes all 200/500 balanced and star nodes in ${width}vp phone viewport`,()=>{
    for(const count of [200,500]) for(const orientation of ['right','down']) for(const shape of ['balanced','star']) {
      assertFits(controller(document(count,orientation,shape),width,360));
    }
  });
}

test('actual selectAt() chooses correct node after fit, pan and zoom; empty area is unchanged',()=>{
  const c=controller(document(200,'right')); let selected=''; c.onSelect=id=>{selected=id;};
  for(const index of [0,1,50,199]) {
    const n=c.scene.nodes[index]; selected='';
    c.selectAt((n.x+n.width/2)*c.zoom+c.panX,(n.y+n.height/2)*c.zoom+c.panY);
    assert.equal(selected,n.id);
  }
  c.panX-=120; c.panY+=37; c.setZoom(c.zoom*1.7);
  const n=c.scene.nodes[90];
  c.selectAt((n.x+n.width/2)*c.zoom+c.panX,(n.y+n.height/2)*c.zoom+c.panY);
  assert.equal(selected,n.id); selected='unchanged'; c.selectAt(-1e9,-1e9); assert.equal(selected,'unchanged');
});

test('actual setZoom() keeps map-space viewport center invariant and emits displayed percentage',()=>{
  const c=controller(document(500,'down')); c.panX+=11; c.panY-=29; const reported=[]; c.onZoom=p=>reported.push(p);
  for(const factor of [1.2,1/1.2,3,0.5]) {
    const x=(c.viewportWidth/2-c.panX)/c.zoom,y=(c.viewportHeight/2-c.panY)/c.zoom;
    c.setZoom(c.zoom*factor);
    assert.ok(Math.abs((c.viewportWidth/2-c.panX)/c.zoom-x)<1e-6);
    assert.ok(Math.abs((c.viewportHeight/2-c.panY)/c.zoom-y)<1e-6);
    assert.equal(reported.at(-1),Math.round(c.zoom*1000)/10);
  }
});

test('document refresh retains viewport for same document and fits when switching documents',()=>{
  const c=controller(document(200)); c.currentDocumentId=c.document.documentId;
  c.panX=123; c.panY=-84; const zoom=c.zoom; c.refreshDocument();
  assert.equal(c.panX,123); assert.equal(c.panY,-84); assert.equal(c.zoom,zoom);
  c.document=document(500,'down'); c.refreshDocument(); assertFits(c);
  assert.equal(c.currentDocumentId,c.document.documentId);
});

test('maximum legal 500-node long-label star fits completely in compact phone viewport',()=>{
  for(const orientation of ['right','down']) assertFits(controller(document(500,orientation,'star',true),320,280));
});

test('viewport repeats retain 50% zoom and resize keeps world-space center without auto-fit',()=>{
  const c=controller(document(200)); c.ready=true; c.paint=()=>{};
  c.setZoom(0.5); c.panX+=31; c.panY-=45;
  const before={x:c.panX,y:c.panY,zoom:c.zoom};
  c.updateViewport(c.viewportWidth,c.viewportHeight);
  assert.deepEqual({x:c.panX,y:c.panY,zoom:c.zoom},before);
  const x=(c.viewportWidth/2-c.panX)/c.zoom,y=(c.viewportHeight/2-c.panY)/c.zoom;
  c.updateViewport(480,320);
  assert.equal(c.zoom,0.5);
  assert.equal((c.viewportWidth/2-c.panX)/c.zoom,x);
  assert.equal((c.viewportHeight/2-c.panY)/c.zoom,y);
  const actual={w:c.viewportWidth,h:c.viewportHeight,x:c.panX,y:c.panY};
  c.updateViewport(0,0); c.updateViewport(NaN,480);
  assert.deepEqual({w:c.viewportWidth,h:c.viewportHeight,x:c.panX,y:c.panY},actual);
});

test('first usable viewport fits once and explicit fit still restores complete scene',()=>{
  const c=new MindMapCanvas(); c.document=document(500,'down'); c.rebuildScene(); c.paint=()=>{};
  c.updateViewport(320,360); assert.equal(c.needsFit,true);
  c.ready=true; c.updateViewport(320,361); assert.equal(c.needsFit,false); assertFits(c);
  c.setZoom(0.5); c.panX=-200; c.requestFit(); assertFits(c);
});

test('candidate preview with stable document ID retains 50% transform and rebuilds index',()=>{
  const c=controller(document(200)); c.currentDocumentId=c.document.documentId; c.setZoom(0.5);
  c.panX+=71; c.panY-=19; const transform={x:c.panX,y:c.panY,z:c.zoom},previous=c.nodeIndex;
  const candidate=structuredClone(c.document); candidate.nodes[1].text='候选修改';
  candidate.nodes.push({id:'new_candidate',parentId:candidate.rootId,order:500,text:'候选节点',note:'',collapsed:false});
  c.document=candidate; c.refreshDocument();
  assert.deepEqual({x:c.panX,y:c.panY,z:c.zoom},transform);
  assert.notEqual(c.nodeIndex,previous); assert.equal(c.nodeIndex.size,201); assert.ok(c.nodeIndex.has('new_candidate'));
});

test('cancelled pan and pinch restore the exact captured transform',()=>{
  const c=controller(document(200));
  const start={x:c.panX,y:c.panY,z:c.zoom};
  c.beginPan(); c.updatePan(121,-47); assert.notEqual(c.panX,start.x); c.cancelPan();
  assert.deepEqual({x:c.panX,y:c.panY,z:c.zoom},start);
  c.beginPinch(); c.setZoom(c.zoom*1.8); c.cancelPinch();
  assert.deepEqual({x:c.panX,y:c.panY,z:c.zoom},start);
});

function recordingContext() {
  return {
    calls:[],fillStyle:'',strokeStyle:'',lineWidth:1,font:'',textBaseline:'',
    clearRect(){this.calls.push({kind:'clear'});},save(){},restore(){},translate(){},scale(){},
    fillRect(){this.calls.push({kind:'dot',color:this.fillStyle});},beginPath(){},moveTo(){},bezierCurveTo(){},
    stroke(){this.calls.push({kind:'stroke',color:this.strokeStyle,width:this.lineWidth});},roundRect(){},arc(){},
    fill(){this.calls.push({kind:'fill',color:this.fillStyle});},
    fillText(text){this.calls.push({kind:'text',text,color:this.fillStyle});}
  };
}
const paletteFiles={
  light:JSON.parse(readFileSync(join(root,'entry/src/main/resources/base/element/color.json'),'utf8')).color,
  dark:JSON.parse(readFileSync(join(root,'entry/src/main/resources/dark/element/color.json'),'utf8')).color
};
function attachHost(c) {
  const state={mode:'light',reads:0,subscribed:null,unsubscribed:[],next:7};
  const app={on(type,callback){assert.equal(type,'environment');state.subscribed=callback;return state.next;},
    async off(type,id){assert.equal(type,'environment');state.unsubscribed.push(id);}};
  c.getUIContext=()=>({getHostContext:()=>({getApplicationContext:()=>app,
    resourceManager:{getColorSync(resource){
      state.reads++;
      const color=paletteFiles[state.mode].find(item=>resource==='app.color.'+item.name);
      assert.ok(color,'unknown semantic canvas color '+resource);
      return Number.parseInt(color.value.slice(1),16);
    }}})});
  return state;
}

test('500-node painting uses cached parent index and palette, including selected semantic colors',()=>{
  globalThis.$r=resource=>resource;
  try {
    const c=controller(document(500)); c.ready=true; c.context=recordingContext(); const host=attachHost(c);
    const index=c.nodeIndex; let gets=0; const get=index.get.bind(index); index.get=id=>{gets++;return get(id);};
    c.scene.nodes.find=()=>{throw Error('paint must not perform per-node linear parent lookup');};
    c.selectedNodeId='n1'; c.paint(); assert.equal(gets,500); assert.equal(host.reads,8);
    assert.ok(c.context.calls.some(call=>call.kind==='fill'&&call.color.toUpperCase()==='#ECECFA'));
    assert.ok(c.context.calls.some(call=>call.kind==='stroke'&&call.width===2.5));
    const dots=c.context.calls.filter(call=>call.kind==='dot').length;
    assert.ok(dots>0&&dots<1000,'grid work must scale with viewport rather than scene size');
    c.beginPan(); c.updatePan(30,-20);
    assert.equal(c.nodeIndex,index); assert.equal(gets,1000); assert.equal(host.reads,8);
  } finally {delete globalThis.$r;}
});

test('appearance and system configuration repaint with dark on-accent contrast and unsubscribe',async()=>{
  globalThis.$r=resource=>resource;
  const c=controller(document(20)); c.ready=true; c.context=recordingContext(); const host=attachHost(c);
  try {
    c.aboutToAppear(); await new Promise(resolve=>setTimeout(resolve,10));
    assert.ok(host.subscribed); assert.ok(c.context.calls.some(call=>call.kind==='text'&&call.color==='#ffffff'));
    host.mode='dark'; c.appearance='dark'; c.refreshAppearance(); await new Promise(resolve=>setTimeout(resolve,10));
    const root=c.scene.nodes[0],rootLabel=root.lines[0];
    assert.equal(c.context.calls.filter(call=>call.kind==='text'&&call.text===rootLabel).at(-1).color,'#171630');
    assert.ok(c.context.calls.some(call=>call.kind==='fill'&&call.color==='#b1aeff'));
    c.appearance='system'; host.mode='light'; const reads=host.reads;
    host.subscribed.onConfigurationUpdated({colorMode:1}); await new Promise(resolve=>setTimeout(resolve,10));
    assert.equal(host.reads,reads+8);
    c.aboutToDisappear(); await Promise.resolve(); assert.deepEqual(host.unsubscribed,[7]);
    assert.equal(c.environmentId,-1); assert.equal(c.paintTimer,-1);
  } finally { c.aboutToDisappear(); delete globalThis.$r; }
});

test('the ten-node example fits a 360vp phone without fixed-width empty label gutters', () => {
  const example = JSON.parse(readFileSync(join(root, 'entry/src/main/resources/rawfile/example-mindmap.json'), 'utf8')).document;
  const c = controller(example, 360, 475);
  assertFits(c);
  assert.ok(c.zoom >= 0.78, 'Short labels should remain legible when all ten nodes fit');
  assert.ok(c.scene.nodes.every(node => node.width < 150));
});

test('solid semantic colors stay visible when the resource backend returns zero', () => {
  globalThis.$r = value => value;
  const c = controller(document(1));
  c.getUIContext = () => ({getHostContext: () => ({config:{colorMode:0},resourceManager:{getColorSync: () => 0}})});
  try {
    assert.equal(c.getPalette().accent.toLowerCase(), '#b1aeff');
    assert.equal(c.getPalette().onAccent.toLowerCase(), '#171630');
  } finally { delete globalThis.$r; }
});

test('tapping a branch disclosure toggles that node, tapping the label only selects it', () => {
  const doc = document(5);
  const c = controller(doc);
  const node = c.scene.nodes[0];
  const selected = [], toggled = [];
  c.onSelect = id => selected.push(id);
  c.onToggle = id => toggled.push(id);
  c.selectAt((node.x + node.width) * c.zoom + c.panX, (node.y + node.height / 2) * c.zoom + c.panY);
  c.selectAt((node.x + 16) * c.zoom + c.panX, (node.y + node.height / 2) * c.zoom + c.panY);
  assert.deepEqual(selected, [doc.rootId, doc.rootId]);
  assert.deepEqual(toggled, [doc.rootId]);
});
