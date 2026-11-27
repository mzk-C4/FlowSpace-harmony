import {readFileSync,writeFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
const root=new URL('../',import.meta.url),modules=['LessonScript','NodeLearning','LessonCatalog'];
const code=modules.map(name=>{
 const source=readFileSync(new URL(`entry/src/main/ets/learning/${name}.ets`,root),'utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export \{.*;\r?\n/gm,'');
 return stripTypeScriptTypes(source,{mode:'transform'}).replace(/^export /gm,'');
}).join('\n');
const ui=readFileSync(new URL('docs/preview/learning-ui.js',root),'utf8');
const file=new URL('docs/preview/index.html',root);let html=readFileSync(file,'utf8');
const start='// BEGIN GENERATED NODE LEARNING',end='// END GENERATED NODE LEARNING';
const section=start+'\n'+code+'\n'+ui+'\n'+end;
if(html.includes(start))html=html.slice(0,html.indexOf(start))+section+html.slice(html.indexOf(end)+end.length);
else html=html.replace("applyTheme();renderRecent();renderVideos();renderResources();renderDocuments();renderEditor();",section+"\napplyTheme();renderRecent();renderVideos();renderResources();renderDocuments();renderEditor();");
writeFileSync(file,html);console.log('Synced learning schema, saved note format, lessons and learning UI into standalone preview.');
