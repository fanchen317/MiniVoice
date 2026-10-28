/** Pinned, offline-capable dependency setup for either UI package. */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const packages={'shared-ui':{folder:'Shared/UI',commands:['vite']},desktop:{folder:'MacOS/Desktop',commands:['vite','electron-packager']}};
const name=process.argv[2]||'shared-ui',config=packages[name];
if(!config)throw new Error(`未知依赖组：${name}`);
const vendor=path.join(root,'Shared/Tooling/NodeDependencies');
const manifest=JSON.parse(fs.readFileSync(path.join(vendor,'manifest.json')));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const folder=path.join(root,config.folder),lockHash=hash(path.join(folder,'package-lock.json'));
if(lockHash!==manifest.packageLocks[config.folder])throw new Error(`${config.folder} 锁文件已变化，请更新共享离线依赖清单。`);
const packageJSON=JSON.parse(fs.readFileSync(path.join(folder,'package.json')));
const locked=JSON.parse(fs.readFileSync(path.join(folder,'package-lock.json'))).packages[''];
for(const section of ['dependencies','devDependencies']){
 const declared=packageJSON[section]||{},pinned=locked[section]||{};
 if(Object.keys(declared).length!==Object.keys(pinned).length||Object.entries(declared).some(([key,value])=>pinned[key]!==value))throw new Error(`${config.folder} 的依赖声明与锁文件不一致`);
}
const stamp=path.join(folder,'node_modules/.minivoice-lock-sha256');
if(config.commands.every(command=>fs.existsSync(path.join(folder,'node_modules/.bin',command)))&&fs.existsSync(stamp)&&fs.readFileSync(stamp,'utf8').trim()===lockHash){
 console.log(`==> ${name} 依赖与锁文件一致，复用本地安装`);
}else{
 const archive=path.join(vendor,'npm-cache.tar.gz');
 if(!fs.existsSync(archive)||hash(archive)!==manifest.archiveSHA256)throw new Error('共享离线依赖资源缺失或校验失败，请运行 git lfs pull。');
 const cache=process.env.MINIVOICE_NPM_CACHE?path.resolve(process.env.MINIVOICE_NPM_CACHE):path.join(root,'.build/cache/npm');
 fs.mkdirSync(cache,{recursive:true});
 let result=spawnSync('tar',['-xzf',archive,'-C',cache],{stdio:'inherit'});
 if(result.status!==0)throw new Error('无法解压共享离线依赖');
 result=spawnSync('npm',['--prefix',folder,'--cache',cache,'ci','--offline','--include=dev','--bin-links=true','--no-audit','--no-fund'],{stdio:'inherit',env:{...process.env,ELECTRON_SKIP_BINARY_DOWNLOAD:'1'}});
 if(result.status!==0)throw new Error(`${name} 离线依赖安装失败`);
 fs.writeFileSync(stamp,lockHash+'\n');
}
