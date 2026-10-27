import React,{useRef} from 'react';
import {Modal} from './Modal';
import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import ScrollRail from '../../../Shared/UI/src/components/ScrollRail.jsx';
import {Icon} from '../../../Shared/UI/src/components/PlayerControls.jsx';
/** Editor-only search workspace. Candidate selection never writes the song. */
export default function OwnSearchBrowser({title,busy,disabled,error,onBack,onSearch,query,onQuery,artist,onArtist,rows,selected,onSelect,children,footer}){
 const list=useRef(null),detail=useRef(null);
 return <Modal title={title} className="own-panel own-search-modal" onClose={onBack}><div className="own-search-browser" data-mv-component="editor-search" aria-label={title} aria-busy={busy}>
  <header><ActionButton className="own-back" aria-label={`返回${title}`} onClick={onBack}><Icon name="chevronLeft"/>返回编辑</ActionButton><strong>{title}</strong></header>
  <form className="own-search-query" onSubmit={event=>{event.preventDefault();if(!busy&&!disabled)onSearch();}}><label>歌曲 / 专辑<input aria-label={`${title}关键词`} value={query} onChange={event=>onQuery(event.target.value)} disabled={busy||disabled}/></label><label>歌手<input aria-label={`${title}歌手`} value={artist} onChange={event=>onArtist(event.target.value)} disabled={busy||disabled}/></label><ActionButton className="own-primary" disabled={busy||disabled} onClick={onSearch}>{busy?'搜索中…':'搜索'}</ActionButton></form>
  {error&&<p role="alert" className="own-search-error">{error}</p>}
  <div className="own-search-columns"><aside><div className="own-search-count">{busy?'正在读取…':rows===null?'搜索结果':`${rows.length} 个结果`}</div><div className="own-search-list" ref={list}>{rows?.map(row=><ActionButton className="own-search-result" key={row.key} aria-pressed={selected===row.key} disabled={busy||disabled} onClick={()=>onSelect(row)}><strong>{row.title}</strong><span>{row.artist||'未知歌手'}</span><small>{row.source}</small></ActionButton>)}{rows?.length===0&&<p className="own-note">没有找到结果，试试修改关键词。</p>}</div><ScrollRail target={list}/></aside><div className="own-search-detail"><div className="own-search-detail-scroll" ref={detail}>{children||<div className="own-search-empty"><Icon name="search"/><strong>选择一个搜索结果</strong><p>在这里查看完整内容，应用后再保存歌曲。</p></div>}</div><ScrollRail target={detail}/>{footer&&<footer className="own-search-actions">{footer}</footer>}</div></div>
 </div></Modal>;
}
