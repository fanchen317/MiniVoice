import {open,stat,cp,mkdir,copyFile,realpath} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
export async function validateResources(source){
 for(const name of ['minivoice-core.exe','ffmpeg.exe','ffprobe.exe','LyricsAI/python.exe']){const file=await open(path.join(source,name),'r');try{const header=Buffer.alloc(64);await file.read(header,0,64,0);if(header.toString('ascii',0,2)!=='MZ')throw Error(`${name} 不是 Windows 可执行文件`);const pe=Buffer.alloc(6);await file.read(pe,0,6,header.readUInt32LE(60));if(pe.toString('binary',0,4)!=='PE\0\0'||pe.readUInt16LE(4)!==0x8664)throw Error(`${name} 不是 Windows x64 PE 文件`);}finally{await file.close();}}
 for(const name of ['LICENSE.txt','LyricsAI/models/small.pt'])if(!(await stat(path.join(source,name))).isFile())throw Error(`缺少资源：${name}`);
 if(!(await stat(path.join(source,'LyricsAI/LICENSES'))).isDirectory())throw Error('缺少 AI 许可目录');
}
if(process.argv[1]&&pathToFileURL(path.resolve(process.argv[1])).href===import.meta.url){const source=await realpath(process.argv[2]),root=path.dirname(fileURLToPath(import.meta.url)),target=path.join(root,'resources');if(source===target)throw Error('资源源目录不能是打包暂存目录');await validateResources(source);await mkdir(target,{recursive:true});await cp(source,target,{recursive:true,dereference:true});await copyFile(path.join(root,'../MacOS/Sources/MiniVoice/Resources/align_lyrics.py'),path.join(target,'align_lyrics.py'));}
