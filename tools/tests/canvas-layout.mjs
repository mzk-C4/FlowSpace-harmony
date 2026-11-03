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
const {createDocument}=await import(pathToFileURL(join(stage,'MindMap.mjs')));
const {layoutMap,nodeLines}=await import(pathToFileURL(join(stage,'MapLayout.mjs')));
const {MindMapCanvas}=await import(pathToFileURL(join(stage,'MindMapCanvas.mjs')));
test.after(()=>{
  rmSync(stage,{recursive:true,force:true});
  delete globalThis.RenderingContextSettings; delete globalThis.CanvasRenderingContext2D;
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
  const c=new MindMapCanvas(); c.document=doc; c.scene=layoutMap(doc);
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
