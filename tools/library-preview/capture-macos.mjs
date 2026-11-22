// Native component preview with an isolated host; never modifies release routes.
// Node 24+: node tools/library-preview/capture-macos.mjs [light|dark] [steps.json]
import { cpSync, copyFileSync, readFileSync, writeFileSync, mkdirSync, mkdtempSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { spawn } from 'node:child_process';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const studio=process.env.FLOWSPACE_DEVECO||'/Applications/DevEco-Studio.app/Contents';
const stage=mkdtempSync(join(tmpdir(),'flowspace-library-preview-'));
for(const directory of ['AppScope','entry/src','hvigor'])cpSync(join(root,directory),join(stage,directory),{recursive:true});
for(const file of ['build-profile.json5','oh-package.json5','hvigorfile.ts','entry/build-profile.json5','entry/oh-package.json5','entry/hvigorfile.ts'])copyFileSync(join(root,file),join(stage,file));
copyFileSync(join(root,'tools/library-preview/LibraryPreview.ets'),join(stage,'entry/src/main/ets/pages/LibraryPreview.ets'));
const routes=join(stage,'entry/src/main/resources/base/profile/main_pages.json');
const pages=JSON.parse(readFileSync(routes,'utf8'));pages.src.push('pages/LibraryPreview');writeFileSync(routes,JSON.stringify(pages));
const output=process.env.FLOWSPACE_LIBRARY_OUTPUT||join(root,'artifacts/library-preview');mkdirSync(output,{recursive:true});
const env={...process.env,DEVECO_SDK_HOME:join(studio,'sdk'),JAVA_HOME:join(studio,'jbr/Contents/Home'),NODE_HOME:join(studio,'tools/node'),FLOWSPACE_LIBRARY_OUTPUT:output};
let log='';
await new Promise((resolve,reject)=>{
 const child=spawn(join(studio,'tools/hvigor/bin/hvigorw'),['--mode','module','-p','product=default','-p','module=entry@default','-p','buildMode=debug','-p','pageType=page','-p','previewMode=true','-p','buildRoot=.preview','PreviewBuild','--no-daemon'],{cwd:stage,env,detached:true});
 let done=false;
 const finish=(error)=>{if(done)return;done=true;clearTimeout(timer);writeFileSync(join(output,'preview-build.log'),log);try{process.kill(-child.pid,'SIGTERM')}catch{}error?reject(error):resolve()};
 const collect=b=>{log+=b.toString();if(log.includes('BUILD SUCCESSFUL'))finish()};
 child.stdout.on('data',collect);child.stderr.on('data',collect);child.once('error',finish);
 child.once('exit',code=>{if(!done)finish(new Error(`PreviewBuild exited ${code}; inspect ${join(output,'preview-build.log')}`))});
 const timer=setTimeout(()=>finish(new Error('PreviewBuild timed out; inspect preview-build.log')),60000);
});
const defaultSteps=join(stage,'capture-steps.json');
writeFileSync(defaultSteps,JSON.stringify([{name:'filter',tap:[380,600],waitMs:1000},{name:'details',tap:[500,1030],waitMs:1300}]));
const steps=process.argv[3]?resolve(process.argv[3]):defaultSteps;
const child=spawn(process.execPath,[join(root,'tools/library-preview/render-native.mjs'),stage,'pages/LibraryPreview',process.argv[2]||'light',steps],{cwd:root,env,stdio:'inherit'});
const code=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve)});
console.log('Preview host: '+stage+' (component screenshot only; no device/database/model validation)');
process.exitCode=code||0;
