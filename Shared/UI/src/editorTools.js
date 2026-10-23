const translationTag=/^\s*\[translation:([A-Za-z0-9+/=]+)\]\s*$/m;
export function splitLyricsDraft(raw=''){
 const match=raw.match(translationTag);let translation='';
 if(match)try{translation=new TextDecoder('utf-8',{fatal:true}).decode(Uint8Array.from(atob(match[1]),c=>c.charCodeAt(0)));}catch{}
 return {lyrics:raw.replace(translationTag,'').trim(),translation};
}
export function joinLyricsDraft(lyrics,translation=''){
 const original=splitLyricsDraft(lyrics).lyrics,clean=splitLyricsDraft(translation).lyrics;
 if(!clean)return original;const bytes=new TextEncoder().encode(clean);let binary='';for(const byte of bytes)binary+=String.fromCharCode(byte);
 return `[translation:${btoa(binary)}]\n${original}`;
}
export function shiftLyricsTimestamps(raw,seconds){
 if(!Number.isFinite(seconds))throw Error('请输入有效的时间偏移');
 return raw.replace(/([\[<])(\d{1,4}):(\d{2}(?:\.\d{1,3})?)([\]>])/g,(all,open,minutes,part,close)=>{if(open==='['&&close!==']'||open==='<'&&close!=='>')return all;const value=Math.max(0,Math.round((Number(minutes)*60+Number(part)+seconds)*1000));return `${open}${String(Math.floor(value/60000)).padStart(2,'0')}:${String(Math.floor(value/1000)%60).padStart(2,'0')}.${String(value%1000).padStart(3,'0')}${close}`;});
}
export function libraryAudit(songs,{milliseconds=false}={}){
 const groups=new Map(),normalize=value=>String(value||'').normalize('NFKC').trim().replace(/\s+/g,' ').toLocaleLowerCase();
 for(const song of songs){const title=normalize(song.title),artist=normalize(song.artist);if(!title)continue;const key=JSON.stringify([title,artist,Math.round((song.duration||0)/(milliseconds?1000:1))]);if(!groups.has(key))groups.set(key,[]);groups.get(key).push(song);}
 return {duplicates:[...groups.values()].filter(group=>group.length>1),unknown:songs.filter(song=>!normalize(song.artist)||!normalize(song.album))};
}
export function lyricTimingRows(raw=''){
 return raw.split(/\r?\n/).flatMap((text,index)=>{if(!text.trim()||/^\s*\[(?:[a-z]+):[^\]]*\]\s*$/i.test(text))return [];const label=text.replace(/\[\d{1,4}:\d{2}(?:\.\d{1,3})?\]/g,'').replace(/<\d{1,4}:\d{2}(?:\.\d{1,3})?>/g,'').trim();return label?[{index,text:label}]:[];});
}
export function stampLyricLine(raw,index,seconds){
 if(!Number.isInteger(index)||!Number.isFinite(seconds)||seconds<0)throw Error('无效的歌词时间');
 const rows=raw.split(/\r?\n/);if(!lyricTimingRows(raw).some(row=>row.index===index))throw Error('请选择歌词行');
 const old=rows[index].match(/[\[<](\d{1,4}):(\d{2}(?:\.\d{1,3})?)[\]>]/),previous=old?Number(old[1])*60+Number(old[2]):seconds;
 const shifted=shiftLyricsTimestamps(rows[index],seconds-previous).replace(/^\s*(?:\[\d{1,4}:\d{2}(?:\.\d{1,3})?\]\s*)+/,'');
 const ms=Math.round(seconds*1000),time=`${String(Math.floor(ms/60000)).padStart(2,'0')}:${String(Math.floor(ms/1000)%60).padStart(2,'0')}.${String(ms%1000).padStart(3,'0')}`;
 rows[index]=`[${time}]${shifted}`;return rows.join('\n');
}
