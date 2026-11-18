const crypto=require('node:crypto');
const searchKey=value=>String(value||'').normalize('NFKD').toLowerCase().replace(/\p{M}/gu,'').replace(/[^\p{L}\p{N}]/gu,'');
const liveVersion=value=>/\blive\b|现场|現場|演唱会|演唱會/iu.test(String(value||''));
function searchTitle(title,artist){
 const separator=title.indexOf(' - ');
 return artist&&separator>=0&&searchKey(title.slice(0,separator))===searchKey(artist)?title.slice(separator+3).trim():title;
}
function searchScore(row,title,artist,duration){
 let score=0;
 if(searchKey(row.title)===searchKey(title))score+=100;
 if(artist&&searchKey(row.artist)===searchKey(artist))score+=60;
 if(liveVersion(row.title)!==liveVersion(title))score-=100;
 const actual=Number(row.duration),expected=Number(duration);
 if(Number.isFinite(actual)&&actual>0&&Number.isFinite(expected)&&expected>0){const difference=Math.abs(actual-expected);score+=difference<=3?40:difference<=10?10:difference>30?-80:0;}
 if(row.timingKind==='word'||row.timingKind==='line')score+=80;
 if(row.timingKind==='word')score+=40;
 if(row.hasTranslation)score+=10;
 return score;
}
async function searchLyrics({title,artist='',duration=0},{fetch:fetcher=globalThis.fetch,additional=[]}={}){
 title=String(title||'').trim();artist=String(artist).trim();if(!title||title.length>500||artist.length>500)throw Error('请输入有效歌曲名称与歌手');
 if(['未知歌手','unknown artist'].includes(artist.toLowerCase()))artist='';
 title=searchTitle(title,artist);if(!title)return [];
 async function json(url){const response=await fetcher(url,{signal:AbortSignal.timeout(18000),headers:{'User-Agent':'MiniVoice/3.0.0'}});if(response.status===404)return null;if(!response.ok)throw Error('歌词来源响应失败');const reader=response.body.getReader();let size=0,chunks=[];try{while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>2*1024*1024)throw Error('歌词响应超过大小限制');chunks.push(Buffer.from(value));}}finally{await reader.cancel().catch(()=>{});}return JSON.parse(Buffer.concat(chunks).toString('utf8'));}
 const sources=[async()=>{const url=new URL('https://lrclib.net/api/search');url.searchParams.set('track_name',title);if(artist)url.searchParams.set('artist_name',artist);const rows=await json(url);if(!Array.isArray(rows))return [];return rows.map(row=>({source:'LRCLIB',title:row.trackName,artist:row.artistName,album:row.albumName,duration:row.duration,lyrics:row.syncedLyrics||row.plainLyrics||''}));},async()=>{const url=new URL('https://api.lrc.cx/jsonapi');url.searchParams.set('title',title);url.searchParams.set('artist',artist);const rows=await json(url);return Array.isArray(rows)?rows.map(row=>({source:'LrcAPI',title:row.title||row.name||title,artist:row.artist||artist,album:row.album,lyrics:row.yrc||row.lrc||''})):[];},async()=>{if(!artist)return [];const row=await json('https://api.lyrics.ovh/v1/'+encodeURIComponent(artist)+'/'+encodeURIComponent(title));return row?.lyrics?[{source:'Lyrics.ovh',title,artist,lyrics:row.lyrics}]:[];},...additional];
 const settled=await Promise.allSettled(sources.map(fn=>fn()));if(settled.every(result=>result.status==='rejected'))throw Error('所有歌词来源均请求失败，请检查网络后重试');
 const rows=[];for(const result of settled)if(result.status==='fulfilled')for(const row of result.value){if(typeof row.lyrics!=='string'||!row.lyrics.trim())continue;const key=crypto.createHash('sha256').update([row.title,row.artist,row.lyrics].join('\n')).digest('hex');rows.push({...row,id:row.id||key,timingKind:row.timingKind||require('./automatic-match.cjs').timingKind(row.lyrics),hasTranslation:Boolean(row.hasTranslation),dedupeKey:key});}
 rows.sort((a,b)=>searchScore(b,title,artist,duration)-searchScore(a,title,artist,duration));
 const seen=new Set(),result=[];for(const {dedupeKey,...row} of rows){if(seen.has(dedupeKey))continue;seen.add(dedupeKey);result.push(row);if(result.length>=100)break;}return result;
}
module.exports={searchLyrics};
