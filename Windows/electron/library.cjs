const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const extensions=new Set(['.mp3','.flac','.m4a','.aac','.wav','.aiff','.ogg','.opus']);
async function scan(roots,{recursive=true,excluded=[],metadata,previous=[],onProgress=()=>{}}={}){
 const songs=[],seen=new Set(),old=new Map(previous.map(song=>[song.path,song]));
 async function visit(dir){for(const entry of await fs.readdir(dir,{withFileTypes:true})){
  if(entry.isSymbolicLink()||entry.name.toLowerCase()==='backup')continue;
  const file=path.join(dir,entry.name);
  if(entry.isDirectory()){if(recursive)await visit(file);continue;}
  if(!entry.isFile()||!extensions.has(path.extname(file).toLowerCase()))continue;
  const canonical=await fs.realpath(file),key=process.platform==='win32'?canonical.toLowerCase():canonical;
  if(seen.has(key)||excluded.includes(canonical))continue;seen.add(key);
  const stat=await fs.stat(canonical);
  const cached=old.get(canonical);let tags={};if(cached&&!cached.metadataError&&cached.modified===stat.mtimeMs&&cached.size===stat.size)tags=cached;else if(metadata)try{tags=await metadata(canonical);}catch(error){tags={metadataError:error.message};}
  songs.push({id:crypto.createHash('sha256').update(key).digest('hex'),path:canonical,title:path.basename(file,path.extname(file)),artist:'未知歌手',album:'未知专辑',duration:0,modified:stat.mtimeMs,size:stat.size,added:stat.birthtimeMs,...tags});onProgress({count:songs.length,path:canonical});
 }}
 for(const root of roots)await visit(root);
 return songs;
}
module.exports={scan};
