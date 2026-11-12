// One inference lane limits memory. Focused requests outrank speculative work;
// within each class the newest request runs first. Already-running work is kept.
export function createLatestFirstQueue(){
 const pending=[];let active=false;
 async function drain(){
  if(active)return;active=true;
  try{while(pending.length){let at=pending.findLastIndex(job=>job.priority!=='background');if(at<0)at=pending.length-1;const [job]=pending.splice(at,1);try{job.resolve(await job.run());}catch(error){job.reject(error);}}}
  finally{active=false;}
 }
 return (run,{priority='foreground'}={})=>{
  let job;const promise=new Promise((resolve,reject)=>{job={run,resolve,reject,priority};pending.push(job);void drain();});
  promise.promote=()=>{job.priority='foreground';};return promise;
 };
}
