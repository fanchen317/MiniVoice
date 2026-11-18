const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');

// Write beside the audio using the same path that the Windows library reads.
// Keep a backup before replacing an existing file and publish a complete file.
async function writeLyricsSidecar(songPath,lyrics,translation,{beforeCommit}={}){
 const target=songPath.slice(0,-path.extname(songPath).length)+'.lrc';
 const text=translation?'[translation:'+Buffer.from(translation,'utf8').toString('base64')+']\n'+(lyrics||''):lyrics||'';
 const temporary=target+'.minivoice-'+crypto.randomUUID()+'.tmp';
 const readStamp=async()=>{try{const stat=await fs.stat(target,{bigint:true});return [stat.dev,stat.ino,stat.size,stat.mtimeNs].join(':');}catch(error){if(error.code==='ENOENT')return null;throw error;}};
 try{
  const original=await readStamp();
  try{await fs.copyFile(target,target+'.minivoice-backup-'+Date.now(),fs.constants.COPYFILE_EXCL);}catch(error){if(error.code!=='ENOENT')throw error;}
  await fs.writeFile(temporary,text,{encoding:'utf8',flag:'wx'});
  if(beforeCommit)await beforeCommit();
  if(await readStamp()!==original)throw Error('歌词文件在保存期间发生变化，请重新加载后重试');
  await fs.rename(temporary,target);
 }finally{await fs.rm(temporary,{force:true});}
 return target;
}
module.exports={writeLyricsSidecar};
