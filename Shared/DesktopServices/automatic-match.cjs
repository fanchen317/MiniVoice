// Automatic application requires identity agreement before quality ranking.
const normalize=value=>String(value||'').normalize('NFKC').toLowerCase().replace(/[\s\p{P}\p{S}]/gu,'');
function same(a,b){return Boolean(normalize(a))&&normalize(a)===normalize(b);}
function identity(song,candidate){
 if(!same(song.title,candidate.title)||!same(song.artist,candidate.artist))return false;
 if(song.duration&&candidate.duration&&Math.abs(song.duration-candidate.duration)>Math.max(3,song.duration*.02))return false;
 return true;
}
function timingKind(raw=''){
 if(/\[\d+,\d+\].*\(\d+,\d+,\d+\)/.test(raw)||/<\d+:\d+(?:\.\d+)?>/.test(raw))return 'word';
 return /\[\d+:\d+(?:\.\d+)?\]/.test(raw)?'line':'plain';
}
function chooseLyrics(song,rows){
 return rows.filter(row=>identity(song,row)&&row.lyrics?.trim()).map(row=>({...row,timingKind:timingKind(row.lyrics)})).sort((a,b)=>({word:3,line:2,plain:1}[b.timingKind]-{word:3,line:2,plain:1}[a.timingKind])||(same(song.album,b.album)?1:0)-(same(song.album,a.album)?1:0))[0]||null;
}
function chooseArtwork(song,rows){
 // Album identity is required: matching an artist alone risks selecting another release.
 if(['','未知专辑','unknown','unknownalbum'].includes(normalize(song.album)))return null;
 return rows.filter(row=>same(song.album,row.album)&&same(song.artist,row.artist)).sort((a,b)=>(b.width||0)*(b.height||0)-(a.width||0)*(a.height||0))[0]||null;
}
module.exports={chooseLyrics,chooseArtwork,timingKind,identity};
