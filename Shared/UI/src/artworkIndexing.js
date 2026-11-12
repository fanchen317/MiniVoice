// Incremental, low-priority library indexing. At most one image is analyzed at
// a time, and a fresh gesture postpones the next item. It never reads files or
// touches the audio pipeline itself: hosts provide authorized artwork URLs.
export function createArtworkIndexer({run,isVisible=()=>true,now=Date.now,setTimer=setTimeout,clearTimer=clearTimeout,interval=2000,retryDelay=60000}={}){
 let sources=new Map(),pending=[],completed=new Set(),timer=null,running=false,disposed=false,paused=false,lastActivity=now(),retryAt=0,current=null,revision=0,failedWrites=0;
 function cancelTimer(){if(timer!==null)clearTimer(timer);timer=null;}
 function rebuild(){pending=[...sources.values()].filter(item=>!completed.has(item.identity)&&item.identity!==current);}
 function schedule(){
  if(disposed||paused||running||timer!==null||!pending.length||!isVisible())return;
  const wait=Math.max(0,interval-(now()-lastActivity),retryAt-now());
  timer=setTimer(tick,wait);
 }
 async function tick(){
  timer=null;if(disposed||paused||running||!isVisible())return;
  const item=pending.shift();if(!item)return;
  running=true;current=item.identity;const started=revision;
  try{
   const stored=await run(item);
   if(started!==revision)return;
   if(stored===false){if(sources.has(item.identity))pending.unshift(item);retryAt=now()+retryDelay;}
   else if(stored==='skip'){if(++failedWrites>=3){retryAt=now()+retryDelay;failedWrites=0;}}
   else{completed.add(item.identity);failedWrites=0;retryAt=0;}
  }catch{/* Invalid or unavailable artwork can be retried on a later scan. */}
  finally{
   running=false;current=null;lastActivity=now();
   if(started!==revision&&!paused)rebuild();
   schedule();
  }
 }
 return {
  update(items){
   if(disposed)return;
   const next=new Map();for(const item of items||[])if(item?.source&&item?.identity&&!next.has(item.identity))next.set(item.identity,item);
   const changed=next.size!==sources.size||[...next.keys()].some(key=>!sources.has(key));
   sources=next;completed=new Set([...completed].filter(key=>sources.has(key)));
   if(changed&&paused){paused=false;revision++;retryAt=0;}
   rebuild();schedule();
  },
  activity(){lastActivity=now();cancelTimer();schedule();},
  visibilityChanged(){if(!isVisible())cancelTimer();else schedule();},
  clear(){revision++;paused=true;retryAt=0;failedWrites=0;completed.clear();pending=[];cancelTimer();},
  refresh(){if(disposed)return;revision++;paused=false;retryAt=0;failedWrites=0;completed.clear();rebuild();schedule();},
  dispose(){disposed=true;revision++;pending=[];cancelTimer();}
 };
}
export function mobileArtworkCandidate(song,host){
 const source=song?.artworkDetail||song?.artworkCard||song?.artwork;
 const revision=song?.artworkRevision;
 if(!source||song?.id==null||song.id===''||!revision||revision==='legacy')return null;
 const variant=song.artworkDetail?'detail':song.artworkCard?'card':'preview';
 return {source,identity:JSON.stringify(['mobile',host||'',String(song.id),String(revision),variant])};
}
export function desktopArtworkCandidate(track,source){
 if(!source||!track?.artworkKey)return null;
 // The desktop host may temporarily serve a trimmed thumbnail for a detail
 // URL. Persistent coordinates must only be produced from the original.
 try{const url=new URL(source);if(url.protocol==='minivoice-art:'&&url.hostname==='detail'){url.searchParams.set('analysis','1');source=url.href;}}catch{}
 return {source,identity:JSON.stringify(['desktop',track.artworkKey])};
}
