import {readFile,mkdir,writeFile,copyFile,readdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const output=path.resolve(process.argv[2]||path.join(root,'.build/work/shared-ui'));
const ui=path.resolve(process.argv[3]||path.join(root,'Shared/UI'));
const sources=['Shared/Core/Sources/MiniVoiceCore/vendor/json.LICENSE','Shared/Core/Sources/MiniVoiceCore/vendor/utf8proc.LICENSE',path.join(ui,'node_modules/react/LICENSE'),path.join(ui,'node_modules/react-dom/LICENSE'),'Shared/UI/src/assets/artwork-models/ONNX-RUNTIME-LICENSE.txt','Shared/UI/src/assets/artwork-models/LICENSE-APACHE-2.0.txt','Shared/UI/src/assets/artwork-models/README.md','Shared/UI/src/assets/artwork-models/face-README.md','Shared/UI/src/assets/artwork-models/retina-README.md','Shared/UI/src/assets/artwork-models/person-README.md'];
const notices=await Promise.all(sources.map(async source=>`${path.relative(root,path.resolve(root,source))}\n\n${await readFile(path.resolve(root,source),'utf8')}`));
await mkdir(path.join(output,'assets'),{recursive:true});await writeFile(path.join(output,'assets/THIRD_PARTY_NOTICES.txt'),notices.join('\n\n----------------\n\n'));

await copyFile(path.join(root,'Android/app/src/main/res/drawable/minivoice_icon.png'),path.join(output,'assets/minivoice_icon.png'));

const icons=path.join(root,'Android/app/src/main/res/drawable');await mkdir(path.join(output,'assets/icons'),{recursive:true});for(const name of await readdir(icons))if(name.startsWith('icon_')&&name.endsWith('.png'))await copyFile(path.join(icons,name),path.join(output,'assets/icons',name));

// Desktop hosts ship the same service implementation inside their app archive.
try { await readdir(path.join(ui,'electron')); const destination=path.join(ui,'electron/shared-services'); await mkdir(destination,{recursive:true}); for(const name of await readdir(path.join(root,'Shared/DesktopServices')))if(name.endsWith('.cjs'))await copyFile(path.join(root,'Shared/DesktopServices',name),path.join(destination,name)); } catch(error){if(error.code!=='ENOENT')throw error;}
