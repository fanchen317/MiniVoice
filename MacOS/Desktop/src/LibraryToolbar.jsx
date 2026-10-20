import {createPortal} from 'react-dom';
import {usePopoverPosition} from './usePopoverPosition';
import {SortMenuItem} from './SortMenuItem';
import React,{useEffect,useRef,useState} from 'react';
import {command} from './store';
import {Icon,IconButton} from './components';
export function LibraryToolbar({title,count,sort,onSort,ascending,onAscending,onLocate,multiple,onMultiple,selection,onSelectAll,onFavorite,onPlaylist,onRemove,onRemoveFromPlaylist,onClearRecent,groupKind,onBack,recent=false,importing=false,canLocate=false,allFavorite=false}){
  const [sorting,setSorting]=useState(false),[recentMenu,setRecentMenu]=useState(false),root=useRef(),panel=useRef(),anchor=useRef();
  const position=usePopoverPosition(anchor,panel,sorting||recentMenu,{align:'end'});
  useEffect(()=>{if(!sorting&&!recentMenu)return;const outside=e=>{if(!root.current?.contains(e.target)&&!panel.current?.contains(e.target)){setSorting(false);setRecentMenu(false);}},key=e=>{if(e.key==='Escape'){e.preventDefault();e.stopImmediatePropagation();setSorting(false);setRecentMenu(false);}};window.addEventListener('pointerdown',outside,true);window.addEventListener('keydown',key,true);return()=>{window.removeEventListener('pointerdown',outside,true);window.removeEventListener('keydown',key,true);};},[sorting,recentMenu]);
  useEffect(()=>{setSorting(false);setRecentMenu(false);},[recent,title]);
  const options=groupKind?[['name',groupKind==='artist'?'歌手姓名':'专辑名称'],['count','歌曲数量']]:[['title','歌曲名称'],['artist','歌手'],['album','专辑'],['sourceAdded','添加时间'],['added','更新时间']];
  const allSelected=count>0&&selection.size===count;
  return <div ref={root} className="library-toolbar"><div className="library-toolbar-main"><span>{onBack?<button className="browse-back" onClick={onBack}><Icon name="previous"/>返回</button>:title}</span><span>{count.toLocaleString()} {groupKind?(groupKind==='artist'?'位':'张'):'首'}</span><div ref={anchor} className="toolbar-actions">
    {!groupKind&&<IconButton label="定位正在播放的歌曲" disabled={!canLocate} onClick={onLocate}><Icon name="toolbar-locate"/></IconButton>}
    {!onBack&&!recent&&<IconButton label="重新扫描" disabled={importing} onClick={()=>command('rescan')}><Icon name="toolbar-refresh"/></IconButton>}
    {!recent&&<IconButton label="歌曲排序" disabled={!count} active={sorting} onClick={()=>setSorting(v=>!v)}><Icon name="toolbar-sort"/></IconButton>}
    {!groupKind&&!recent&&<IconButton label={multiple?'退出多选':'多选歌曲'} disabled={!count&&!multiple} active={multiple} onClick={onMultiple}><Icon name={multiple?'checkCircleFill':'toolbar-checklist'}/></IconButton>}
    {recent&&<IconButton label="最近播放选项" disabled={!count} aria-expanded={recentMenu} onClick={()=>setRecentMenu(v=>!v)}><Icon name="ellipsis"/></IconButton>}
    </div></div>
    {recentMenu&&createPortal(<div ref={panel} style={position} className="sort-popover anchored-popover"><button onClick={()=>{onClearRecent();setRecentMenu(false);}}>清空最近播放记录</button></div>,document.body)}
    {sorting&&!recent&&createPortal(<div ref={panel} style={position} className="sort-popover anchored-popover"><strong>{groupKind?'分类排序':'歌曲排序'}</strong>{options.map(([value,label])=><SortMenuItem key={value} selected={sort===value} className={sort===value?'active':''} onClick={()=>{onSort(value);setSorting(false);}}>{label}</SortMenuItem>)}<SortMenuItem selected={ascending} onClick={()=>onAscending()}>升序</SortMenuItem></div>,document.body)}
    <div className={`selection-toolbar ${multiple?'open':''}`} inert={!multiple} aria-hidden={!multiple}><div><small>已选 {selection.size} 首</small><button disabled={!count} onClick={onSelectAll}><Icon name={allSelected?'minusCircle':'checkCircle'}/>{allSelected?'取消全选':'全选'}</button><IconButton label={allFavorite?'取消收藏所选歌曲':'收藏所选歌曲'} onClick={onFavorite} disabled={!selection.size}><Icon name={allFavorite?'favoriteFill':'favorites'}/></IconButton><button disabled={!selection.size} onClick={onPlaylist}>加入歌单</button><IconButton label="删除所选歌曲" disabled={!selection.size} onClick={onRemove}><Icon name="trash"/></IconButton>{onRemoveFromPlaylist&&<button disabled={!selection.size} onClick={onRemoveFromPlaylist}>从歌单移除所选歌曲</button>}</div></div>
  </div>;
}
