import {createHash} from 'node:crypto';
import {createReadStream} from 'node:fs';
import {open,stat,cp,mkdir,copyFile,realpath,readFile,mkdtemp,rename,rm} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
export async function validateResources(source){
 let manifest;
 try{manifest=JSON.parse(await readFile(path.join(source,'resource-manifest.json'),'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
 if(manifest){
  if(manifest.platform!=='win32-x64'||!manifest.files||!Object.keys(manifest.files).length)throw Error('Windows 资源清单无效');
  for(const [name,expected] of Object.entries(manifest.files)){
   const file=path.resolve(source,name),relative=path.relative(path.resolve(source),file);
   if(!relative||relative.startsWith('..')||path.isAbsolute(relative))throw Error('资源清单路径越界');
   const hash=createHash('sha256');for await(const chunk of createReadStream(file))hash.update(chunk);
   if(hash.digest('hex')!==expected)throw Error(`Windows 资源校验失败：${name}`);
  }
 }

 for(const name of ['minivoice-core.exe','ffmpeg.exe','ffprobe.exe','LyricsAI/python.exe']){const file=await open(path.join(source,name),'r');try{const header=Buffer.alloc(64);await file.read(header,0,64,0);if(header.toString('ascii',0,2)!=='MZ')throw Error(`${name} 不是 Windows 可执行文件`);const pe=Buffer.alloc(6);await file.read(pe,0,6,header.readUInt32LE(60));if(pe.toString('binary',0,4)!=='PE\0\0'||pe.readUInt16LE(4)!==0x8664)throw Error(`${name} 不是 Windows x64 PE 文件`);}finally{await file.close();}}
 for(const name of ['LICENSE.txt','LyricsAI/models/small.pt'])if(!(await stat(path.join(source,name))).isFile())throw Error(`缺少资源：${name}`);
 if(!(await stat(path.join(source,'LyricsAI/LICENSES'))).isDirectory())throw Error('缺少 AI 许可目录');
}
export async function stageResources(source,target,worker){
 await mkdir(path.dirname(target),{recursive:true});
 const staging=await mkdtemp(path.join(path.dirname(target),'.windows-resources-')),fresh=path.join(staging,'fresh'),previous=path.join(staging,'previous');let moved=false;
 try{
  await cp(source,fresh,{recursive:true,dereference:true});
  await copyFile(worker,path.join(fresh,'align_lyrics.py'));
  try{await rename(target,previous);moved=true;}catch(error){if(error.code!=='ENOENT')throw error;}
  try{await rename(fresh,target);}catch(error){if(moved)await rename(previous,target);throw error;}
 }finally{await rm(staging,{recursive:true,force:true});}
}
if(process.argv[1]&&pathToFileURL(path.resolve(process.argv[1])).href===import.meta.url){
 const source=await realpath(process.argv[2]),root=path.dirname(fileURLToPath(import.meta.url)),target=path.join(root,'resources');
 if(source===target)throw Error('资源源目录不能是打包暂存目录');
 await validateResources(source);
 await stageResources(source,target,path.join(root,'../MacOS/Sources/MiniVoice/Resources/align_lyrics.py'));
}
