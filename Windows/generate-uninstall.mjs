import {readdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
export async function uninstallManifest(root){
 const files=[],directories=[];
 async function walk(relative=''){for(const item of await readdir(path.join(root,relative),{withFileTypes:true})){const name=path.join(relative,item.name);if(item.isSymbolicLink())throw Error('安装目录不允许符号链接');if(item.isDirectory()){directories.push(name);await walk(name);}else if(item.isFile())files.push(name);}}
 await walk();const escape=value=>value.replaceAll('\\','/').replaceAll('$','$$').replaceAll('"','$\\"').replaceAll('/','\\');
 return [...files.map(file=>`Delete "$INSTDIR\\${escape(file)}"`),...directories.reverse().map(dir=>`RMDir "$INSTDIR\\${escape(dir)}"`)].join('\n')+'\n';
}
if(process.argv[1]&&pathToFileURL(path.resolve(process.argv[1])).href===import.meta.url)await writeFile(process.argv[3],await uninstallManifest(process.argv[2]));
