const fs=require('node:fs/promises'),path=require('node:path');
const {chooseLyrics,chooseArtwork}=require('./automatic-match.cjs');
const {searchLyrics}=require('./online-lyrics.cjs');
const {artworkService}=require('./online-artwork.cjs');
function automaticEnrichment({command,directory,onError=()=>{},nativeSearch,nativeDownload,validateImage,search=searchLyrics,artwork}){
 const art=artwork||artworkService({nativeSearch,nativeDownload});let state={},busy=false;const attempted=new Map();
 async function authorized(song){const file=await fs.realpath(song.path);let allowed=false;for(const root of state.folders||[]){const raw=typeof root==='string'?root:root.path;if(!raw)continue;const folder=await fs.realpath(raw);const rel=path.relative(folder,file);if(rel&&!rel.startsWith('..'+path.sep)&&rel!=='..'&&!path.isAbsolute(rel))allowed=true;}if(!allowed)throw Error('自动补齐：歌曲不在授权目录');return file;}
 async function exclusive(file,data){const temporary=file+'.minivoice-'+require('node:crypto').randomUUID()+'.tmp';try{await fs.writeFile(temporary,data,{flag:'wx'});try{await fs.link(temporary,file);}catch(error){if(error.code!=='EEXIST')throw error;const existing=await fs.readFile(file);if(!existing.equals(Buffer.from(data)))throw Error('自动补齐：已有不同内容，保留原文件');}}finally{await fs.rm(temporary,{force:true});}}

 const journal=path.join(directory,'automatic-enrichment.json');
 async function jobs(){try{return JSON.parse(await fs.readFile(journal,'utf8'));}catch(error){if(error.code==='ENOENT')return [];throw error;}}
 async function store(rows){await fs.mkdir(directory,{recursive:true});const temp=journal+'.tmp';await fs.writeFile(temp,JSON.stringify(rows));await fs.rename(temp,journal);}
 async function run(){if(busy)return;busy=true;try{
  let pending=await jobs();
  // Windows holds the playing file open. Commit only after switching songs on both hosts.
  for(const job of [...pending]){if(job.id===state.playing?.id||Date.now()-(job.lastAttempt||0)<3600000)continue;job.lastAttempt=Date.now();await store(pending);
   try{const current=await command('detail',{id:job.id});if(!current||current.path!==job.path)throw Error('自动补齐：歌曲身份已变化');const source=await authorized(current);const stat=await fs.stat(source);if(stat.size!==job.size||stat.mtimeMs!==job.modified)throw Error('自动补齐：音频文件已变化，取消自动写回');
    const payload={id:job.id,title:current.title,artist:current.artist,album:current.album,lyrics:current.lyrics||'',destination:'both',automatic:true};
    if(job.lyrics){if(current.lyrics?.trim()&&current.lyrics!==job.lyrics)throw Error('自动补齐：歌词已被修改');payload.lyrics=job.lyrics;}
    if(job.artwork&&!current.artworkKey)payload.artwork=job.artwork;
    if(current.canWriteTags){await command('saveMetadata',payload);}else onError('该格式暂不支持嵌入，已保留歌词/封面文件：'+current.title);
    pending=pending.filter(row=>row!==job);await store(pending);
   }catch(error){onError(error.message);}
  }
  const song=state.playing;if(!state.isPlaying||!song?.id||song.lyricsLoading||pending.some(row=>row.id===song.id))return;
  const key=song.id;if(Date.now()-(attempted.get(key)||0)<3600000)return;attempted.set(key,Date.now());
  if(song.lyrics?.trim()&&song.artworkKey)return;
  const file=await authorized(song),initial=await fs.stat(file),job={id:song.id,path:song.path,size:initial.size,modified:initial.mtimeMs};
  const results=await Promise.allSettled([
   !song.lyrics?.trim()?search(song,{additional:[()=>command('lyricsSearch',{id:song.id,title:song.title,artist:song.artist})]}).then(rows=>{const candidate=chooseLyrics(song,rows);if(candidate)job.lyrics=candidate.lyrics;}):Promise.resolve(),
   !song.artworkKey?art.search(song).then(async rows=>{const candidates=rows.filter(row=>chooseArtwork(song,[row])).slice(0,3);const images=await Promise.allSettled(candidates.map(async candidate=>{const image=await art.download({id:song.id,token:candidate.token});return {image,quality:Number(validateImage(image))};}));const best=images.filter(result=>result.status==='fulfilled'&&result.value.quality>0).map(result=>result.value).sort((a,b)=>b.quality-a.quality)[0];if(best)job.artwork=best.image;}):Promise.resolve()
  ]);for(const result of results)if(result.status==='rejected')onError(result.reason.message);
  if(!job.lyrics&&!job.artwork)return;
  const fresh=await command('detail',{id:song.id});if(!fresh||fresh.path!==song.path)throw Error('自动补齐：歌曲已移除');await authorized(fresh);const after=await fs.stat(file);if(after.size!==initial.size||after.mtimeMs!==initial.mtimeMs)throw Error('自动补齐：文件已变化，请重试');
  if(fresh.lyrics?.trim())delete job.lyrics;if(fresh.artworkKey)delete job.artwork;
  const stem=file.slice(0,-path.extname(file).length);
  if(job.lyrics){await exclusive(stem+'.lrc',job.lyrics);}
  if(job.artwork){const match=/^data:image\/(png|jpeg);base64,([A-Za-z0-9+/=]+)$/.exec(job.artwork);if(!match)throw Error('无效自动封面');await exclusive(stem+(match[1]==='png'?'.png':'.jpg'),Buffer.from(match[2],'base64'));}
  if(job.lyrics||job.artwork){pending.push(job);await store(pending);if(job.lyrics)await command('saveMetadata',{id:song.id,title:song.title,artist:song.artist,album:song.album,lyrics:job.lyrics,destination:'sidecar'});}
 }catch(error){onError(error.message);}finally{busy=false;}}
 return {observe(next){state=next;return run();}};
}
module.exports={automaticEnrichment};
