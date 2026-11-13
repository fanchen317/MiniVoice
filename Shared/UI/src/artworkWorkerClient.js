// One worker is shared by all requests. On crash or timeout, reject every
// outstanding request and create a fresh worker for the next attempt.
export function createArtworkWorkerClient(createWorker,{timeoutMs=45000}={}){
 let worker=null,nextId=0;const requests=new Map();
 function fail(error){
  const failed=worker;worker=null;
  if(failed)failed.terminate();
  for(const request of requests.values()){clearTimeout(request.timer);request.reject(error);}
  requests.clear();
 }
 function getWorker(){
  if(worker)return worker;
  const instance=createWorker();worker=instance;
  instance.onmessage=event=>{
   if(worker!==instance)return;
   const message=event.data||{},request=requests.get(message.id);if(!request)return;
   if(message.error){fail(new Error(message.error));return;}
   if(!Array.isArray(message.regions)){fail(new Error('Invalid artwork worker response'));return;}
   requests.delete(message.id);clearTimeout(request.timer);
   if(message.cacheable===false)Object.defineProperty(message.regions,'cacheable',{value:false});
   request.resolve(message.regions);
  };
  instance.onerror=()=>{if(worker===instance)fail(new Error('Artwork worker failed'));};
  instance.onmessageerror=()=>{if(worker===instance)fail(new Error('Invalid artwork worker message'));};
  return instance;
 }
 return {
  analyze({pixels,width,height}){
   return new Promise((resolve,reject)=>{
    let instance;try{instance=getWorker();}catch(error){reject(error);return;}
    const id=++nextId;
    const timer=setTimeout(()=>{if(requests.has(id))fail(new Error('Artwork worker timed out'));},timeoutMs);
    requests.set(id,{resolve,reject,timer});
    try{instance.postMessage({id,pixels:pixels.buffer,width,height},[pixels.buffer]);}
    catch(error){fail(error);}
   });
  },
  dispose(){fail(new Error('Artwork worker stopped'));}
 };
}
