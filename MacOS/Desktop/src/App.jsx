import {wallDockPlacement} from './motion';
import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import {OwnSurfaces} from './OwnPanels';
import CheckControl from '../../../Shared/UI/src/components/CheckControl.jsx';
import Choice from '../../../Shared/UI/src/components/Choice.jsx';
import {MenuPopover} from '../../../Shared/UI/src/components/Menu.jsx';
import {BackgroundTasks} from './BackgroundTasks';
import {PlaylistPicker} from './PlaylistPicker';
import {Modal} from './Modal';
import {groupName,sortCategory,normalizeOrdering,emptyListMessage} from './libraryState';
import {useLiquidGlass} from './liquidGlass';
import { textInputTabNavigation } from './textInputNavigation';
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { layoutTransition, springLayout, styleTransition } from './transitions';
import { Backdrop, BrowsePages, NavigationSelection, SimplePage } from './Pages';
import { artwork, command, signals, useCatalog, usePlayback } from './store';
import { Cover, GroupGrid, Icon, IconButton, Lyrics, TranslationToggle, Player, VirtualList } from './components';
import { WallSearch } from './WallSearch';
import { Wall } from './Wall';
import { wallWorkspaceMetrics } from './wallGeometry';
import { playbackAction } from './shortcuts';
import { state as playbackState } from './store';
import { playerContentWidth, responsivePlayerLayout, cancelPlayerReflow } from './playerReflow';
import { LibraryToolbar } from './LibraryToolbar';

const names={all:'音乐库',recent:'最近播放',favorites:'收藏',artists:'歌手',albums:'专辑',settings:'设置'};
const collator=new Intl.Collator('zh-CN',{numeric:true,sensitivity:'base'});
export default function App(){
  const tracks=useCatalog(),state=usePlayback();
  const [multiple,setMultiple]=useState(false),[selection,setSelection]=useState(new Set());
  function selectRow(track){if(multiple)setSelection(previous=>{const next=new Set(previous);next.has(track.id)?next.delete(track.id):next.add(track.id);return next;});else command('select',{id:track.id});}
  const [style,setStyle]=useState(localStorage.getItem('style')||'simple');
  const [destination,setDestination]=useState('all'),[group,setGroup]=useState(null),[query,setQuery]=useState('');
  const [nativeOrder,setNativeOrder]=useState(null);
  const [ordering,setOrdering]=useState(()=>{try{return normalizeOrdering(JSON.parse(localStorage.getItem('ordering')||'null'));}catch{return normalizeOrdering();}}),[sidebar,setSidebar]=useState(localStorage.getItem('sidebar')!=='false');
  const category=sortCategory(destination,group),sort=ordering[category].field,ascending=ordering[category].ascending;
  const effectiveSort=group&&((destination==='artists'&&sort==='artist')||(destination==='albums'&&sort==='album'))?'title':sort;
  function setOrderingValue(patch){const next={...ordering[category],...patch};setOrdering(previous=>({...previous,[category]:next}));command('sorting',{category,...next});}
  const setSort=field=>setOrderingValue({field}),setAscending=value=>setOrderingValue({ascending:typeof value==='function'?value(ascending):value});
  useEffect(()=>localStorage.setItem('ordering',JSON.stringify(ordering)),[ordering]);
  const initialized=useRef(false);
  useEffect(()=>{if(!state.sorting||initialized.current)return;initialized.current=true;setOrdering(normalizeOrdering(state.sorting));if(state.interfaceStyle)setStyle(state.interfaceStyle);},[state.sorting,state.interfaceStyle]);
  const [context,setContext]=useState(null),[playlistDialog,setPlaylistDialog]=useState(null),[playlistTracks,setPlaylistTracks]=useState(null),[deleteTargets,setDeleteTargets]=useState(null),[deleteFiles,setDeleteFiles]=useState(false),[deleting,setDeleting]=useState(false);
  const [wallPreview,setWallPreview]=useState(null);
  const [notice,setNotice]=useState(''),[location,setLocation]=useState({id:null,token:0,animated:false}),[expanded,setExpanded]=useState(false),[simpleExpanded,setSimpleExpanded]=useState(false),[wallChromeHidden,setWallChromeHidden]=useState(false);
  const sidebarBeforeWall=useRef(null),navigationHandlers=useRef();
  function immersiveWall(value){if(value){sidebarBeforeWall.current=sidebar;setSidebar(false);}else if(sidebarBeforeWall.current!==null){setSidebar(sidebarBeforeWall.current);sidebarBeforeWall.current=null;}}
  const [dockCollapsed,setDockCollapsed]=useState(false);
  const [theme,setTheme]=useState('system');
  const [windowSize,setWindowSize]=useState({width:innerWidth,height:innerHeight});
  const windowWidth=windowSize.width,windowHeight=windowSize.height;
  useLiquidGlass(style);
  const responsiveLayout=useRef();responsiveLayout.current={style,sidebar,expanded,width:windowWidth};
  useEffect(()=>{let timer;const resize=()=>{
    document.documentElement.classList.add('is-resizing');clearTimeout(timer);
    timer=setTimeout(()=>document.documentElement.classList.remove('is-resizing'),160);
    const before=responsiveLayout.current;
    const changesRows=before.style!=='wall'&&!before.expanded&&
      (playerContentWidth(before.width,before.sidebar)<680)!==(playerContentWidth(innerWidth,before.sidebar)<680);
    responsivePlayerLayout(()=>setWindowSize(previous=>previous.width===innerWidth&&previous.height===innerHeight?previous:{width:innerWidth,height:innerHeight}),{start:changesRows});
  };window.addEventListener('resize',resize);return()=>{window.removeEventListener('resize',resize);clearTimeout(timer);cancelPlayerReflow();document.documentElement.classList.remove('is-resizing');};},[]);
  useEffect(()=>{const pointer=()=>document.documentElement.dataset.input='pointer',keyboard=event=>{if(event.key==='Tab'){textInputTabNavigation(event);return;}if(event.key.startsWith('Arrow')&&!event.metaKey&&!event.ctrlKey&&!event.altKey)document.documentElement.dataset.input='keyboard';};window.addEventListener('pointerdown',pointer,true);window.addEventListener('keydown',keyboard,true);return()=>{window.removeEventListener('pointerdown',pointer,true);window.removeEventListener('keydown',keyboard,true);};},[]);
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
  useEffect(()=>{const media=matchMedia('(prefers-reduced-motion: reduce)'),change=()=>setReduceMotion(media.matches);media.addEventListener('change',change);return()=>media.removeEventListener('change',change);},[]);
  useEffect(()=>{
    const error=event=>setNotice(event.detail),styleChanged=event=>navigationHandlers.current.changeStyle(event.detail),navigate=event=>navigationHandlers.current.go(event.detail);
    signals.addEventListener('error',error);signals.addEventListener('engineError',error);signals.addEventListener('style',styleChanged);signals.addEventListener('navigate',navigate);
    command('snapshot');
    return()=>{signals.removeEventListener('error',error);signals.removeEventListener('engineError',error);signals.removeEventListener('style',styleChanged);signals.removeEventListener('navigate',navigate);};
  },[]);
  useEffect(()=>{if(state.error)setNotice(state.error);},[state.error]);
  useEffect(()=>{const key=event=>{
    if(document.querySelector('[aria-modal="true"]'))return;
    if(event.target.closest('input,textarea,select,[role=slider],[role=scrollbar],[role=menu],[aria-modal="true"],[contenteditable="true"]'))return;
    if(event.code==='Space'&&event.target.closest('button,a,[role="button"]'))return;
    const action=playbackAction(event,playbackState.get().playbackShortcuts);if(action){event.preventDefault();command(action.action,action.payload);}
    if(event.key==='Escape'){setContext(null);springLayout(()=>{setExpanded(false);setSimpleExpanded(false);},'.simple-lyrics,.player .mini-cover');}
  };window.addEventListener('keydown',key);return()=>window.removeEventListener('keydown',key);},[]);
  useEffect(()=>{let current=true;if(category!=='tracks')return;command('orderedTracks',{field:effectiveSort,ascending}).then(ids=>{if(current)setNativeOrder({sort:effectiveSort,ascending,positions:new Map(ids.map((id,index)=>[id,index]))});});return()=>{current=false;};},[tracks,effectiveSort,ascending,category]);
  const filtered=useMemo(()=>{
    let result=tracks;
    if(destination==='favorites')result=result.filter(t=>favorites.has(t.path));
    if(destination==='recent'){const order=new Map(state.recent.map((p,i)=>[p,i]));result=result.filter(t=>order.has(t.path)).sort((a,b)=>order.get(a.path)-order.get(b.path));}
    if(playlist){const paths=new Set(playlist.paths);result=result.filter(t=>paths.has(t.path));}
    if(group)result=result.filter(t=>groupName(destination==='artists'?t.artist:t.album,destination==='artists')===group);
    if(query.trim()){const q=query.toLocaleLowerCase();result=result.filter(t=>`${t.title} ${t.artist} ${t.album}`.toLocaleLowerCase().includes(q));}
    if(destination!=='recent')result=[...result].sort((a,b)=>nativeOrder?.sort===effectiveSort&&nativeOrder?.ascending===ascending?(nativeOrder.positions.get(a.id)??Infinity)-(nativeOrder.positions.get(b.id)??Infinity):collator.compare(a[effectiveSort]||'',b[effectiveSort]||'')*(ascending?1:-1));
    return result;
  },[tracks,destination,group,query,effectiveSort,ascending,nativeOrder,recentKey,favoriteKey,playlistKey]);
  const groups=useMemo(()=>{
    if(!['artists','albums'].includes(destination))return[];
    const map=new Map(),q=query.trim().toLocaleLowerCase();
    for(const track of tracks){
      if(q&&!`${track.title} ${track.artist} ${track.album}`.toLocaleLowerCase().includes(q))continue;
      const name=groupName(destination==='artists'?track.artist:track.album,destination==='artists');if(!map.has(name))map.set(name,[]);map.get(name).push(track);
    }
    return [...map].map(([name,tracks])=>({name,tracks})).sort((a,b)=>(sort==='count'?(a.tracks.length-b.tracks.length||collator.compare(a.name,b.name)):collator.compare(a.name,b.name))*(ascending?1:-1));
  },[tracks,destination,query,ascending,sort]);
  function openEditor(track){if(track)command('openEditor',{id:track.id});}
  function changeStyle(value){
    cancelPlayerReflow();
    command('interfaceStyle',{value});
    styleTransition(()=>{immersiveWall(false);setWallChromeHidden(false);setWallPreview(null);setStyle(value);setExpanded(false);setSimpleExpanded(false);setDestination('all');setGroup(null);setQuery('');setMultiple(false);setSelection(new Set());setContext(null);if(value==='simple')setSidebar(true);setLocation(previous=>({id:state.playing?.id,token:previous.token+1,animated:false}));});
  }
  function toggleSidebar(){cancelPlayerReflow();layoutTransition(()=>setSidebar(v=>!v),'.app:not(.style-wall) .workspace,.app:not(.style-wall)>.player,.app:not(.style-wall) .window-tools',360);}
  function toggleAlbum(){cancelPlayerReflow();springLayout(()=>setExpanded(v=>!v),'.player .mini-cover',.38,.9);}
  function go(destination){cancelPlayerReflow();if(destination==='settings'){command('openSettings');return;}immersiveWall(false);setWallChromeHidden(false);setWallPreview(null);if((style==='wall'&&wallMetrics.overlays)||(style==='library'&&sidebarOverlap>0))setSidebar(false);setMultiple(false);setSelection(new Set());setDestination(destination);setGroup(null);setQuery('');setContext(null);setExpanded(false);setLocation(previous=>({id:state.playing?.id,token:previous.token+1,animated:false}));}
  function onMenu(event,track){event.preventDefault();setContext({x:event.clientX,y:event.clientY,origin:event.currentTarget,track});}
  function locatePlaying(){const id=state.playing?.id||state.selected?.id;if((style!=='simple'&&['artists','albums'].includes(destination)&&!group)||!filtered.some(t=>t.id===id))go('all');if(id)command('select',{id});setExpanded(false);setLocation(previous=>({id,token:previous.token+1,animated:true}));}
  useEffect(()=>{if(!state.playing?.id||location.token)return;setLocation({id:state.playing.id,token:1,animated:false});},[state.playing?.id]);
  function requestDelete(ids){setDeleteTargets(tracks.filter(t=>ids.includes(t.id)));setDeleteFiles(false);setContext(null);}
  function pickerFor(track){setPlaylistTracks(multiple&&selection.has(track.id)?filtered.filter(t=>selection.has(t.id)):[track]);setContext(null);}
  const current=state.selected||state.playing,playing=state.playing||state.selected;
  const wallMetrics=wallWorkspaceMetrics(windowWidth,sidebar),dockPlacement=wallDockPlacement(windowWidth,wallMetrics.leadingInset,wallMetrics.dockWidth);
  const contentWidth=windowWidth-24-(sidebar?Math.min(288,Math.max(250,windowWidth*.25))+12:0),albumWide=contentWidth>=680&&windowHeight-108>=420&&contentWidth/Math.max(1,windowHeight-108)>=1.05;
  // Native narrow-window sidebars dim the content only as the panels overlap.
  // Keep the layer mounted so closing the sidebar can fade it back out.
  const sidebarOverlap=Math.max(0,Math.min(288,Math.max(250,windowWidth*.25))+12+280-(windowWidth-24));
  const sidebarDepth=sidebar?Math.min(1,sidebarOverlap/60):0;
  const showGroups=style!=='simple'&&['artists','albums'].includes(destination);
  navigationHandlers.current={changeStyle,go};
  const toolbar=<LibraryToolbar recent={destination==='recent'} title={style==='simple'?(destination==='recent'?'最近播放':'我的歌曲'):(group||playlist?.name||names[destination])} count={filtered.length} sort={sort} onSort={setSort} ascending={ascending} onAscending={()=>setAscending(v=>!v)} onLocate={locatePlaying} multiple={multiple} onMultiple={()=>{setMultiple(v=>!v);setSelection(new Set());}} selection={selection} onSelectAll={()=>setSelection(selection.size===filtered.length?new Set():new Set(filtered.map(t=>t.id)))} onFavorite={()=>command('favoriteMany',{ids:[...selection],value:!filtered.filter(t=>selection.has(t.id)).every(t=>favorites.has(t.path))})} playlists={state.playlists} onPlaylist={()=>setPlaylistTracks(filtered.filter(t=>selection.has(t.id)))} onRemove={()=>requestDelete([...selection])} onRemoveFromPlaylist={playlist?async()=>{await command('removeManyFromPlaylist',{ids:[...selection],playlist:playlist.id});setSelection(new Set());}:undefined} onClearRecent={()=>command('clearRecent')} importing={state.importing} canLocate={Boolean(state.playing)} allFavorite={Boolean(selection.size)&&filtered.filter(t=>selection.has(t.id)).every(t=>favorites.has(t.path))}/>;
  const renderSongList=onBack=><div className="library-layout"><section className="songs-panel">{onBack?React.cloneElement(toolbar,{onBack}):toolbar}<VirtualList key={`${destination}:${group||''}`} library tracks={filtered} favorites={favorites} onMenu={onMenu} onEdit={openEditor} selectedID={state.selected?.id} locateToken={location.token} locateID={location.id} locateAnimated={location.animated} onSelect={selectRow} multiple={multiple} selection={selection}/>{!filtered.length&&<div className="list-empty"><Icon name={destination==='favorites'?'favorites':'queue'}/><h2>{emptyListMessage({destination,query,hasFolders:Boolean(state.folders?.length)})}</h2>{destination!=='favorites'&&!state.folders?.length&&<ActionButton className="primary-button" onClick={()=>command('openSettings')}>打开设置</ActionButton>}</div>}</section></div>;
  return <main data-dock-collapsed={dockCollapsed} className={`app style-${style} ${playing?'':'no-track'} ${sidebar?'with-sidebar':''} ${expanded&&style==='library'?'album-mode':''} ${wallChromeHidden?'wall-immersive':''} ${wallMetrics.overlays?'wall-sidebar-overlays':''} ${expanded&&style==='library'&&!albumWide?'album-stacked':''} ${windowWidth-24-(sidebar?Math.min(288,Math.max(250,windowWidth*.25))+12:0)<680?'controls-two-rows':''}`} style={{'--sidebar-depth':sidebarDepth,'--content-left':`${windowWidth-12-Math.max(280,contentWidth)}px`,'--content-width':`${Math.max(280,contentWidth)}px`,'--wall-inset':`${wallMetrics.leadingInset}px`,'--wall-header-leading':`${wallMetrics.headerLeading}px`,'--wall-dock-left':`${dockCollapsed?wallMetrics.headerLeading:dockPlacement.left}px`,'--wall-dock-width':`${wallMetrics.dockWidth}px`,'--wall-tools-bottom':`${dockCollapsed?18:dockPlacement.toolsBottom}px`}} onClick={()=>context&&setContext(null)}>
    <Backdrop track={style==='simple'?current:playing}/><div className="titlebar"/><div className="window-tools" inert={style==='wall'&&(wallChromeHidden||(sidebar&&wallMetrics.overlays))}><IconButton label="显示或隐藏侧栏" active={style==='wall'&&sidebar} onClick={toggleSidebar}><Icon name="wall-sidebar"/></IconButton></div>
    {style==='wall'&&sidebar&&wallMetrics.overlays&&<ActionButton className="wall-sidebar-dismiss" aria-label="收起覆盖侧栏" onClick={toggleSidebar}/>}
    {style!=='wall'&&<ActionButton className="sidebar-dismiss-layer" style={{opacity:.18*sidebarDepth,pointerEvents:sidebarDepth>0?'auto':'none'}} inert={sidebarDepth===0} aria-hidden={sidebarDepth===0} aria-label="收起覆盖侧栏" onClick={toggleSidebar}/>}
    <aside className="sidebar" inert={!sidebar} aria-hidden={!sidebar}><div className="brand"><ActionButton feedback="none" className="brand-logo" aria-label={`切换到${style==='simple'?'音乐库':style==='library'?'音乐墙':'简易'}样式`} onClick={()=>changeStyle(style==='simple'?'library':style==='library'?'wall':'simple')}><img src="./app-icon.png" alt=""/><span className="style-switch-hint"><Icon name="styleSwitch"/></span></ActionButton><ActionButton className="brand-name" onClick={()=>go('all')}><strong>MiniVoice</strong><small>音乐让生活更美好</small></ActionButton><BackgroundTasks/><IconButton label="收起侧栏" className="sidebar-close icon-button" onClick={toggleSidebar}><Icon name="close"/></IconButton></div>

      {style==='simple'&&<label className="search"><Icon name="search"/><input aria-label="搜索音乐" placeholder="搜索歌曲、歌手或专辑" value={query} onChange={event=>setQuery(event.target.value)}/></label>}<nav className="main-navigation"><NavigationSelection value={destination}/>{[['all','◫'],['recent','◷'],['favorites','♡'],['artists','♙'],['albums','▣']].map(([key,icon])=><ActionButton key={key} className={destination===key?'active':''} onClick={()=>go(key)}><i><Icon name={style==='simple'?key:`navigation-${key}`}/></i>{names[key]}{key==='all'&&<small>{tracks.length}</small>}</ActionButton>)}</nav>
      <div className="playlist-heading"><span className="nav-heading">我的歌单</span></div>
      <nav className="playlist-nav">{state.playlists.map(p=><ActionButton key={p.id} className={destination===p.id?'active':''} onClick={()=>go(p.id)} onContextMenu={event=>{event.preventDefault();setContext({playlist:p,x:event.clientX,y:event.clientY,origin:event.currentTarget});}}><i><Icon name="navigation-queue"/></i><span>{p.name}</span><small>{p.paths.length}</small></ActionButton>)}<ActionButton className="create-playlist" onClick={()=>setPlaylistDialog({name:''})}>＋ 新建歌单</ActionButton></nav>
      {style==='simple'&&<section className="simple-songs">{toolbar}<VirtualList tracks={filtered} favorites={favorites} onMenu={onMenu} onEdit={openEditor} selectedID={state.selected?.id} locateToken={location.token} locateID={location.id} locateAnimated={location.animated} onSelect={selectRow} multiple={multiple} selection={selection}/></section>}<div className="sidebar-bottom"><ActionButton className="add-folder" onClick={()=>command('chooseFolders')}>＋ 添加音乐文件夹</ActionButton><ActionButton className={destination==='settings'?'active':''} onClick={()=>go('settings')}><Icon name="settingsGear"/> 设置</ActionButton><small>{`本地音乐 · ${tracks.length.toLocaleString()} 首`}</small></div>
    </aside>
    {style==='simple'&&destination!=='settings'&&<IconButton label="歌曲信息" className="simple-info-button icon-button" onClick={()=>current&&openEditor(current)}><Icon name="wall-info"/></IconButton>}
    <section className="workspace">{style==='wall'&&(group||destination!=='all')&&<div className="wall-browse-heading"><span>{group||playlist?.name||names[destination]}</span>{group&&<IconButton label="返回卡片" onClick={()=>setGroup(null)}><Icon name="previous"/></IconButton>}</div>}{style==='wall'&&<WallSearch query={query} onQuery={setQuery} hidden={wallChromeHidden} reduceMotion={reduceMotion}/>}
      <><header className="workspace-header"><div className="page-title"><div><span className="eyebrow"></span><h1>{playlist?.name||names[destination]}</h1><p>{showGroups?`${groups.length} ${destination==='artists'?'位歌手':'张专辑'}`:`${filtered.length.toLocaleString()} 首歌曲`}</p></div></div>
        {expanded&&style==='library'?<div className="album-header-actions"><TranslationToggle track={playing}/><IconButton label="歌曲信息" onClick={()=>playing&&openEditor(playing)}><Icon name="wall-info"/></IconButton><IconButton label="返回歌曲列表" onClick={toggleAlbum}><Icon name="chevronDown"/></IconButton></div>:<div className="browse-tools"><label className="search"><Icon name="search"/> <input aria-label="搜索音乐" placeholder="搜索歌曲、歌手或专辑" value={query} onChange={event=>setQuery(event.target.value)}/>{query&&<ActionButton aria-label="清除搜索" onClick={()=>setQuery('')}><Icon name="close"/></ActionButton>}</label>
        <div className="sort-tools">{!(showGroups&&!group)&&<IconButton label="定位正在播放的歌曲" onClick={locatePlaying}><Icon name="locate"/></IconButton>}{destination!=='recent'&&<><Choice label="排序字段" value={sort} onChange={setSort} options={[{value:'title',label:'歌曲名称'},{value:'artist',label:'歌手'},{value:'album',label:'专辑'},{value:'duration',label:'时长'}]}/><IconButton label="切换排序方向" onClick={()=>setAscending(v=>!v)}><Icon name="sort"/></IconButton></>}</div></div>}</header>
      <div className="browse-body"><div className={`library-page-home ${expanded&&style==='library'?'is-covered':''}`} inert={expanded&&style==='library'} aria-hidden={expanded&&style==='library'}>
        {state.importing&&tracks.length===0?<div className="library-loading-placeholder" aria-hidden="true"/>:
        style==='simple'&&!current?<div className="empty"><Icon name="queue"/><h2>添加你的音乐文件夹</h2><ActionButton className="primary-button" onClick={()=>command('openSettings')}>打开设置</ActionButton></div>:style==='simple'?<SimplePage sizing={{width:Math.max(280,contentWidth),height:windowHeight,controls:contentWidth<680?172:106}} track={current} playbackTrack={state.playing||current} expanded={simpleExpanded} onExpanded={setSimpleExpanded} onEdit={openEditor}/>:
        showGroups&&style!=='wall'?<BrowsePages toolbar={React.cloneElement(toolbar,{groupKind:destination==='artists'?'artist':'album',count:groups.length,title:names[destination]})} groups={groups} artist={destination==='artists'} selected={group} onOpen={setGroup} onClose={()=>setGroup(null)}>{renderSongList}</BrowsePages>:
        style==='wall'?<Wall onFocusChange={setWallPreview} contentKey={`${destination}:${group||''}:${query}`} onEscapeSidebar={sidebar?toggleSidebar:undefined} emptyTitle={emptyListMessage({destination,query,hasFolders:Boolean(state.folders?.length)})} sorting={destination==='recent'?undefined:{sort,ascending,onSort:setSort,onAscending:setAscending,grouping:showGroups&&!group,artist:destination==='artists'}} groups={showGroups&&!group?groups:null} onOpenGroup={setGroup} leadingInset={wallMetrics.leadingInset} tracks={showGroups&&!group?groups.map(g=>({...g.tracks[0],title:g.name,artist:`${g.tracks.length} 首歌曲` })):filtered} playingID={state.playing?.id} selectedID={playing?.id} onMenu={onMenu} locateToken={location.token} locateID={location.id} locateAnimated={location.animated} reduceMotion={reduceMotion} onImmersive={immersiveWall} onChromeHidden={setWallChromeHidden} onEdit={openEditor}/>:renderSongList()}
      </div>{style==='library'&&<section className={`album-lyrics ${expanded?'is-open':''}`} inert={!expanded} aria-hidden={!expanded} aria-label="歌词">{expanded&&<Lyrics track={playing} expanded workspace onEdit={()=>playing&&openEditor(playing)}/>}</section>}</div></>

    </section>
    <OwnSurfaces style={style} onStyle={changeStyle}/>
    {(style==='wall'||playing)&&<Player onCompact={setDockCollapsed} previewTrack={wallPreview} onPlayPreview={()=>wallPreview&&command('play',{id:wallPreview.id,ids:filtered.map(t=>t.id)})} compactWidth={wallMetrics.dockWidth} hiddenChrome={wallChromeHidden} compact={style==='wall'} onLocate={locatePlaying} onEdit={openEditor} onExpand={style==='simple'?()=>springLayout(()=>setSimpleExpanded(v=>!v),'.simple-lyrics'):toggleAlbum} onAlbum={style==='library'?toggleAlbum:undefined} albumExpanded={expanded&&style==='library'} immersive={expanded&&style==='library'&&albumWide}/>}
    {notice&&<Modal title="操作失败" alert onClose={()=>{setNotice('');command('clearError');}}><h2>操作失败</h2><p>{notice}</p><div className="dialog-actions"><ActionButton className="primary-button" onClick={()=>{setNotice('');command('clearError');}}>好</ActionButton></div></Modal>}
    {context&&<MenuPopover className="context-menu" point={context} origin={context.origin} onClose={()=>setContext(null)} label={context.playlist?'歌单操作':'歌曲操作'}>{context.playlist?<><ActionButton role="menuitem" onClick={()=>{setPlaylistDialog(context.playlist);setContext(null);}}>重命名歌单</ActionButton><ActionButton role="menuitem" className="destructive" onClick={()=>{command('deletePlaylist',{playlist:context.playlist.id});if(destination===context.playlist.id)go('all');setContext(null);}}>删除歌单</ActionButton></>:<>
      {style==='wall'&&<ActionButton role="menuitem" onClick={()=>{command('select',{id:context.track.id});setLocation(previous=>({id:context.track.id,token:previous.token+1,animated:true}));setContext(null);}}>聚焦</ActionButton>}
      <ActionButton role="menuitem" onClick={()=>{command('play',{id:context.track.id,ids:filtered.map(t=>t.id),preservePosition:style==='wall'});setContext(null);}}>播放</ActionButton>
      <ActionButton role="menuitem" onClick={()=>{openEditor(context.track);setContext(null);}}>编辑歌曲信息、歌词与插图</ActionButton>
      {style!=='simple'&&<><ActionButton role="menuitem" onClick={()=>{command('favorite',{id:context.track.id});setContext(null);}}>{favorites.has(context.track.path)?'取消收藏':'收藏歌曲'}</ActionButton><ActionButton role="menuitem" onClick={()=>pickerFor(context.track)}>加入歌单…</ActionButton>{playlist&&<ActionButton role="menuitem" onClick={()=>{command('removeFromPlaylist',{id:context.track.id,playlist:playlist.id});setContext(null);}}>从此歌单移除</ActionButton>}<ActionButton role="menuitem" onClick={()=>{command('reveal',{id:context.track.id});setContext(null);}}>在 Finder 中显示</ActionButton></>}
      {style!=='wall'&&<ActionButton role="menuitem" className="destructive" onClick={()=>requestDelete([context.track.id])}>删除歌曲</ActionButton>}
    </>}</MenuPopover>}
    {deleteTargets?.length>0&&<Modal title="删除歌曲" alert onClose={deleting?undefined:()=>setDeleteTargets(null)}><h2>删除 {deleteTargets.length} 首歌曲？</h2><p>{deleteFiles?'本地文件将移至废纸篓。':'仅从音乐库移除，保留本地文件。'}</p><label className="trash-option"><CheckControl label="同时移至废纸篓" checked={deleteFiles} disabled={deleting} onCheckedChange={setDeleteFiles}/>同时移至废纸篓</label><div className="dialog-actions"><ActionButton disabled={deleting} onClick={()=>setDeleteTargets(null)}>取消</ActionButton><ActionButton disabled={deleting} className="primary-button destructive" onClick={async()=>{setDeleting(true);try{await command('deleteTracks',{ids:deleteTargets.map(t=>t.id),trash:deleteFiles});setSelection(new Set());setDeleteTargets(null);}finally{setDeleting(false);}}}>确认删除</ActionButton></div></Modal>}
    {playlistTracks&&<PlaylistPicker tracks={playlistTracks} playlists={state.playlists} onClose={()=>setPlaylistTracks(null)}/>}
    {playlistDialog&&<NameDialog title={playlistDialog.id?'重命名歌单':'新建歌单'} initialName={playlistDialog.name} onClose={()=>setPlaylistDialog(null)} onSubmit={async name=>{if(playlistDialog.id)await command('renamePlaylist',{playlist:playlistDialog.id,name});else{const id=await command('createPlaylist',{name});if(id)go(id);}setPlaylistDialog(null);}}/>}

  </main>;
}
function NameDialog({title,initialName='',onClose,onSubmit}){const[name,setName]=useState(initialName),[busy,setBusy]=useState(false);return <Modal title={title} onClose={busy?undefined:onClose}><form onSubmit={async event=>{event.preventDefault();if(!name.trim()||busy)return;setBusy(true);try{await onSubmit(name.trim());}finally{setBusy(false);}}}><h2>{title}</h2><input autoFocus aria-label="歌单名称" placeholder="歌单名称" value={name} onChange={event=>setName(event.target.value)}/><div className="dialog-actions"><ActionButton disabled={busy} type="button" className="soft-button" onClick={onClose}>取消</ActionButton><ActionButton className="primary-button" disabled={busy||!name.trim()}>保存</ActionButton></div></form></Modal>;}
