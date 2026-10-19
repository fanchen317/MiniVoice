import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Build only from the pinned distribution stored in Git LFS.
const desktop=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const root=path.dirname(desktop), module=path.join(desktop,'node_modules/electron');
const version=JSON.parse(fs.readFileSync(path.join(module,'package.json'))).version;
const filename=`electron-v${version}-darwin-arm64.zip`, zip=path.join(root,'.build',filename);
const checksums=JSON.parse(fs.readFileSync(path.join(module,'checksums.json')));
function valid(){return fs.existsSync(zip)&&crypto.createHash('sha256').update(fs.readFileSync(zip)).digest('hex')===checksums[filename];}
if(!valid()){
  fs.mkdirSync(path.dirname(zip),{recursive:true});
  const vendored=path.join(root,'Vendor/Electron/arm64',filename);
  if(!fs.existsSync(vendored)||crypto.createHash('sha256').update(fs.readFileSync(vendored)).digest('hex')!==checksums[filename]){
    throw new Error(`本地 Electron 资源缺失或校验失败：${vendored}。请先运行 git lfs pull；部署不会联网下载。`);
  }
  console.log(`==> 从仓库本地资源准备 Electron ${version}，无需联网`);
  fs.copyFileSync(vendored,zip);
}
else console.log(`==> 使用已校验的 Electron ${version} 本地安装包，无需下载`);
const dist=path.join(module,'dist');
if(!fs.existsSync(path.join(dist,'Electron.app/Contents/MacOS/Electron'))){
  fs.mkdirSync(dist,{recursive:true});
  const result=spawnSync('ditto',['-x','-k',zip,dist],{stdio:'inherit'});
  if(result.status!==0)throw new Error('Cannot extract Electron distribution');
}
fs.writeFileSync(path.join(module,'path.txt'),'Electron.app/Contents/MacOS/Electron');
console.log(`Verified Electron ${version} (${checksums[filename].slice(0,12)}…)`);
