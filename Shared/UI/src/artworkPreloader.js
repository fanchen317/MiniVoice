// Speculative artwork belongs to a wall instance, never to the music library.
// Bound concurrent decoding and retain only a small decoded-image working set.
export function createArtworkPreloader({concurrency=3,maxBytes=24*1024*1024,maxEntries=48,load=loadImage}={}){
 const pending=new Map(),queue=[],cache=new Map(),running=new Set();let active=0,bytes=0,disposed=false;
 const settle=(entry,ok)=>{if(pending.get(entry.source)===entry)pending.delete(entry.source);for(const waiter of entry.waiters.splice(0))waiter.resolve(ok&&waiter.current());};
 function remember(source,image){
  const cost=(image?.naturalWidth||0)*(image?.naturalHeight||0)*4;
  if(!cost||cost>maxBytes||!maxEntries)return;
  while(cache.size&&(bytes+cost>maxBytes||cache.size>=maxEntries)){const [key,value]=cache.entries().next().value;cache.delete(key);bytes-=value.cost;}
  cache.set(source,{image,cost});bytes+=cost;
 }
 function pump(){
  // A rapid skip cancels work which has not started, including old neighbours.
  for(let i=queue.length-1;i>=0;i--){const entry=queue[i];if(!entry.waiters.some(waiter=>waiter.current())){queue.splice(i,1);pending.delete(entry.source);settle(entry,false);}}
  while(!disposed&&active<concurrency&&queue.length){
   const entry=queue.shift();entry.controller=new AbortController();running.add(entry);active++;
   Promise.resolve().then(()=>disposed?null:load(entry.source,entry.controller.signal)).then(image=>{
    const current=!disposed&&entry.waiters.some(waiter=>waiter.current());
    if(current)remember(entry.source,image);settle(entry,Boolean(image)&&current);
   },()=>settle(entry,false)).finally(()=>{active--;running.delete(entry);if(pending.get(entry.source)===entry)pending.delete(entry.source);pump();});
  }
 }
 return {
  prefetch(sources,current=()=>true,{priority=false}={}){
   if(disposed)return Promise.resolve([]);
   const work=[...new Set(sources.filter(Boolean))].map(source=>{
    if(!current())return Promise.resolve(false);
    const cached=cache.get(source);if(cached){cache.delete(source);cache.set(source,cached);return Promise.resolve(true);}
    return new Promise(resolve=>{let entry=pending.get(source);if(!entry){entry={source,waiters:[]};pending.set(source,entry);queue.push(entry);}entry.waiters.push({current,resolve});});
   });if(priority){const wanted=new Set(sources);queue.sort((a,b)=>Number(wanted.has(b.source))-Number(wanted.has(a.source)));}pump();return Promise.all(work);
  },
  dispose(){disposed=true;cache.clear();bytes=0;for(const entry of running){entry.controller.abort();settle(entry,false);}for(const entry of queue.splice(0)){pending.delete(entry.source);settle(entry,false);}},
  stats:()=>({active,queued:queue.length,entries:cache.size,bytes})
 };
}
function loadImage(source,signal){return new Promise(resolve=>{
 const image=new Image();let timer,settled=false;
 const abort=()=>finish(false);
 const finish=ok=>{if(settled)return;settled=true;clearTimeout(timer);signal?.removeEventListener('abort',abort);image.onload=image.onerror=null;if(!ok)image.removeAttribute('src');resolve(ok?image:null);};
 if(signal?.aborted){finish(false);return;}signal?.addEventListener('abort',abort,{once:true});
 image.decoding='async';image.onload=()=>image.decode().then(()=>finish(true),()=>finish(false));image.onerror=()=>finish(false);
 timer=setTimeout(()=>finish(false),8000);image.src=source;
});}
