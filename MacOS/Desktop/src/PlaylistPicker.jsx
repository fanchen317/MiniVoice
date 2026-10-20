import React,{useState} from 'react';
import {Modal} from './Modal';
import {Icon} from './components';
import {command} from './store';
export function PlaylistPicker({tracks,playlists,onClose}){
  const [name,setName]=useState(''),[busy,setBusy]=useState(false);
  async function add(id){setBusy(true);try{await command('addManyToPlaylist',{ids:tracks.map(t=>t.id),playlist:id});onClose();}finally{setBusy(false);}}
  async function create(event){event.preventDefault();if(!name.trim()||busy)return;setBusy(true);try{const id=await command('createPlaylist',{name:name.trim()});if(id)await add(id);}finally{setBusy(false);}}
  return <Modal title="加入歌单" onClose={busy?undefined:onClose} className="playlist-picker"><header><h2>加入歌单</h2><button disabled={busy} onClick={onClose}>取消</button></header><p>{tracks.length===1?tracks[0].title:`已选 ${tracks.length} 首歌曲`}</p><div className="playlist-picker-list">{playlists.length?playlists.map(p=>{const added=tracks.every(t=>p.paths.includes(t.path));return <button key={p.id} disabled={busy||added} onClick={()=>add(p.id)}><Icon name="queue"/><span>{p.name}</span><small>{added?'✓ 已在歌单中':'⊕'}</small></button>;}):<div className="playlist-picker-empty"><Icon name="queue"/><p>还没有歌单，可在下方新建并加入。</p></div>}</div><form onSubmit={create}><input aria-label="新歌单名称" placeholder="新歌单名称" value={name} onChange={e=>setName(e.target.value)}/><button className="primary-button" disabled={busy||!name.trim()}>新建并加入</button></form></Modal>;
}
