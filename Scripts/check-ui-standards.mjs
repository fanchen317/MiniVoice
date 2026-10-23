import {readdir,readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {contentViolations,componentViolations} from './ui-standards-rules.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),failures=[];
async function walk(folder){const rows=await readdir(path.join(root,folder),{withFileTypes:true});return (await Promise.all(rows.map(row=>row.isDirectory()?walk(`${folder}/${row.name}`):`${folder}/${row.name}`))).flat();}
const files=(await Promise.all(['Shared/UI/src','MacOS/Desktop/src'].map(walk))).flat().filter(file=>/\.(?:jsx|js)$/.test(file));
for(const file of files){const source=await readFile(path.join(root,file),'utf8');for(const error of [...contentViolations(source,file),...componentViolations(source,file)])failures.push(`${file}: ${error}`);}
const manifest=await readFile(path.join(root,'Android/app/src/main/AndroidManifest.xml'),'utf8');
const portable=manifest.match(/<activity\b[^>]*android:name="\.PortablePlayerActivity"[^>]*>([\s\S]*?)<\/activity>/)?.[1]||'';
if(!portable.includes('android.intent.category.LAUNCHER'))failures.push('Android 默认启动器必须进入自有内容界面');
const host=await readFile(path.join(root,'Android/app/src/main/java/com/xcosmos/minivoice/PortablePlayerActivity.java'),'utf8');
if(/new Intent\([^)]*MainActivity\.class/.test(host))failures.push('Android 自有界面不得回退到旧 MainActivity 内容');
if(/(?:Toast\.makeText|AlertDialog|BottomSheet\.)/.test(host))failures.push('Android 内容宿主不得创建原生提示/内容面板');
for(const file of ['PlaybackService.java','LibraryScanService.java']){const source=await readFile(path.join(root,'Android/app/src/main/java/com/xcosmos/minivoice',file),'utf8');if(/new Intent\([^)]*MainActivity\.class/.test(source))failures.push(`${file}: 通知入口必须进入自有界面`);}
if(failures.length){console.error('MiniVoice 产品标准检查失败：\n'+failures.map(text=>' - '+text).join('\n'));process.exitCode=1;}
else console.log(`PASS MiniVoice 自有组件边界（${files.length} 个源文件，Android 默认入口及原生回退检查）；视觉与运行验收仍按 Docs/PRODUCT_STANDARD.md 执行。`);
