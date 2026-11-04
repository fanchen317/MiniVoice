/** One in-flight read; no background polling or catch-up burst on resume. */
export function startSnapshotPolling({read,onValue,onError,onRecovered,interval=450,document:page=globalThis.document,lifecycle=globalThis,setTimer=setTimeout,clearTimer=clearTimeout}){
 let disposed=false,busy=false,timer=null,failures=0;
 const schedule=delay=>{clearTimer(timer);if(!disposed&&!page?.hidden)timer=setTimer(update,delay);};
 async function update(){if(disposed||busy||page?.hidden)return;busy=true;try{const value=await read();if(!disposed){onValue(value);if(failures)onRecovered?.();failures=0;}}catch(error){if(!disposed&&!page?.hidden){failures++;if(failures===3)onError(error);}}finally{busy=false;schedule(failures?Math.min(8000,1000*2**(failures-1)):interval);}}
 const resume=()=>{clearTimer(timer);if(!page?.hidden)update();};
 page?.addEventListener('visibilitychange',resume);lifecycle?.addEventListener?.('pageshow',resume);
 update();return()=>{disposed=true;clearTimer(timer);page?.removeEventListener('visibilitychange',resume);lifecycle?.removeEventListener?.('pageshow',resume);};
}
