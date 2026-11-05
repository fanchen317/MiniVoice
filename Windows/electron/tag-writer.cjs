const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const locks=new Set();
async function writeMP3(file,patch,{beforeCommit=async()=>{}}={}){
 if(path.extname(file).toLowerCase()!=='.mp3')throw Error('当前安全标签写入仅接入 MP3');
 if(locks.has(file))throw Error('此歌曲正在保存');locks.add(file);
 let temporary;
 try{
 const id3=require('node-id3'),stat=await fs.stat(file);if(stat.size>256*1024*1024)throw Error('此文件超过当前标签写入的 256 MB 上限');
 const original=await fs.readFile(file),hash=b=>crypto.createHash('sha256').update(b).digest('hex'),originalHash=hash(original);
 const tags={};for(const key of ['title','artist','album'])if(patch[key]!==undefined){if(typeof patch[key]!=='string'||patch[key].length>500)throw Error('无效歌曲信息');tags[key]=patch[key];}
 if(!tags.title?.trim())throw Error('歌曲名称不能为空');
 if(patch.lyrics!==undefined){if(typeof patch.lyrics!=='string'||Buffer.byteLength(patch.lyrics)>1024*1024)throw Error('歌词超过大小限制');tags.unsynchronisedLyrics={language:'eng',text:patch.lyrics};}
 if(patch.removeArtwork)tags.image=null;
 if(patch.image)tags.image=patch.image;
 const output=id3.update(tags,original);if(!Buffer.isBuffer(output))throw Error('标签写入失败');
 const audio=b=>{const value=id3.removeTagsFromBuffer(b);if(!Buffer.isBuffer(value))throw Error('无法校验原始音频');return hash(value);};
 if(audio(output)!==audio(original))throw Error('音频数据校验失败，原文件未更改');
 const check=id3.read(output),old=id3.read(original);const changed=new Set(['TIT2','TPE1','TALB',...(patch.lyrics!==undefined?['USLT']:[]),...(patch.image||patch.removeArtwork?['APIC']:[])]);for(const [key,value] of Object.entries(old.raw||{}))if(!changed.has(key)&&!require('node:util').isDeepStrictEqual(check.raw?.[key],value))throw Error('原有标签无法完整保留，原文件未更改');if(patch.removeArtwork&&check.image)throw Error('封面移除校验失败');for(const key of ['title','artist','album'])if(tags[key]!==undefined&&check[key]!==tags[key])throw Error('标签回读校验失败');
 if(tags.unsynchronisedLyrics&&check.unsynchronisedLyrics?.text!==patch.lyrics)throw Error('歌词回读校验失败');
 temporary=path.join(path.dirname(file),'.minivoice-'+crypto.randomUUID()+'.mp3');await fs.writeFile(temporary,output,{flag:'wx',mode:stat.mode});
 const disk=await fs.readFile(temporary);if(hash(disk)!==hash(output))throw Error('临时文件校验失败');
 await beforeCommit();if(hash(await fs.readFile(file))!==originalHash)throw Error('文件已被其他程序修改，请重新打开编辑器');
 const backupDir=path.join(path.dirname(file),'backup');await fs.mkdir(backupDir,{recursive:true});const backup=path.join(backupDir,path.basename(file)+'.minivoice-backup-'+crypto.randomUUID());await fs.copyFile(file,backup,fs.constants.COPYFILE_EXCL);
 if(hash(await fs.readFile(backup))!==originalHash)throw Error('备份校验失败，原文件未更改');
 await fs.rename(temporary,file);temporary=null;return {backup};
 }finally{if(temporary)await fs.rm(temporary,{force:true});locks.delete(file);}
}
module.exports={writeMP3};
