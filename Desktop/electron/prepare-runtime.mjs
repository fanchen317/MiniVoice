import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Verify distribution bytes against checksums shipped in the npm Electron
// package, including when a regional mirror is needed for GitHub connectivity.
const desktop=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const root=path.dirname(desktop), module=path.join(desktop,'node_modules/electron');
const version=JSON.parse(fs.readFileSync(path.join(module,'package.json'))).version;
const filename=`electron-v${version}-darwin-arm64.zip`, zip=path.join(root,'.build',filename);
const checksums=JSON.parse(fs.readFileSync(path.join(module,'checksums.json')));
function valid(){return fs.existsSync(zip)&&crypto.createHash('sha256').update(fs.readFileSync(zip)).digest('hex')===checksums[filename];}
if(!valid()){
  fs.mkdirSync(path.dirname(zip),{recursive:true});
  let downloaded=false;
  for(const url of [`https://github.com/electron/electron/releases/download/v${version}/${filename}`,`https://npmmirror.com/mirrors/electron/${version}/${filename}`]){
    console.log(`==> 下载 Electron ${version} (${new URL(url).hostname})，首次下载可能需要数分钟…`);
    const result=spawnSync('curl',['--fail','--location','--show-error',
      '--connect-timeout','15','--max-time','600',
      '--speed-limit','1024','--speed-time','60',
      '--retry','2','--retry-delay','2',url,'--output',zip],{stdio:'inherit'});
    if(result.status===0&&valid()){downloaded=true;break;}
    console.warn(`Electron 下载${result.status===0?'校验失败':'未完成'}，尝试备用下载源…`);
  }
  if(!downloaded)throw new Error('Electron distribution download or SHA-256 verification failed');
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
