const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
async function readMetadata(file,{cacheDir,parseFile,selectCover}={}){
 if(!parseFile){const parser=await import('music-metadata');parseFile=parser.parseFile;selectCover=parser.selectCover;}
 const {common,format}=await parseFile(file,{duration:true});
 const result={title:common.title?.trim(),artist:(common.artists?.length?common.artists.join(' / '):common.artist)?.trim(),album:common.album?.trim(),duration:Number.isFinite(format.duration)?format.duration*1000:0};
 result.rawLyrics=(common.lyrics||[]).map(value=>typeof value==='string'?value:value.text||'').filter(Boolean).join('\n');
 const picture=selectCover?.(common.picture);
 if(picture&&cacheDir&&picture.data.length<=20*1024*1024&&['image/jpeg','image/png','image/webp'].includes(picture.format)){
  const data=Buffer.from(picture.data),key=crypto.createHash('sha256').update(data).digest('hex');await fs.mkdir(cacheDir,{recursive:true});
  try{await fs.writeFile(path.join(cacheDir,key),data,{flag:'wx'});}catch(error){if(error.code!=='EEXIST')throw error;}
  result.artworkKey=key;result.artworkMime=picture.format;
 }
 return Object.fromEntries(Object.entries(result).filter(([,v])=>v!==undefined&&v!==''));
}
module.exports={readMetadata};
