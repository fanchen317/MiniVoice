const {randomUUID}=require('node:crypto');
function collectionAction(state,name,p={}){
 const validIds=ids=>{if(!Array.isArray(ids)||ids.some(id=>!state.songs.some(s=>s.id===id)))throw Error('歌曲已不在音乐库内');return [...new Set(ids)];};
 const list=()=>{const value=state.playlists.find(v=>v.id===p.playlist);if(!value)throw Error('歌单不存在');return value;};
 const title=()=>{const value=String(p.name||'').trim();if(!value||value.length>100)throw Error('歌单名称需为 1—100 字');if(state.playlists.some(v=>v.id!==p.playlist&&v.name===value))throw Error('已有同名歌单');return value;};
 switch(name){
 case 'createPlaylist':{const value={id:randomUUID(),name:title(),ids:validIds(p.ids||[])};state.playlists.push(value);return value;}
 case 'renamePlaylist':{const value=list();value.name=title();return value;}
 case 'deletePlaylist':list();state.playlists=state.playlists.filter(v=>v.id!==p.playlist);return true;
 case 'addManyToPlaylist':{const value=list();value.ids=[...new Set([...value.ids,...validIds(p.ids)])];return true;}
 case 'removeManyFromPlaylist':{const value=list(),ids=validIds(p.ids);value.ids=value.ids.filter(id=>!ids.includes(id));return true;}
 case 'favoriteMany':{const ids=validIds(p.ids);state.favorites=p.value?[...new Set([...state.favorites,...ids])]:state.favorites.filter(id=>!ids.includes(id));return true;}
 default:throw Error('未知集合操作');
 }
}
module.exports={collectionAction};
