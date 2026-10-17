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
    const result=spawnSync('curl',['--fail','--location','--silent','--show-error','--max-time',url.includes('github.com')?'20':'180',url,'--output',zip],{stdio:'inherit'});
    if(result.status===0&&valid()){downloaded=true;break;}
  }
  if(!downloaded)throw new Error('Electron distribution download or SHA-256 verification failed');
}
const dist=path.join(module,'dist');
if(!fs.existsSync(path.join(dist,'Electron.app/Contents/MacOS/Electron'))){
  fs.mkdirSync(dist,{recursive:true});
  const result=spawnSync('ditto',['-x','-k',zip,dist],{stdio:'inherit'});
  if(result.status!==0)throw new Error('Cannot extract Electron distribution');
}
fs.writeFileSync(path.join(module,'path.txt'),'Electron.app/Contents/MacOS/Electron');
console.log(`Verified Electron ${version} (${checksums[filename].slice(0,12)}…)`);
