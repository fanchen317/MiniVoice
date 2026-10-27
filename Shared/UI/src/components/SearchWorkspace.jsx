import React,{useRef} from 'react';
import ActionButton from './ActionButton.jsx';
import ScrollRail from './ScrollRail.jsx';
import {Icon} from './PlayerControls.jsx';
import {formatSearchDuration,lyricsTimingLabel} from './searchResultModel.js';
import './searchWorkspace.css';
/** Editor-only search workspace. Candidate selection never writes the song. */
export default function SearchWorkspace({title,busy,disabled,error,onBack,onSearch,query,onQuery,artist,onArtist,rows,selected,onSelect,children,footer,kind='lyrics'}){
 const list=useRef(null),detail=useRef(null),pending=busy||(rows===null&&!error);
 return <div className="own-search-browser mv-editor-search" data-mv-component="editor-search" aria-label={title} aria-busy={pending}>
  <header><ActionButton className="own-back" aria-label={`返回${title}`} onClick={onBack}><Icon name="chevronLeft"/>返回编辑</ActionButton><strong>{title}</strong></header>
  <form className="own-search-query" onSubmit={event=>{event.preventDefault();if(!busy&&!disabled)onSearch();}}><label>歌曲 / 专辑<input aria-label={`${title}关键词`} value={query} onChange={event=>onQuery(event.target.value)} disabled={busy||disabled}/></label><label>歌手<input aria-label={`${title}歌手`} value={artist} onChange={event=>onArtist(event.target.value)} disabled={busy||disabled}/></label><ActionButton className="own-primary" disabled={busy||disabled} onClick={onSearch}>{busy?'搜索中…':'搜索'}</ActionButton></form>
  {error&&<p role="alert" className="own-search-error">{error}</p>}
  <div className="own-search-columns"><aside><div className="own-search-count">{busy?'正在读取…':rows===null?'搜索结果':`${rows.length} 个结果`}</div><div className="own-search-list" ref={list}>{rows?.map(row=><ActionButton className="own-search-result" key={row.key} aria-pressed={selected===row.key} disabled={busy||disabled} onClick={()=>onSelect(row)}><strong>{row.title}</strong><span>{row.artist||'未知歌手'}</span>{kind==='lyrics'&&<span className="mv-search-album">{row.album||'未提供专辑'}</span>}<small className="mv-search-result-tags">{kind==='lyrics'&&<><span>{lyricsTimingLabel(row)}</span><span>{formatSearchDuration(row.duration)}</span></>}<span>{row.source||'未知来源'}</span></small></ActionButton>)}{rows?.length===0&&<p className="own-note">没有找到结果，试试修改关键词。</p>}</div><ScrollRail target={list}/></aside><div className="own-search-detail"><div className="own-search-detail-scroll" ref={detail}>{pending?<div className="mv-search-loading" role="status" aria-live="polite"><span className="mv-search-spinner" aria-hidden="true"/><strong>正在{selected?'读取预览':'搜索'}…</strong><p>请稍候</p></div>:children||<div className="own-search-empty"><Icon name="search"/><strong>选择一个搜索结果</strong><p>在这里查看完整内容，应用后再保存歌曲。</p></div>}</div><ScrollRail target={detail}/>{footer&&<footer className="own-search-actions">{footer}</footer>}</div></div>
 </div>;
}
