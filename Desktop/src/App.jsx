import React, { useEffect, useMemo, useRef, useState } from 'react';
import { layoutTransition, springLayout, styleTransition } from './transitions';
import { Backdrop, BrowsePages, NavigationSelection, SimplePage } from './Pages';
import { artwork, command, signals, useCatalog, usePlayback } from './store';
import { Cover, GroupGrid, Icon, IconButton, Lyrics, TranslationToggle, Player, VirtualList } from './components';
import { WallSearch } from './WallSearch';
import { Wall } from './Wall';
import { wallWorkspaceMetrics } from './wallGeometry';
import { LibraryToolbar } from './LibraryToolbar';

const names={all:'音乐库',recent:'最近播放',favorites:'收藏',artists:'歌手',albums:'专辑',settings:'设置'};
const collator=new Intl.Collator('zh-CN',{numeric:true,sensitivity:'base'});
export default function App(){
  const tracks=useCatalog(),state=usePlayback();
  const [multiple,setMultiple]=useState(false),[selection,setSelection]=useState(new Set()),[confirmRemove,setConfirmRemove]=useState(false);
  function selectRow(track){if(multiple)setSelection(previous=>{const next=new Set(previous);next.has(track.id)?next.delete(track.id):next.add(track.id);return next;});else command('select',{id:track.id});}
  const [style,setStyle]=useState(localStorage.getItem('style')||'wall');
  const [destination,setDestination]=useState('all'),[group,setGroup]=useState(null),[query,setQuery]=useState('');
  const [nativeOrder,setNativeOrder]=useState(null);
  const [sort,setSort]=useState('title'),[ascending,setAscending]=useState(true),[sidebar,setSidebar]=useState(localStorage.getItem('sidebar')==='true');
  const [editor,setEditor]=useState(null),[context,setContext]=useState(null),[playlistDialog,setPlaylistDialog]=useState(false);
  const [notice,setNotice]=useState(''),[locate,setLocate]=useState(0),[expanded,setExpanded]=useState(false),[simpleExpanded,setSimpleExpanded]=useState(false),[wallChromeHidden,setWallChromeHidden]=useState(false);
  const sidebarBeforeWall=useRef(null),navigationHandlers=useRef();
  function immersiveWall(value){if(value){sidebarBeforeWall.current=sidebar;setSidebar(false);}else if(sidebarBeforeWall.current!==null){setSidebar(sidebarBeforeWall.current);sidebarBeforeWall.current=null;}}
  const [theme,setTheme]=useState('system');
  const [windowSize,setWindowSize]=useState({width:innerWidth,height:innerHeight});
  const windowWidth=windowSize.width,windowHeight=windowSize.height;
  useEffect(()=>{const resize=()=>setWindowSize(previous=>previous.width===innerWidth&&previous.height===innerHeight?previous:{width:innerWidth,height:innerHeight});window.addEventListener('resize',resize);return()=>window.removeEventListener('resize',resize);},[]);
  useEffect(()=>{if(state.appearance)setTheme(state.appearance);},[state.appearance]);
  const [reduceMotion,setReduceMotion]=useState(matchMedia('(prefers-reduced-motion: reduce)').matches);
  const favorites=useMemo(()=>new Set(state.favorites),[state.favorites.join('\n')]);
  const recentKey=destination==='recent'?state.recent.join('\n'):'';
  const favoriteKey=destination==='favorites'?state.favorites.join('\n'):'';
  const playlist=state.playlists.find(p=>p.id===destination),playlistKey=playlist?.paths.join('\n')||'';
  useEffect(()=>{localStorage.setItem('style',style);},[style]);
  useEffect(()=>{localStorage.setItem('sidebar',sidebar);},[sidebar]);
  useEffect(()=>{const media=matchMedia('(prefers-color-scheme: dark)'),apply=()=>document.documentElement.dataset.theme=theme==='system'?(media.matches?'dark':'light'):theme;apply();media.addEventListener('change',apply);return()=>media.removeEventListener('change',apply);},[theme]);
  useEffect(()=>{document.documentElement.classList.toggle('reduce-motion',reduceMotion);},[reduceMotion]);
  useEffect(()=>{
    const error=event=>setNotice(event.detail),style=event=>navigationHandlers.current.changeStyle(event.detail),navigate=event=>navigationHandlers.current.go(event.detail);
    signals.addEventListener('error',error);signals.addEventListener('engineError',error);signals.addEventListener('style',style);signals.addEventListener('navigate',navigate);
    command('snapshot');
    return()=>{signals.removeEventListener('error',error);signals.removeEventListener('engineError',error);signals.removeEventListener('style',style);signals.removeEventListener('navigate',navigate);};
  },[]);
  useEffect(()=>{if(state.error)setNotice(state.error);},[state.error]);
  useEffect(()=>{if(!notice)return;const timer=setTimeout(()=>setNotice(''),8000);return()=>clearTimeout(timer);},[notice]);
  useEffect(()=>{const key=event=>{
    if(event.target.closest('input,textarea,select,[contenteditable="true"]'))return;
    if(event.code==='Space'&&event.target.closest('button,a,[role="button"]'))return;
    if(event.code==='Space'){event.preventDefault();command('toggle');}
    if(event.key==='Escape'){setContext(null);setEditor(null);springLayout(()=>{setExpanded(false);setSimpleExpanded(false);},'.simple-lyrics,.player .mini-cover');}
  };window.addEventListener('keydown',key);return()=>window.removeEventListener('keydown',key);},[]);
  useEffect(()=>{let current=true;if(!['title','artist','album','sourceAdded','added'].includes(sort))return;command('orderedTracks',{field:sort,ascending}).then(ids=>{if(current)setNativeOrder({sort,ascending,positions:new Map(ids.map((id,index)=>[id,index]))});});return()=>{current=false;};},[tracks,sort,ascending]);
  const filtered=useMemo(()=>{
    let result=tracks;
    if(destination==='favorites')result=result.filter(t=>favorites.has(t.path));
    if(destination==='recent'){const order=new Map(state.recent.map((p,i)=>[p,i]));result=result.filter(t=>order.has(t.path)).sort((a,b)=>order.get(a.path)-order.get(b.path));}
    if(playlist){const paths=new Set(playlist.paths);result=result.filter(t=>paths.has(t.path));}
    if(group)result=result.filter(t=>(destination==='artists'?t.artist:t.album)===group);
    if(query.trim()){const q=query.toLocaleLowerCase();result=result.filter(t=>`${t.title} ${t.artist} ${t.album}`.toLocaleLowerCase().includes(q));}
    if(destination!=='recent')result=[...result].sort((a,b)=>nativeOrder?.sort===sort&&nativeOrder?.ascending===ascending?(nativeOrder.positions.get(a.id)??Infinity)-(nativeOrder.positions.get(b.id)??Infinity):(sort==='duration'?a.duration-b.duration:collator.compare(a[sort]||'',b[sort]||''))*(ascending?1:-1));
    return result;
  },[tracks,destination,group,query,sort,ascending,nativeOrder,recentKey,favoriteKey,playlistKey]);
  const groups=useMemo(()=>{
    if(!['artists','albums'].includes(destination))return[];
    const map=new Map(),q=query.trim().toLocaleLowerCase();
    for(const track of tracks){
      if(q&&!`${track.title} ${track.artist} ${track.album}`.toLocaleLowerCase().includes(q))continue;
      const name=(destination==='artists'?track.artist:track.album)||'未知';if(!map.has(name))map.set(name,[]);map.get(name).push(track);
    }
    return [...map].map(([name,tracks])=>({name,tracks})).sort((a,b)=>(sort==='count'?a.tracks.length-b.tracks.length:collator.compare(a.name,b.name))*(ascending?1:-1));
  },[tracks,destination,query,ascending,sort]);
  function changeStyle(value){
    styleTransition(()=>{immersiveWall(false);setWallChromeHidden(false);setStyle(value);setExpanded(false);setSimpleExpanded(false);if(value==='simple'){setSidebar(true);setDestination('all');setGroup(null);}});
  }
  function toggleSidebar(){layoutTransition(()=>setSidebar(v=>!v),'.app:not(.style-wall) .workspace,.app:not(.style-wall)>.player,.app:not(.style-wall) .window-tools',360);}
  function toggleAlbum(){springLayout(()=>setExpanded(v=>!v),'.player .mini-cover',.38,.9);}
  function go(destination){immersiveWall(false);setWallChromeHidden(false);if(style==='wall'&&wallMetrics.overlays)setSidebar(false);setMultiple(false);setSelection(new Set());setDestination(destination);setGroup(null);setQuery('');setContext(null);setExpanded(false);}
  function onMenu(event,track){event.preventDefault();setContext({x:Math.min(event.clientX,innerWidth-240),y:Math.min(event.clientY,innerHeight-350),track});}
  function locatePlaying(){const id=state.playing?.id||state.selected?.id;if(!filtered.some(t=>t.id===id))go('all');setLocate(value=>value+1);}
  const current=state.selected||state.playing,playing=state.playing||state.selected;
  const wallMetrics=wallWorkspaceMetrics(windowWidth,sidebar);
  const contentWidth=windowWidth-24-(sidebar?Math.min(288,Math.max(250,windowWidth*.25))+12:0),albumWide=contentWidth>=680&&innerHeight-104>=420&&contentWidth/Math.max(1,innerHeight-104)>=1.05;
  const showGroups=style!=='simple'&&['artists','albums'].includes(destination);
  navigationHandlers.current={changeStyle,go};
  const toolbar=<LibraryToolbar title={style==='simple'?'':(group||playlist?.name||names[destination])} count={filtered.length} sort={sort} onSort={setSort} ascending={ascending} onAscending={()=>setAscending(v=>!v)} onLocate={locatePlaying} multiple={multiple} onMultiple={()=>{setMultiple(v=>!v);setSelection(new Set());}} selection={selection} onSelectAll={()=>setSelection(selection.size===filtered.length?new Set():new Set(filtered.map(t=>t.id)))} onFavorite={()=>command('favoriteMany',{ids:[...selection],value:!filtered.filter(t=>selection.has(t.id)).every(t=>favorites.has(t.path))})} playlists={state.playlists} onPlaylist={id=>Promise.all([...selection].map(trackID=>command('addToPlaylist',{id:trackID,playlist:id})))} onRemove={()=>setConfirmRemove(true)}/>;
  const renderSongList=onBack=><div className="library-layout"><section className="songs-panel">{onBack?React.cloneElement(toolbar,{onBack}):toolbar}<VirtualList library tracks={filtered} favorites={favorites} onMenu={onMenu} onEdit={setEditor} selectedID={state.selected?.id} locateToken={locate} onSelect={selectRow} multiple={multiple} selection={selection}/>{!filtered.length&&<div className="empty"><h2>{tracks.length?'没有找到匹配的音乐':'添加你的音乐文件夹'}</h2><button className="primary-button" onClick={()=>command('chooseFolders')}>添加音乐文件夹</button></div>}</section></div>;
  return <main className={`app style-${style} ${sidebar?'with-sidebar':''} ${expanded&&style==='library'?'album-mode':''} ${wallChromeHidden?'wall-immersive':''} ${wallMetrics.overlays?'wall-sidebar-overlays':''} ${expanded&&style==='library'&&!albumWide?'album-stacked':''} ${windowWidth-24-(sidebar?Math.min(288,Math.max(250,windowWidth*.25))+12:0)<680?'controls-two-rows':''}`} style={{'--content-left':`${windowWidth-12-Math.max(280,contentWidth)}px`,'--content-width':`${Math.max(280,contentWidth)}px`,'--wall-inset':`${wallMetrics.leadingInset}px`,'--wall-header-leading':`${wallMetrics.headerLeading}px`,'--wall-dock-width':`${wallMetrics.dockWidth}px`,'--wall-tools-bottom':`${wallMetrics.toolsBottom}px`}} onClick={()=>context&&setContext(null)}>
    <Backdrop track={style==='simple'?current:playing}/><div className="titlebar"/><div className="window-tools" inert={style==='wall'&&(wallChromeHidden||(sidebar&&wallMetrics.overlays))}><IconButton label="显示或隐藏侧栏" active={style==='wall'&&sidebar} onClick={toggleSidebar}><Icon name="sidebar"/></IconButton></div>
    {style==='wall'&&sidebar&&wallMetrics.overlays&&<button className="wall-sidebar-dismiss" aria-label="收起覆盖侧栏" onClick={toggleSidebar}/>}
    <aside className="sidebar" inert={!sidebar} aria-hidden={!sidebar}><div className="brand"><button className="brand-logo" aria-label={`切换到${style==='simple'?'音乐库':style==='library'?'音乐墙':'简易'}样式`} onClick={()=>changeStyle(style==='simple'?'library':style==='library'?'wall':'simple')}><img src="./app-icon.png" alt=""/><span className="style-switch-hint"><Icon name="styleSwitch"/></span></button><button className="brand-name" onClick={()=>go('all')}><strong>MiniVoice</strong><small>音乐让生活更美好</small></button><IconButton label="收起侧栏" className="sidebar-close icon-button" onClick={toggleSidebar}><Icon name="close"/></IconButton></div>

      {style==='simple'&&<label className="search"><Icon name="search"/><input aria-label="搜索音乐" placeholder="搜索歌曲、歌手或专辑" value={query} onChange={event=>setQuery(event.target.value)}/></label>}<nav className="main-navigation"><NavigationSelection value={destination}/>{[['all','◫'],['recent','◷'],['favorites','♡'],['artists','♙'],['albums','▣']].map(([key,icon])=><button key={key} className={destination===key?'active':''} onClick={()=>go(key)}><i><Icon name={key}/></i>{names[key]}{key==='all'&&<small>{tracks.length}</small>}</button>)}</nav>
      <div className="playlist-heading"><span className="nav-heading">我的歌单</span></div>
      <nav className="playlist-nav">{state.playlists.map(p=><button key={p.id} className={destination===p.id?'active':''} onClick={()=>go(p.id)}><i>≡</i><span>{p.name}</span><small>{p.paths.length}</small></button>)}<button className="create-playlist" onClick={()=>setPlaylistDialog(true)}>＋ 新建歌单</button></nav>
      {style==='simple'&&<section className="simple-songs">{toolbar}<VirtualList tracks={filtered} favorites={favorites} onMenu={onMenu} onEdit={setEditor} selectedID={state.selected?.id} locateToken={locate} onSelect={selectRow} multiple={multiple} selection={selection}/></section>}<div className="sidebar-bottom"><button className="add-folder" onClick={()=>command('chooseFolders')}>＋ 添加音乐文件夹</button><button className={destination==='settings'?'active':''} onClick={()=>go('settings')}>⚙ 设置与后台任务</button><small>{state.importing?state.scanSummary:`本地音乐 · ${tracks.length.toLocaleString()} 首`}</small></div>
    </aside>
    <section className="workspace">{style==='simple'&&destination!=='settings'&&<IconButton label="歌曲信息" className="simple-info-button icon-button" onClick={()=>current&&setEditor(current)}><Icon name="info"/></IconButton>}{style==='wall'&&(group||destination!=='all')&&<div className="wall-browse-heading"><span>{group||playlist?.name||names[destination]}</span>{group&&<IconButton label="返回卡片" onClick={()=>setGroup(null)}><Icon name="previous"/></IconButton>}</div>}{style==='wall'&&<WallSearch query={query} onQuery={setQuery} hidden={wallChromeHidden} reduceMotion={reduceMotion}/>}
      {destination==='settings'?<Settings state={state} theme={theme} setTheme={value=>{setTheme(value);command('appearance',{value});}} reduceMotion={reduceMotion} setReduceMotion={setReduceMotion}/>:
      <><header className="workspace-header"><div className="page-title"><div><span className="eyebrow"></span><h1>{playlist?.name||names[destination]}</h1><p>{showGroups?`${groups.length} ${destination==='artists'?'位歌手':'张专辑'}`:`${filtered.length.toLocaleString()} 首歌曲`}</p></div></div>
        {expanded&&style==='library'?<div className="album-header-actions"><IconButton label="歌曲信息" onClick={()=>playing&&setEditor(playing)}><Icon name="info"/></IconButton><IconButton label="返回歌曲列表" onClick={toggleAlbum}><Icon name="chevronDown"/></IconButton></div>:<div className="browse-tools"><label className="search"><Icon name="search"/> <input aria-label="搜索音乐" placeholder="搜索歌曲、歌手或专辑" value={query} onChange={event=>setQuery(event.target.value)}/>{query&&<button aria-label="清除搜索" onClick={()=>setQuery('')}>×</button>}</label>
        <div className="sort-tools"><IconButton label="定位正在播放的歌曲" onClick={locatePlaying}>◎</IconButton><select aria-label="排序字段" value={sort} onChange={event=>setSort(event.target.value)}><option value="title">歌曲名称</option><option value="artist">歌手</option><option value="album">专辑</option><option value="duration">时长</option></select><IconButton label="切换排序方向" onClick={()=>setAscending(v=>!v)}>{ascending?'↑':'↓'}</IconButton></div></div>}</header>
      <div className="browse-body"><div className={`library-page-home ${expanded&&style==='library'?'is-covered':''}`} inert={expanded&&style==='library'} aria-hidden={expanded&&style==='library'}>
        {state.importing&&tracks.length===0?<div className="empty"><div className="spinner"/><h2>正在载入音乐库…</h2><p>{state.scanSummary}</p></div>:
        style==='simple'?<SimplePage sizing={{width:Math.max(280,contentWidth),height:windowHeight,controls:contentWidth<680?172:106}} track={current} playbackTrack={state.playing||current} expanded={simpleExpanded} onExpanded={setSimpleExpanded} onEdit={setEditor}/>:
        showGroups&&style!=='wall'?<BrowsePages toolbar={React.cloneElement(toolbar,{groupKind:destination==='artists'?'artist':'album',count:groups.length,title:names[destination]})} groups={groups} artist={destination==='artists'} selected={group} onOpen={setGroup} onClose={()=>setGroup(null)}>{renderSongList}</BrowsePages>:
        style==='wall'?<Wall sorting={{sort,ascending,onSort:setSort,onAscending:setAscending,grouping:showGroups&&!group,artist:destination==='artists'}} groups={showGroups&&!group?groups:null} onOpenGroup={setGroup} leadingInset={wallMetrics.leadingInset} tracks={showGroups&&!group?groups.map(g=>({...g.tracks[0],title:g.name,artist:`${g.tracks.length} 首歌曲` })):filtered} playingID={state.playing?.id} selectedID={playing?.id} onMenu={onMenu} locateToken={locate} reduceMotion={reduceMotion} onImmersive={immersiveWall} onChromeHidden={setWallChromeHidden} onEdit={setEditor}/>:renderSongList()}
      </div>{style==='library'&&<section className={`album-lyrics ${expanded?'is-open':''}`} inert={!expanded} aria-hidden={!expanded}><header className="album-lyrics-heading"><h2>歌词</h2><TranslationToggle track={playing}/></header>{expanded&&<Lyrics track={playing} expanded onEdit={()=>playing&&setEditor(playing)}/>}</section>}</div></>}

    </section>
    <Player hiddenChrome={wallChromeHidden} compact={style==='wall'} onLocate={locatePlaying} onEdit={setEditor} onExpand={style==='simple'?()=>springLayout(()=>setSimpleExpanded(v=>!v),'.simple-lyrics'):toggleAlbum} onAlbum={style==='library'?toggleAlbum:undefined} albumExpanded={expanded&&style==='library'} immersive={expanded&&style==='library'&&albumWide}/>
    {notice&&<div className="toast" role="alert"><span>{notice}</span><button onClick={()=>{setNotice('');command('clearError');}}>×</button></div>}
    {context&&<div className="context-menu" style={{left:context.x,top:context.y}} onClick={event=>event.stopPropagation()}>
      <strong>{context.track.title}</strong><button onClick={()=>{command('play',{id:context.track.id,ids:filtered.map(t=>t.id)});setContext(null);}}>▶ 播放</button>
      <button onClick={()=>{command('favorite',{id:context.track.id});setContext(null);}}>♡ {favorites.has(context.track.path)?'取消收藏':'收藏'}</button><button onClick={()=>{setEditor(context.track);setContext(null);}}>✎ 编辑信息与歌词</button><button onClick={()=>{command('reveal',{id:context.track.id});setContext(null);}}>在 Finder 中显示</button>
      {state.playlists.map(p=><button key={p.id} onClick={()=>{command('addToPlaylist',{id:context.track.id,playlist:p.id});setContext(null);}}>＋ 加入 {p.name}</button>)}
      {playlist&&<button onClick={()=>{command('removeFromPlaylist',{id:context.track.id,playlist:playlist.id});setContext(null);}}>从当前歌单移除</button>}
    </div>}
    {editor&&<Editor track={editor} onClose={()=>setEditor(null)}/>}
    {confirmRemove&&<div className="modal-backdrop"><section className="name-dialog" role="alertdialog" aria-label="移出曲库"><h2>移出 {selection.size} 首歌曲？</h2><p>保留原始音乐文件。</p><div className="dialog-actions"><button onClick={()=>setConfirmRemove(false)}>取消</button><button className="primary-button" onClick={async()=>{for(const id of selection)await command('removeTrack',{id});setSelection(new Set());setConfirmRemove(false);}}>移出曲库</button></div></section></div>}
    {playlistDialog&&<NameDialog title="创建歌单" onClose={()=>setPlaylistDialog(false)} onSubmit={name=>{command('createPlaylist',{name});setPlaylistDialog(false);}}/>}

  </main>;
}
function Settings({state,theme,setTheme,reduceMotion,setReduceMotion}){
  return <div className="settings-page"><span className="eyebrow"></span><h1>设置</h1><p>MiniVoice · 音乐让生活更美好</p>
    <section><h2>音乐文件夹</h2><p>直接使用已有 MiniVoice 曲库与缓存，不复制原始音乐。</p>{state.folders.map(path=><div className="setting-row" key={path}><span className="folder-path">{path}</span><button className="soft-button" onClick={()=>command('removeFolder',{path})}>移除</button></div>)}
      <div className="setting-row"><button className="primary-button" onClick={()=>command('chooseFolders')}>添加文件夹</button><button className="soft-button" onClick={()=>command('rescan')}>重新扫描</button></div><label className="setting-row">扫描子文件夹<input type="checkbox" checked={state.recursive} onChange={event=>command('recursive',{value:event.target.checked})}/></label><small>{state.scanSummary}</small></section>
    <section><h2>外观与动效</h2><label className="setting-row">颜色<select value={theme} onChange={event=>setTheme(event.target.value)}><option value="system">跟随系统</option><option value="dark">深色</option><option value="light">浅色</option></select></label><label className="setting-row">减弱动态效果<input type="checkbox" checked={reduceMotion} onChange={event=>setReduceMotion(event.target.checked)}/></label><div className="setting-row"><span>桌面歌词</span><button className="soft-button" onClick={()=>command('desktopLyrics')}>显示 / 隐藏</button></div></section>
    <section><h2>声音输出</h2><label className="setting-row">输出设备<select value={state.outputDevice||0} onChange={event=>command('outputDevice',{id:Number(event.target.value)})}>{state.outputDevices.map(d=><option value={d.id} key={d.id}>{d.name}</option>)}</select></label><p>空格播放/暂停 · Option + ← / → 切歌 · Command + , 打开设置</p></section>
    <section><h2>后台任务</h2>{state.jobs.length?state.jobs.map(job=><p key={job.id}>{job.finished?'✓':'◌'} {job.detail}</p>):<p>没有正在进行的歌词同步任务</p>}{state.issues.length>0&&<details><summary>扫描提示 ({state.issues.length})</summary>{state.issues.map((issue,i)=><p key={i}>{issue}</p>)}</details>}</section>
  </div>;
}
function NameDialog({title,onClose,onSubmit}){const[name,setName]=useState('');return <div className="modal-backdrop"><form className="name-dialog" onSubmit={event=>{event.preventDefault();if(name.trim())onSubmit(name.trim());}}><h2>{title}</h2><input autoFocus aria-label="歌单名称" placeholder="歌单名称" value={name} onChange={event=>setName(event.target.value)}/><div className="dialog-actions"><button type="button" className="soft-button" onClick={onClose}>取消</button><button className="primary-button" disabled={!name.trim()}>创建</button></div></form></div>;}
function Editor({track,onClose}){
  const [draft,setDraft]=useState({...track,lyrics:track.lyrics||''}),[loading,setLoading]=useState(true),[loaded,setLoaded]=useState(false),[saving,setSaving]=useState(false),[destination,setDestination]=useState('sidecar'),[searching,setSearching]=useState(false),[results,setResults]=useState([]);
  const [error,setError]=useState('');
  useEffect(()=>{let active=true;command('detail',{id:track.id}).then(detail=>{if(active&&detail){setDraft(detail);setLoaded(true);}else if(active)setError('无法读取歌曲，请确认原文件可访问。');}).catch(error=>active&&setError(error.message)).finally(()=>active&&setLoading(false));return()=>{active=false;};},[track.id]);
  async function save(event){event.preventDefault();if(!loaded||saving)return;setSaving(true);try{await command('saveMetadata',{...draft,destination});onClose();}catch(error){setError(error.message);}finally{setSaving(false);}}
  async function search(){setSearching(true);try{setResults(await command('lyricsSearch',{id:track.id}));}catch(error){setError(error.message);}finally{setSearching(false);}}
  return <div className="modal-backdrop"><form className="editor" onSubmit={save}><header><div><span className="eyebrow">SONG DETAILS</span><h2>歌曲信息与歌词</h2></div><IconButton label="关闭编辑器" onClick={onClose} type="button">×</IconButton></header><div className="editor-fields">{[['title','歌曲名称'],['artist','歌手'],['album','专辑']].map(([key,label])=><label key={key}>{label}<input disabled={!loaded||saving} value={draft[key]||''} onChange={event=>setDraft({...draft,[key]:event.target.value})}/></label>)}</div>
    <div className="editor-lyrics-label"><label htmlFor="lyrics-input">歌词 · 支持 LRC 与逐字格式</label><button type="button" className="soft-button" disabled={searching} onClick={search}>{searching?'搜索中…':'在线搜索歌词'}</button><button type="button" className="soft-button" onClick={()=>command('syncLyrics',{id:track.id})}>AI 同步</button></div>
    {results.length>0&&<div className="lyrics-results">{results.map(result=><button type="button" key={result.id} onClick={()=>{setDraft({...draft,lyrics:result.lyrics});setResults([]);}}><strong>{result.title}</strong><small>{result.artist} · {result.source}</small></button>)}</div>}
    <textarea id="lyrics-input" disabled={!loaded||saving} value={draft.lyrics||''} onChange={event=>setDraft({...draft,lyrics:event.target.value})}/><p className="editor-path">{track.path}</p>{loading&&<p>正在读取原文件；如 macOS 提示访问音乐文件夹，请完成授权。</p>}{error&&<p role="alert" className="error">{error}</p>}
    <div className="dialog-actions"><label>歌词保存到 <select value={destination} onChange={event=>setDestination(event.target.value)}><option value="sidecar">lrc 子文件夹</option><option value="tags">音频标签</option></select></label><button type="button" className="soft-button" onClick={onClose}>取消</button><button className="primary-button" disabled={saving||!loaded}>{saving?'正在保存…':'保存修改'}</button></div>
  </form></div>;
}
