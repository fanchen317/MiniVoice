// Real Chromium IndexedDB integration, isolated profile and synthetic subjects.
const {app,BrowserWindow}=require('electron');const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{pathToFileURL}=require('node:url');
app.setPath('userData',fs.mkdtempSync(path.join(os.tmpdir(),'minivoice-idb-')));
const timeout=setTimeout(()=>{console.error('IndexedDB test timed out');app.exit(1);},30000);
app.whenReady().then(async()=>{let win;try{
 win=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true}});
 const page=path.join(app.getPath('userData'),'test.html');fs.writeFileSync(page,'<!doctype html><title>Artwork cache</title>');await win.loadFile(page);
 const url=pathToFileURL(path.resolve('Shared/UI/src/artworkAnalysisCache.js')).href;
 const result=await win.webContents.executeJavaScript(`(async()=>{
  const {createArtworkAnalysisCache,artworkAnalysisCacheKey}=await import(${JSON.stringify(url)});
  const assert=(condition,message)=>{if(!condition)throw Error(message)};
  assert(await createArtworkAnalysisCache({indexedDB:null}).count()===null,'unavailable count must be null');
  const name='cache-'+Date.now(),v=[{x:.1,y:.2,width:.3,height:.4,face:1,confidence:.8}];let clock=1000;
  const cache=createArtworkAnalysisCache({dbName:name,maxEntries:2,maxAgeMs:1000,now:()=>clock});
  assert(await cache.available(),'storage unavailable');assert(await cache.count()===0,'empty count incorrect');assert(await cache.put('private/cover-one',v),'put failed');assert(await cache.count()===1,'count did not include stored record');
  assert((await cache.get('private/cover-one'))?.[0].face===1,'first read failed');
  const second=createArtworkAnalysisCache({dbName:name,maxEntries:2,maxAgeMs:1000,now:()=>clock});
  assert((await second.get('private/cover-one'))?.[0].face===1,'reload did not persist');
  assert(await cache.put('cover-two',[]),'empty detection must be cacheable');await cache.get('private/cover-one');assert(await cache.put('cover-three',v),'third put failed');
  assert(await cache.get('cover-two')===null,'oldest item was not evicted');assert((await cache.get('private/cover-one'))!==null,'recent item was evicted');
  clock=2001;assert(await cache.get('private/cover-one')===null,'stale item was not expired');
  const oldGeneration=cache.generation();assert(await cache.clear(),'clear failed');assert(await cache.count()===0,'clear did not reset count');assert(await cache.get('cover-three')===null,'clear retained data');assert(!(await cache.put('late-analysis',v,{generation:oldGeneration})),'analysis started before clear resurrected data');
  const actual=await new Promise((resolve,reject)=>{const request=indexedDB.open(name);request.onsuccess=()=>{const tx=request.result.transaction('entries','readonly'),q=tx.objectStore('entries').getAllKeys();q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);};request.onerror=()=>reject(request.error);});
  assert(actual.every(key=>/^[0-9a-f]{64}$/.test(key)&&!key.includes('private')),'raw identity persisted');
  let unlock;const delayed={open(...args){const real=indexedDB.open(...args),proxy={};real.onupgradeneeded=()=>{proxy.result=real.result;proxy.transaction=real.transaction;proxy.onupgradeneeded?.();};real.onsuccess=()=>{proxy.result=real.result;unlock=()=>proxy.onsuccess?.();};real.onerror=()=>proxy.onerror?.();return proxy;}};
  const raced=createArtworkAnalysisCache({indexedDB:delayed,dbName:name+'-race',openTimeoutMs:5000});const pending=raced.put('stale',v);
  for(let i=0;i<100&&!unlock;i++)await new Promise(resolve=>setTimeout(resolve,10));assert(unlock,'delayed open never completed');const cleared=raced.clear();unlock();
  assert(await pending===false,'old write was accepted after clear');assert(await cleared,'racing clear failed');assert(await raced.get('stale')===null,'old write resurrected after clear');
  assert(artworkAnalysisCacheKey('same','v1')!==artworkAnalysisCacheKey('same','v2'),'model version missing');
  return 'PASS persistent IndexedDB, LRU, expiration, hashed keys and clear race';
 })()`);
 console.log(result);clearTimeout(timeout);win.destroy();app.exit(0);
 }catch(error){console.error(error);clearTimeout(timeout);win?.destroy();app.exit(1);}});
