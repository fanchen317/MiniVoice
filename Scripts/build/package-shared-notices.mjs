import {readFile,mkdir,writeFile,copyFile,readdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const output=path.resolve(process.argv[2]||path.join(root,'.build/work/shared-ui'));
// Shared/UI owns the licensed React copy; the desktop package keeps its own.
const licenses=['Shared/Core/Sources/MiniVoiceCore/vendor/json.LICENSE','Shared/Core/Sources/MiniVoiceCore/vendor/utf8proc.LICENSE'];
for(const folder of ['Shared/UI/node_modules','MacOS/Desktop/node_modules'])for(const name of ['react','react-dom'])licenses.push(`${folder}/${name}/LICENSE`);
const notices=[];
for(const source of licenses){try{notices.push(`${source}\n\n${await readFile(path.join(root,source),'utf8')}`)}catch{}}
if(!notices.length)throw Error('未找到任何第三方许可文件，无法打包声明');
await mkdir(path.join(output,'assets'),{recursive:true});await writeFile(path.join(output,'assets/THIRD_PARTY_NOTICES.txt'),notices.join('\n\n----------------\n\n'));

await copyFile(path.join(root,'Android/app/src/main/res/drawable/minivoice_icon.png'),path.join(output,'assets/minivoice_icon.png'));

const icons=path.join(root,'Android/app/src/main/res/drawable');await mkdir(path.join(output,'assets/icons'),{recursive:true});for(const name of await readdir(icons))if(name.startsWith('icon_')&&name.endsWith('.png'))await copyFile(path.join(icons,name),path.join(output,'assets/icons',name));
