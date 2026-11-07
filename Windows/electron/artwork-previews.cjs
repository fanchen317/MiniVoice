const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const png=Buffer.from([137,80,78,71,13,10,26,10]);
function artworkPreviews({directory,nativeImage,memoryLimit=32*1024*1024}){
 const derived=path.join(directory,'Previews-v1'),memory=new Map(),pending=new Map();let bytes=0,queue=Promise.resolve();
 const stats={generated:0,memoryHits:0,diskHits:0,originalReads:0};
 function remember(key,data){if(data.length>memoryLimit)return;memory.set(key,data);bytes+=data.length;while(bytes>memoryLimit){const first=memory.keys().next().value;bytes-=memory.get(first).length;memory.delete(first);}}
 async function get(key,{original=false,list=false,mime='image/png'}={}){
  if(!/^[a-f0-9]{64}$/.test(key))throw Error('无效封面');
  if(original){stats.originalReads++;return {data:await fs.readFile(path.join(directory,key)),mime};}
  const side=list?192:512,token=key+'-'+side;
  if(memory.has(token)){stats.memoryHits++;const data=memory.get(token);memory.delete(token);memory.set(token,data);return {data,mime:'image/png'};}
  if(pending.has(token))return pending.get(token);
  const job=(async()=>{
   const file=path.join(derived,token+'.png');
   try{const data=await fs.readFile(file);if(data.subarray(0,8).equals(png)){stats.diskHits++;remember(token,data);return {data,mime:'image/png'};}}catch{}
   // Yield between decodes rather than flooding the main process with original images.
   const work=queue.catch(()=>{}).then(async()=>{
    await new Promise(resolve=>setImmediate(resolve));
    const image=nativeImage.createFromBuffer(await fs.readFile(path.join(directory,key)));
    if(image.isEmpty())throw Error('无法读取封面');const size=image.getSize(),ratio=Math.min(1,side/Math.max(size.width,size.height));
    const output=ratio<1?image.resize({width:Math.max(1,Math.round(size.width*ratio)),height:Math.max(1,Math.round(size.height*ratio)),quality:'good'}):image;
    const data=output.toPNG();stats.generated++;
    let temporary;
    try{await fs.mkdir(derived,{recursive:true});temporary=file+'.'+crypto.randomUUID()+'.tmp';await fs.writeFile(temporary,data);await fs.rename(temporary,file);}catch{}finally{if(temporary)await fs.rm(temporary,{force:true}).catch(()=>{});}
    remember(token,data);return {data,mime:'image/png'};
   });queue=work.catch(()=>{});return work;
  })();pending.set(token,job);try{return await job;}finally{pending.delete(token);}
 }
 return {get,stats};
}
module.exports={artworkPreviews};
