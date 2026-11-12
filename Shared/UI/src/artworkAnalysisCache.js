// Local-only subject boxes. Keys are a SHA-256 digest of the caller's stable,
// versioned artwork identity and detector version; raw artwork URLs are not stored.
const MODEL_VERSION='minivoice-subjects-yunet-yolox-ppocr-v2';
const MAX_REGIONS=48,MAX_RECORD_BYTES=4096,DAY=86400000;
let defaultIndexedDB;try{defaultIndexedDB=globalThis.indexedDB;}catch{defaultIndexedDB=undefined;}
const K=new Uint32Array([0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]);
const ror=(x,n)=>(x>>>n)|(x<<(32-n));
function digest(text){
 const input=new TextEncoder().encode(text),size=Math.ceil((input.length+9)/64)*64,bytes=new Uint8Array(size);bytes.set(input);bytes[input.length]=128;
 const view=new DataView(bytes.buffer);view.setUint32(size-8,Math.floor(input.length/0x20000000));view.setUint32(size-4,input.length*8);
 const h=new Uint32Array([0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]),w=new Uint32Array(64);
 for(let offset=0;offset<size;offset+=64){for(let i=0;i<16;i++)w[i]=view.getUint32(offset+i*4);for(let i=16;i<64;i++){const a=w[i-15],b=w[i-2];w[i]=(w[i-16]+(ror(a,7)^ror(a,18)^(a>>>3))+w[i-7]+(ror(b,17)^ror(b,19)^(b>>>10)))>>>0;}
  let [a,b,c,d,e,f,g,z]=h;for(let i=0;i<64;i++){const t1=(z+(ror(e,6)^ror(e,11)^ror(e,25))+((e&f)^(~e&g))+K[i]+w[i])>>>0,t2=((ror(a,2)^ror(a,13)^ror(a,22))+((a&b)^(a&c)^(b&c)))>>>0;z=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b;b=a;a=(t1+t2)>>>0;}const v=[a,b,c,d,e,f,g,z];for(let i=0;i<8;i++)h[i]=(h[i]+v[i])>>>0;
 }
 return Array.from(h,n=>n.toString(16).padStart(8,'0')).join('');
}
export function artworkAnalysisCacheKey(identity,version=MODEL_VERSION){
 if(typeof identity!=='string'||!identity||identity.length>4096||typeof version!=='string'||!version)return null;
 return digest(JSON.stringify([version,identity]));
}
function cleanRegions(regions){
 if(!Array.isArray(regions)||regions.length>MAX_REGIONS)return null;
 const result=[];for(const box of regions){if(!box||![box.x,box.y,box.width,box.height,box.confidence].every(Number.isFinite)||box.x<0||box.y<0||box.width<=0||box.height<=0||box.x+box.width>1.000001||box.y+box.height>1.000001||box.confidence<0||box.confidence>1)return null;
  const clean={x:box.x,y:box.y,width:box.width,height:box.height,confidence:box.confidence};for(const kind of ['face','person','text','saliency','attention'])if(box[kind]===1||box[kind]===true)clean[kind]=1;result.push(clean);
 }
 // Numeric, ASCII-only JSON provides a conservative bound for payload size;
 // IndexedDB's own record/index overhead is platform-dependent.
 return JSON.stringify(result).length<=MAX_RECORD_BYTES?result:null;
}
// No throw on unavailable storage, quota exhaustion, private mode, or schema
// races: cache misses simply fall back to the regular detector.
export function createArtworkAnalysisCache({indexedDB=defaultIndexedDB,dbName='minivoice-artwork-analysis',maxEntries=20000,maxAgeMs=90*DAY,now=Date.now,openTimeoutMs=1000}={}){
 let opening=null,generation=0,lastUsed=0,retryAfter=0;maxEntries=Math.max(1,Math.min(50000,Math.floor(maxEntries)||20000));
 function open(){
  if(!indexedDB)return Promise.resolve(null);if(opening)return opening;if(retryAfter&&now()<retryAfter)return Promise.resolve(null);
  let resolveOpen;const promise=new Promise(resolve=>{resolveOpen=resolve;});opening=promise;
  let settled=false,request,timer;
  const finish=db=>{if(settled){db?.close();return;}settled=true;clearTimeout(timer);if(!db&&opening===promise){opening=null;retryAfter=now()+30000;}else if(db)retryAfter=0;resolveOpen(db);};
  try{request=indexedDB.open(dbName,1);request.onupgradeneeded=()=>{const db=request.result,store=db.objectStoreNames.contains('entries')?request.transaction.objectStore('entries'):db.createObjectStore('entries',{keyPath:'key'});if(!store.indexNames.contains('used'))store.createIndex('used','used');};
   request.onsuccess=()=>{const db=request.result;db.onversionchange=()=>{db.close();if(opening===promise)opening=null;};finish(db);};request.onerror=()=>finish(null);request.onblocked=()=>finish(null);timer=setTimeout(()=>finish(null),openTimeoutMs);
  }catch{finish(null);}return promise;
 }
 const stamp=()=>{lastUsed=Math.max(Number(now())||0,lastUsed+1);return lastUsed;};
 async function transact(mode,operation,fallback){const db=await open();if(!db)return fallback;return new Promise(resolve=>{let value=fallback,tx;try{tx=db.transaction('entries',mode);tx.oncomplete=()=>resolve(value);tx.onerror=tx.onabort=()=>resolve(fallback);operation(tx.objectStore('entries'),v=>{value=v;},tx);}catch{resolve(fallback);}});}
 return {
  generation(){return generation;},
  async available(){return transact('readonly',(store,set)=>{const req=store.count();req.onsuccess=()=>set(true);},false);},
  async count(){return transact('readonly',(store,set)=>{const req=store.count();req.onsuccess=()=>set(req.result);},null);},
  async get(identity){const key=artworkAnalysisCacheKey(identity),epoch=generation;if(!key)return null;
   return transact('readwrite',(store,set)=>{const req=store.get(key);req.onsuccess=()=>{const record=req.result;if(!record)return;const data=cleanRegions(record.regions),age=Number(now())-record.created;if(!data||!Number.isFinite(record.created)||age<0||age>maxAgeMs||epoch!==generation){if(epoch===generation)store.delete(key);return;}record.used=stamp();store.put(record);set(data);};},null).then(value=>epoch===generation?value:null);
  },
  async put(identity,regions,{generation:epoch=generation}={}){const key=artworkAnalysisCacheKey(identity),data=cleanRegions(regions);if(!key||!data||epoch!==generation)return false;
   return transact('readwrite',(store,set)=>{if(epoch!==generation)return;const created=Number(now());if(!Number.isFinite(created))return;store.put({key,created,used:stamp(),regions:data});const count=store.count();count.onsuccess=()=>{let excess=count.result-maxEntries;if(excess<=0){set(true);return;}const cursor=store.index('used').openCursor();cursor.onsuccess=()=>{const item=cursor.result;if(!item||excess<=0){set(true);return;}item.delete();excess--;item.continue();};};},false).then(value=>epoch===generation&&value);
  },
  async clear(){generation++;return transact('readwrite',(store,set)=>{store.clear();set(true);},false);}
 };
}
export const artworkAnalysisCache=createArtworkAnalysisCache();
