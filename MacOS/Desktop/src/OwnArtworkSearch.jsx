import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import React,{useEffect,useRef,useState} from 'react';
import {command} from './store';
export default function ArtworkSearch({id,title,artist,album,disabled,onApply,onError}){
 const [rows,setRows]=useState(null),[preview,setPreview]=useState(null),[busy,setBusy]=useState(false);const revision=useRef(0);
 useEffect(()=>()=>{revision.current++;},[]);
 async function search(){if(busy)return;const serial=++revision.current;setBusy(true);setPreview(null);try{const value=await command('artworkSearch',{id,title,artist,album});if(serial===revision.current)setRows(value);}catch(e){if(serial===revision.current)onError(e.message);}finally{if(serial===revision.current)setBusy(false);}}
 async function select(row){if(busy)return;const serial=++revision.current;setBusy(true);try{const image=await command('artworkDownload',{id,token:row.token});if(serial===revision.current)setPreview({...row,image});}catch(e){if(serial===revision.current)onError(e.message);}finally{if(serial===revision.current)setBusy(false);}}
 return <section className="own-artwork-search" aria-label="在线封面搜索" aria-busy={busy}><ActionButton type="button" disabled={disabled||busy} onClick={search}>{busy?'正在读取封面…':'在线搜索封面'}</ActionButton>{rows&&<><p className="own-note">{rows.length?`${rows.length} 个结果，点击下载预览；应用后仍需保存歌曲。`:'没有找到封面，可修改歌曲信息后重试。'}</p><div className="own-artwork-results">{rows.map(row=><ActionButton type="button" key={row.token} disabled={busy||disabled} onClick={()=>select(row)}><strong>{row.album||title}</strong><small>{row.artist} · {row.source}</small></ActionButton>)}</div></>}{preview&&<div className="own-artwork-preview"><img src={preview.image} alt={`${preview.album} 封面预览`}/><ActionButton type="button" disabled={disabled} onClick={()=>{onApply(preview.image);setPreview(null);setRows(null);}}>应用此封面</ActionButton><ActionButton type="button" onClick={()=>setPreview(null)}>取消预览</ActionButton></div>}</section>;
}
