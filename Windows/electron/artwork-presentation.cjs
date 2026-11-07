const fs=require('node:fs/promises'),path=require('node:path');
// Match ArtworkPresentation.averageColor + DesktopEngine.detail on Mac.
// Electron bitmap samples are premultiplied BGRA on supported little-endian hosts.
function backdropColors(bitmap){
 let red=0,green=0,blue=0,alpha=0;
 for(let i=0;i+3<bitmap.length;i+=4){blue+=bitmap[i];green+=bitmap[i+1];red+=bitmap[i+2];alpha+=bitmap[i+3];}
 if(!alpha)return undefined;
 const rgb=[red,green,blue].map(value=>Math.min(1,value/alpha));
 return [rgb.map(value=>Math.min(1,value*.38+.62)),rgb.map(value=>Math.min(1,value*.20+.80))];
}
function artworkPresentation({directory,nativeImage,readFile=fs.readFile,limit=8}){
 const cache=new Map();
 async function colors(key){
  if(!/^[a-f0-9]{64}$/.test(key||''))return undefined;
  if(cache.has(key)){const value=cache.get(key);cache.delete(key);cache.set(key,value);return value;}
  const pending=(async()=>{try{
   const image=(nativeImage||require('electron').nativeImage).createFromBuffer(await readFile(path.join(directory,key)));
   if(image.isEmpty())return undefined;
   return backdropColors(image.resize({width:18,height:18,quality:'good'}).toBitmap());
  }catch{return undefined;}})();
  cache.set(key,pending);while(cache.size>limit)cache.delete(cache.keys().next().value);
  const value=await pending;if(!value&&cache.get(key)===pending)cache.delete(key);return value;
 }
 return {colors};
}
module.exports={backdropColors,artworkPresentation};
