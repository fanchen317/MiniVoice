// All model preprocessing and inference runs on a worker; the main thread only
// reads the same decoded and oriented image used by the wallpaper.
import {createLatestFirstQueue} from './artworkAnalysisQueue.js';
import {createArtworkWorkerClient} from './artworkWorkerClient.js';
import {artworkAnalysisCache} from './artworkAnalysisCache.js';
import {clearArtworkSubjects} from './components/artworkFocus.js';

const enqueue=createLatestFirstQueue();
const worker=createArtworkWorkerClient(()=>new Worker(new URL('./artworkSubjectWorker.js',import.meta.url),{type:'module'}));
function readPixels(source){
 return new Promise((resolve,reject)=>{
  const image=new Image();image.crossOrigin='anonymous';image.onload=()=>{
   try{const scale=Math.min(1,1024/Math.max(image.naturalWidth,image.naturalHeight)),width=Math.max(1,Math.round(image.naturalWidth*scale)),height=Math.max(1,Math.round(image.naturalHeight*scale));
    const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;const context=canvas.getContext('2d',{willReadFrequently:true});
    if(!context)throw Error('Artwork canvas unavailable');context.drawImage(image,0,0,width,height);resolve({pixels:context.getImageData(0,0,width,height).data,width,height});
   }catch(error){reject(error);}
  };image.onerror=()=>reject(Error('Artwork image unavailable'));image.src=source;
 });
}
const pending=new Map();
export function analyzeArtworkSubjects(source,{identity,priority='foreground'}={}){
 if(!source)return Promise.resolve([]);
 const key=identity||source,existing=pending.get(key);
 if(existing){if(priority!=='background')existing.promote();return existing.promise;}
 const generation=artworkAnalysisCache.generation();let queued;
 const entry={promise:null,promote(){priority='foreground';queued?.promote();}};
 const task=(async()=>{
  if(identity){const cached=await artworkAnalysisCache.get(identity);if(cached!==null)return cached;}
  queued=enqueue(async()=>{
   // Background indexing and a focused request can meet while queued.
   if(identity){const cached=await artworkAnalysisCache.get(identity);if(cached!==null)return cached;}
   const regions=await worker.analyze(await readPixels(source));
   if(identity)await artworkAnalysisCache.put(identity,regions,{generation});
   return regions;
  },{priority});
  return queued;
 })().finally(()=>{if(pending.get(key)===entry)pending.delete(key);});
 entry.promise=task;pending.set(key,entry);return task;
}
export async function precomputeArtworkSubjects({source,identity}){
 if(!identity||!await artworkAnalysisCache.available())return false;
 await analyzeArtworkSubjects(source,{identity,priority:'background'});
 if((await artworkAnalysisCache.get(identity))!==null)return true;
 return await artworkAnalysisCache.available()?'skip':false;
}
export async function clearArtworkAnalysis(){
 // Prevent queued work started before the clear from repopulating either cache.
 pending.clear();clearArtworkSubjects();return artworkAnalysisCache.clear();
}
