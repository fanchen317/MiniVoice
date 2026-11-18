// Artwork preparation is optional: an unfinished decoder or background model
// must not prevent the selected song from becoming active on the wall.
export function waitForArtworkPreparation(tasks,{timeoutMs=800,setTimer=setTimeout,clearTimer=clearTimeout}={}){
 return new Promise(resolve=>{
  let finished=false,timer;
  const settle=value=>{if(finished)return;finished=true;clearTimer(timer);resolve(value);};
  timer=setTimer(()=>settle(false),Math.max(0,timeoutMs));
  Promise.allSettled(tasks).then(()=>settle(true));
 });
}
