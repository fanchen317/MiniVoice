import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const vendor=path.join(root,'MacOS/Vendor/NodeDependencies');
const manifest=JSON.parse(fs.readFileSync(path.join(vendor,'manifest.json')));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const lock=path.join(root,'MacOS/Desktop/package-lock.json');
const cache=process.env.MINIVOICE_NPM_CACHE?path.resolve(process.env.MINIVOICE_NPM_CACHE):path.join(root,'.build/npm-cache');
const stamp=path.join(root,'MacOS/Desktop/node_modules/.minivoice-lock-sha256');
const lockHash=hash(lock);
if(lockHash!==manifest.packageLockSHA256) throw new Error('package-lock.json 已变化，请更新 MacOS/Vendor/NodeDependencies 离线缓存。');
const commands=['vite','electron-packager'];
if(commands.every(name=>fs.existsSync(path.join(root,'MacOS/Desktop/node_modules/.bin',name)))
  && fs.existsSync(stamp)&&fs.readFileSync(stamp,'utf8').trim()===lockHash){
  console.log('==> 前端依赖与锁文件一致，复用本地安装');
}else{
  const archive=path.join(vendor,'npm-cache.tar.gz');
  if(!fs.existsSync(archive)||hash(archive)!==manifest.archiveSHA256) throw new Error('本地 npm 依赖资源缺失或校验失败，请运行 git lfs pull。');
  fs.mkdirSync(cache,{recursive:true});
  let result=spawnSync('tar',['-xzf',archive,'-C',cache],{stdio:'inherit'});
  if(result.status!==0) throw new Error('无法解压本地 npm 依赖缓存');
  console.log('==> 从仓库缓存离线安装前端依赖');
  result=spawnSync('npm',['--prefix',path.join(root,'MacOS/Desktop'),'--cache',cache,'ci','--offline','--include=dev','--bin-links=true','--no-audit','--no-fund'],
    {stdio:'inherit',env:{...process.env,ELECTRON_SKIP_BINARY_DOWNLOAD:'1'}});
  if(result.status!==0) throw new Error('离线依赖安装失败；请检查仓库缓存是否与当前平台及锁文件一致');
  fs.writeFileSync(stamp,lockHash+'\n');
}
