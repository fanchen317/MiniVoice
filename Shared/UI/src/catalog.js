/** Shared navigation rules; identifiers stay strings on every host. */
const catalogCollator=new Intl.Collator('zh-CN',{numeric:true});
export const sections=['音乐库','最近播放','收藏','歌手','专辑'];
export function catalogFor(snapshot,section,group,query='',sort='title',descending=false){
 const favorites=new Set(snapshot.favorites||[]),recent=snapshot.recent||[],playlist=(snapshot.playlists||[]).find(p=>'歌单:'+p.id===section);
 let songs=snapshot.songs||[];
 if(section==='收藏')songs=songs.filter(song=>favorites.has(song.id));
 if(section==='最近播放'){const index=new Map(songs.map(song=>[song.id,song]));songs=recent.map(id=>index.get(id)).filter(Boolean);}
 if(playlist){const included=new Set(playlist.ids);songs=songs.filter(song=>included.has(song.id));}
 const key=value=>String(value||'').normalize('NFKC').toLocaleLowerCase().trim();
 const normalizedQuery=key(query);if(normalizedQuery)songs=songs.filter(song=>key(`${song.title} ${song.artist} ${song.album}`).includes(normalizedQuery));
 const grouped=!group&&(section==='歌手'||section==='专辑');
 if(grouped){const groups=new Map();for(const song of songs){const name=section==='歌手'?song.artist:song.album;const row=groups.get(name)||{id:name,title:name,count:0,artwork:song.artwork};row.count++;groups.set(name,row);}songs=[...groups.values()];}
 else if(group)songs=songs.filter(song=>(section==='歌手'?song.artist:song.album)===group);
 if(section!=='最近播放')songs=[...songs].sort((a,b)=>{const first=a[sort],second=b[sort];return (typeof first==='number'?first-second:catalogCollator.compare(String(first||''),String(second||'')))*(descending?-1:1);});
 return {items:songs,grouped};
}
export function wallCells(camera,width,height,count){
 if(!count||width<=0||height<=0)return [];
 const unitX=184,unitY=250,scale=Math.max(.6,Math.min(1.6,camera.scale||1));
 const startX=Math.floor(-camera.x/(unitX*scale))-1,startY=Math.floor(-camera.y/(unitY*scale))-1,cols=Math.ceil(width/(unitX*scale))+2,rows=Math.ceil(height/(unitY*scale))+2;
 return Array.from({length:Math.min(120,cols*rows)},(_,i)=>{const x=startX+i%cols,y=startY+Math.floor(i/cols),index=((y*11+x)%count+count)%count;return {key:`${x}:${y}`,index,x:x*unitX,y:y*unitY};});
}
