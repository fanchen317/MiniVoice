import React, { memo, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useScrollThumb } from './scrollbar';
import { WallQueue } from './WallQueue';
import { WallLyrics } from './WallLyrics';
import { PlaybackModeMenu } from './PlaybackModeMenu';
import { listColumns,listColumnStyles } from './listColumns';
import { wallDockMetrics,browseGridMetrics,springEasing } from './motion';
import { displayLine, wallCardSizing } from './kinetic';
import { artwork, command, seconds, useClock, usePlayback, useCatalog } from './store';

export const Cover = memo(function Cover({ track, detail=false }) {
  const [failed,setFailed]=useState(false), url=artwork(track,detail);
  useEffect(()=>setFailed(false),[url]);
  return url&&!failed ? <img className="cover" src={url} alt="" decoding="async" draggable="false" onError={()=>setFailed(true)}/> : <div className="cover cover-empty">♫</div>;
});
export function Icon({name}){return <span className="glyph" aria-hidden="true" style={{maskImage:`url("./symbols/${name}.png")`,WebkitMaskImage:`url("./symbols/${name}.png")`}}/>;}
export function IconButton({ label, children, onClick, active=false, className='', ...props }) {
  return <button className={`icon-button ${active?'active':''} ${className}`} title={label} aria-label={label} onClick={onClick} {...props}>{children}</button>;
}
const EMPTY_LINES=[];
export function Lyrics({ track, expanded=false, onEdit }) {
  const {showLyricsTranslation=true}=usePlayback(),clock=useClock(),root=useRef(),activeRef=useRef(-2),scrollFrame=useRef(0),manualUntil=useRef(0),sourceLines=track?.lyrics?.trim()?(track.lines||EMPTY_LINES):EMPTY_LINES;
  const lines=useMemo(()=>sourceLines.map((line,index)=>displayLine(line,sourceLines.slice(index+1).find(next=>next.time>line.time)?.time,track?.duration)),[sourceLines,track?.duration]);
  useScrollThumb(root);
  function align(index,animate=false){
    const el=root.current,line=el?.querySelector(`[data-lyric="${Math.max(0,index)}"]`);if(!line)return;
    cancelAnimationFrame(scrollFrame.current);
    const from=el.scrollTop,to=Math.max(0,line.offsetTop+line.offsetHeight/2-el.clientHeight/2);
    if(!animate||document.documentElement.classList.contains('reduce-motion')){el.scrollTop=to;return;}
    const began=performance.now();function tick(now){const p=Math.min(1,(now-began)/400),eased=p<.5?2*p*p:1-(-2*p+2)**2/2;el.scrollTop=from+(to-from)*eased;if(p<1)scrollFrame.current=requestAnimationFrame(tick);}
    scrollFrame.current=requestAnimationFrame(tick);
  }
  useLayoutEffect(()=>{
    const el=root.current;if(!el)return;activeRef.current=-2;
    const observer=new ResizeObserver(()=>{
      const height=el.clientHeight,width=el.clientWidth,bilingual=showLyricsTranslation&&lines.some(l=>l.translation);
      const base=Math.min(expanded?72:92,Math.max(28,(height-36)/(expanded?6:5))),row=bilingual?Math.max(62,base*1.45):base;
      el.style.setProperty('--lyric-row',`${row}px`);el.style.setProperty('--lyric-font',`${expanded?Math.min(38,Math.max(22,width*.058)):Math.min(34,Math.max(19,base*.56))}px`);
      el.style.setProperty('--lyric-padding',`${height/2}px`);align(activeRef.current,false);
    });observer.observe(el);
    const manual=()=>{cancelAnimationFrame(scrollFrame.current);manualUntil.current=performance.now()+2000;};el.addEventListener('wheel',manual,{passive:true});el.addEventListener('pointerdown',manual);
    return()=>{observer.disconnect();el.removeEventListener('wheel',manual);el.removeEventListener('pointerdown',manual);cancelAnimationFrame(scrollFrame.current);};
  },[track?.id,lines,expanded,showLyricsTranslation]);
  useEffect(()=>{
    const el=root.current;if(!el)return;let frame=0;
    function update(){
      const time=clock.time+(clock.playing?Math.min(.24,(performance.now()-clock.sampledAt)/1000):0);let index=-1;
      for(let i=0;i<lines.length;i++)if(lines[i].time!==null&&lines[i].time<=time)index=i;
      if(index!==activeRef.current){const previous=activeRef.current;activeRef.current=index;
        for(const line of el.querySelectorAll('[data-lyric]')){const n=Number(line.dataset.lyric);line.classList.toggle('current',n===index);line.dataset.emphasis=index<0?'-1':String(Math.min(2,Math.abs(n-index)));}
        if(performance.now()>=manualUntil.current)align(index,previous!==-2);
      }
      const current=el.querySelector('.current');if(current)for(const word of current.querySelectorAll('[data-word-start]')){const from=Number(word.dataset.wordStart),to=Number(word.dataset.wordEnd);word.style.setProperty('--word-progress',`${Math.max(0,Math.min(1,(time-from)/Math.max(.01,to-from)))*100}%`);}
      if(clock.playing)frame=requestAnimationFrame(update);
    }
    update();return()=>cancelAnimationFrame(frame);
  },[clock,lines]);
  const plain=lines.length>0&&lines.every(line=>line.time===null);
  return <div ref={root} className={`lyrics-scroll ${expanded?'expanded':''} ${plain?'plain-lyrics':''}`} aria-label="歌词">
    {track?.lyricsLoading?<div className="lyrics-loading" role="status"><span className="spinner"/><span>正在加载歌词…</span></div>:lines.length?<div className="lyrics-lines">{lines.map((line,index)=><button key={`${track.id}:${index}`} data-lyric={index} className="lyric-line" onClick={()=>line.time!==null&&command('seek',{time:line.time})}><span className="lyric-content">{line.words?.length?line.words.map((word,i)=><span className="lyric-word" key={i} data-word-start={word.start} data-word-end={word.end??line.words[i+1]?.start??line.end??lines[index+1]?.time??word.start+1}>{word.text}</span>):line.text||'♪'}</span>{showLyricsTranslation&&line.translation&&<small>{line.translation}</small>}</button>)}</div>:<div className="empty"><div className="empty-lyrics-icon"><Icon name="lyrics"/><img src="./app-icon.png" alt=""/></div><h3>尚未添加歌词</h3><button className="soft-button" onClick={onEdit}>添加歌词</button></div>}
  </div>;
}
export function TranslationToggle({track}){
  const state=usePlayback();
  if(!track?.lines?.some(line=>line.translation))return null;
  const enabled=state.showLyricsTranslation!==false;
  return <button className={`translation-toggle ${enabled?'active':''}`} aria-label={enabled?'隐藏译文':'显示译文'} aria-pressed={enabled} onClick={()=>command('lyricsPresentation',{translation:!enabled})}>译文</button>;
}
export function NowPlayingIndicator({playing,inline=false}){
  const root=useRef();useEffect(()=>{let frame=0,last=0;const bars=[...root.current.children],reduced=document.documentElement.classList.contains('reduce-motion');
    function tick(now){if(now-last>=1000/30){last=now;bars.forEach((bar,i)=>bar.style.height=`${playing&&!reduced?5+13*(Math.sin(now/1000*(3.8+i*.7)+i*1.6)+1)/2:[7,14,18,10][i]}px`);}if(playing&&!reduced)frame=requestAnimationFrame(tick);}
    tick(performance.now());return()=>cancelAnimationFrame(frame);
  },[playing]);return <span ref={root} className={`now-playing-indicator ${inline?'inline':''}`} aria-label={playing?'正在播放':'当前歌曲已暂停'}><i/><i/><i/><i/></span>;
}
export function Player({ onLocate,onEdit, compact=false,compactWidth=460, onExpand,onAlbum,albumExpanded=false,hiddenChrome=false,immersive=false }) {
  const state=usePlayback(),clock=useClock(),track=state.playing||state.selected,tracks=useCatalog();
  // The outer dock and all its controls use the same viewport calculation in
  // one commit. Measuring the new dock in an observer left its old details
  // and play-button size visible for a frame during each window resize.
  const dockRoot=useRef(),dock=wallDockMetrics(compactWidth);
  const [queue,setQueue]=useState(false),[devices,setDevices]=useState(false),outputRoot=useRef();
  useEffect(()=>{if(hiddenChrome){setQueue(false);setDevices(false);}},[hiddenChrome]);
  useEffect(()=>{if(!devices)return;const outside=event=>{if(!outputRoot.current?.contains(event.target))setDevices(false);},key=event=>{if(event.key==='Escape'){event.preventDefault();event.stopImmediatePropagation();setDevices(false);outputRoot.current?.querySelector('button')?.focus({preventScroll:true});}};window.addEventListener('pointerdown',outside,true);window.addEventListener('keydown',key,true);return()=>{window.removeEventListener('pointerdown',outside,true);window.removeEventListener('keydown',key,true);};},[devices]);
  const [scrub,setScrub]=useState(null),pendingSeek=useRef(null);
  useEffect(()=>{if(pendingSeek.current!==null&&Math.abs(clock.time-pendingSeek.current)<.5){pendingSeek.current=null;setScrub(null);}},[clock.time]);
  function commitSeek(time){pendingSeek.current=time;setScrub(time);command('seek',{time}).catch(()=>{pendingSeek.current=null;setScrub(null);});}
  const duration=track?.duration||0, time=scrub??clock.time;
  const modes=[['list','≡'],['shuffle','⤨'],['repeatOne','↻¹'],['repeatAll','↻'],['single','①']];
  const seek=<div className="seek" style={{'--seek':`${Math.max(0,Math.min(100,time/Math.max(1,duration)*100))}%`}}><span aria-hidden={compact&&dock.detail<.5}>{compact?seconds(time).padStart(5,'0'):seconds(time)}</span><input aria-label="播放进度" type="range" min="0" max={Math.max(1,duration)} step=".05" value={Math.min(time,duration)} onChange={event=>setScrub(Number(event.target.value))} onPointerUp={event=>commitSeek(Number(event.currentTarget.value))} onKeyUp={event=>commitSeek(Number(event.currentTarget.value))}/><span aria-hidden={compact&&dock.detail<.5}>{compact?seconds(duration).padStart(5,'0'):seconds(duration)}</span></div>;
  const play=<button className={`play-main ${state.isPlaying?'is-playing':''}`} title={state.preparing?'正在准备播放':state.isPlaying?'暂停':'播放'} aria-label={state.preparing?'正在准备播放':state.isPlaying?'暂停':'播放'} onClick={()=>command('toggle')}><span className="play-symbol"><Icon name="play"/></span><span className="pause-symbol"><Icon name="pause"/></span></button>;
  if(compact)return <footer ref={dockRoot} style={{'--dock-detail':dock.detail,'--dock-gap':`${dock.spacing}px`,'--dock-padding':`${dock.padding}px`,'--dock-play-side':`${dock.playSide}px`,'--dock-play-font':`${dock.playFont}px`}} className="player compact" aria-label="播放器" inert={hiddenChrome} aria-hidden={hiddenChrome}>{play}<div className="dock-middle"><div className="dock-title"><IconButton label="上一首" onClick={()=>command('skip',{delta:-1})}><Icon name="previous"/></IconButton><button onClick={onLocate}>{track?.title||'选择一首音乐'}</button><IconButton label="下一首" onClick={()=>command('skip',{delta:1})}><Icon name="next"/></IconButton></div>{seek}</div><PlaybackModeMenu/><span className="dock-queue-slot" data-fully-visible={dock.detail>=.999} inert={dock.detail<=.8} aria-hidden={dock.detail<.5}><IconButton label="播放队列" aria-expanded={queue} active={queue} onClick={()=>setQueue(v=>!v)}><Icon name="queue"/></IconButton></span>{queue&&<WallQueue onClose={()=>setQueue(false)}/>}</footer>;
  return <footer className={`player ${compact?'compact':''} ${albumExpanded?'album-controls':''}`} aria-label="播放器"><div className="player-layout">
    <div className="now-playing"><button className="mini-cover" aria-label={albumExpanded?'收起专辑播放模式':onAlbum?'打开专辑播放模式':'定位正在播放的歌曲'} disabled={immersive} onClick={onAlbum||onLocate}><Cover track={track} detail={immersive}/>{onAlbum&&!immersive&&<span className="artwork-hover-arrow"><Icon name={albumExpanded?'chevronDown':'chevronUp'}/></span>}</button><div className="song-info-and-favorite"><button className="now-playing-title" onClick={onLocate}><strong>{track?.title||'选择一首歌'}</strong><span>{track?.artist||'MiniVoice'}</span><small>{track?.album}</small></button>{albumExpanded&&<IconButton label="收藏歌曲" className={`album-favorite icon-button ${state.favorites.includes(track?.path)?'active':''}`} onClick={()=>command('favorite',{id:track.id})}><Icon name={state.favorites.includes(track?.path)?'favoriteFill':'favorites'}/></IconButton>}</div></div>
    <div className="transport"><div className="transport-buttons">
      <IconButton label="播放模式" onClick={()=>command('mode',{value:modes[(modes.findIndex(m=>m[0]===state.mode)+1)%modes.length][0]})}><Icon name={state.mode||'list'}/></IconButton>
      <IconButton label="上一首" onClick={()=>command('skip',{delta:-1})}><Icon name="previousTrack"/></IconButton>
      {play}
      <IconButton label="下一首" onClick={()=>command('skip',{delta:1})}><Icon name="nextTrack"/></IconButton>
      <IconButton label="显示桌面歌词" active={state.desktopLyrics} onClick={()=>command('desktopLyrics')}><Icon name="desktopLyrics"/></IconButton>
    </div>{seek}</div>
    <div ref={outputRoot} className="player-tools"><div className="volume-row"><Icon name="speaker"/><input type="range" aria-label="播放器音量" min="0" max="1" step=".01" value={state.volume} style={{'--volume':`${state.volume*100}%`}} onChange={event=>command('volume',{value:Number(event.target.value)})}/><span>{Math.round(state.volume*100)}%</span></div><button className="output-device" aria-label="选择播放设备" aria-expanded={devices} onClick={()=>setDevices(v=>!v)}><Icon name="airplay"/><span>{state.outputDevices.find(d=>d.id===state.outputDevice)?.name||'声音输出'}</span><span className={`device-disclosure ${devices?'open':''}`}><Icon name="chevronDown"/></span></button>{devices&&<div className="output-popover"><strong>播放设备</strong>{state.outputDevices.map(device=><button key={device.id} className={state.outputDevice===device.id?'active':''} onClick={()=>{command('outputDevice',{id:device.id});setDevices(false);}}>{device.name}</button>)}</div>}</div>
    </div>
  </footer>;
}
export function VirtualList({ tracks, favorites, onMenu, onEdit, selectedID, locateToken, onSelect, multiple=false, selection=new Set(),library=false }) {
  const root=useRef(),[viewport,setViewport]=useState({top:0,height:600,width:800});
  useScrollThumb(root);
  const columns=listColumns(viewport.width,multiple);
  const rowHeight=62,playback=usePlayback();
  useEffect(()=>{const panel=root.current.closest('.songs-panel'),observer=new ResizeObserver(()=>setViewport(v=>({...v,height:root.current.clientHeight,width:panel?.clientWidth||root.current.clientWidth})));observer.observe(root.current);if(panel)observer.observe(panel);return()=>observer.disconnect();},[]);
  useEffect(()=>{if(!locateToken)return;const index=tracks.findIndex(t=>t.id===selectedID);if(index>=0)root.current.scrollTo({top:Math.max(0,index*rowHeight-viewport.height/2),behavior:'smooth'});},[locateToken]);
  useEffect(()=>{root.current.scrollTop=0;setViewport(v=>({...v,top:0}));},[tracks]);
  const first=Math.max(0,Math.floor(viewport.top/rowHeight)-5),last=Math.min(tracks.length,Math.ceil((viewport.top+viewport.height)/rowHeight)+5);
  return <div className={`track-list ${library?'native-columns':''}`} style={library?listColumnStyles(columns):undefined} data-album={columns.album} data-duration={columns.duration} data-edit={columns.edit} ref={root} role="list" aria-label="歌曲列表" onScroll={event=>{const top=event.currentTarget.scrollTop;setViewport(v=>Math.abs(top-v.top)>rowHeight*2?{...v,top}:v);}}>
    <div style={{height:tracks.length*rowHeight,position:'relative'}}>{tracks.slice(first,last).map((track,i)=><div key={track.id} className={`track-row ${selectedID===track.id||selection.has(track.id)?'selected':''} ${multiple?'multi-select':''}`} style={{transform:`translateY(${(first+i)*rowHeight}px)`}} role="listitem"
      onClick={()=>onSelect(track)} onDoubleClick={()=>!multiple&&command('play',{id:track.id,ids:tracks.map(t=>t.id)})} onContextMenu={event=>onMenu(event,track)} tabIndex="0" onKeyDown={event=>event.key==='Enter'&&command('play',{id:track.id,ids:tracks.map(t=>t.id)})}>
      <span className="selection-circle" aria-hidden={!multiple}>{selection.has(track.id)?'✓':''}</span><span className="row-index">{String(first+i+1).padStart(2,'0')}</span><div className="row-cover"><Cover track={track}/>{playback.playing?.id===track.id&&<NowPlayingIndicator playing={playback.isPlaying}/>}</div><div className="row-title"><strong>{track.title}</strong></div><span className="row-artist">{track.artist}</span><span className="row-playing">{!multiple&&playback.playing?.id===track.id&&<NowPlayingIndicator playing={playback.isPlaying} inline/>}</span><span className="row-album">{track.album}</span><span className="row-duration">{seconds(track.duration)}</span>
      <IconButton className="row-favorite" label={`收藏 ${track.title}`} active={favorites.has(track.path)} onClick={event=>{event.stopPropagation();command('favorite',{id:track.id});}}><Icon name={favorites.has(track.path)?'favoriteFill':'favorites'}/></IconButton><IconButton className="row-edit" label={`编辑 ${track.title}`} onClick={event=>{event.stopPropagation();onEdit(track);}}>⋯</IconButton>
    </div>)}</div>
  </div>;
}
export function GroupGrid({ groups, artist, onOpen }) {
  const root=useRef(),positions=useRef(new Map()),reflows=useRef(new Map()),[view,setView]=useState({width:1000,height:600,top:0});
  useEffect(()=>{const panel=root.current.closest('.songs-panel'),observer=new ResizeObserver(()=>setView(v=>({...v,width:panel?.clientWidth||root.current.clientWidth,height:root.current.clientHeight})));observer.observe(root.current);if(panel)observer.observe(panel);return()=>observer.disconnect();},[]);
  useScrollThumb(root);
  const metrics=browseGridMetrics(view.width,artist),{columns,width,compact,height,stride}=metrics,firstRow=Math.max(0,Math.floor(view.top/stride)-2),lastRow=Math.ceil((view.top+view.height)/stride)+2;
  useLayoutEffect(()=>{
    const next=new Map();
    for(const node of root.current.querySelectorAll('.group-card')){
      const to=new DOMMatrix(node.style.transform),previous=positions.current.get(node),running=reflows.current.get(node);
      const from=running?new DOMMatrix(getComputedStyle(node).transform):previous;
      running?.cancel();reflows.current.delete(node);next.set(node,{e:to.e,f:to.f,columns});
      if(previous&&previous.columns!==columns&&!document.documentElement.classList.contains('reduce-motion')){
        const animation=node.animate([{transform:`translate(${from.e}px,${from.f}px)`},{transform:node.style.transform}],{duration:600,easing:springEasing(.28,.92)});
        reflows.current.set(node,animation);animation.finished.catch(()=>{}).finally(()=>{if(reflows.current.get(node)===animation)reflows.current.delete(node);});
      }
    }
    for(const [node,animation] of reflows.current)if(!next.has(node)){animation.cancel();reflows.current.delete(node);}
    positions.current=next;
  },[columns,view.width,firstRow,lastRow,groups,artist]);
  useEffect(()=>()=>{for(const animation of reflows.current.values())animation.cancel();},[]);
  useEffect(()=>{root.current.scrollTop=0;setView(v=>({...v,top:0}));},[groups]);
  return <div className={`group-scroll ${compact?'compact-grid':''}`} ref={root} onScroll={event=>{const top=event.currentTarget.scrollTop;setView(v=>Math.abs(top-v.top)>stride?{...v,top}:v);}} aria-label={artist?'歌手卡片':'专辑卡片'}>
    <div style={{height:Math.ceil(groups.length/columns)*stride,width:metrics.available,position:'relative'}}>{groups.slice(firstRow*columns,lastRow*columns).map((group,index)=>{
      const position=firstRow*columns+index,artists=[...new Set(group.tracks.map(track=>track.artist).filter(Boolean))].sort().join(' / ')||'未知歌手',cover=group.tracks.find(track=>track.artworkKey)||group.tracks[0];
      return <button key={group.name} className={`group-card ${artist?'artist':''} ${compact?'compact-card':''}`} aria-label={`${group.name}，${group.tracks.length} 首歌曲`} style={{width,height,transform:`translate(${position%columns*(width+16)}px,${Math.floor(position/columns)*stride}px)`,'--group-art-size':`${metrics.artwork}px`}} onClick={event=>onOpen(group.name,event)}>
        <div className={`group-art ${cover?.artworkKey?'':'group-art-empty'}`}>{cover?.artworkKey?<Cover track={cover} detail/>:<Icon name={artist?'person':'albums'}/>}</div><div className="group-card-label"><strong title={group.name}>{group.name}</strong>{!artist&&<small title={artists}>{artists}</small>}<small>{group.tracks.length} 首歌曲</small></div>{compact&&<Icon name="next"/>}
      </button>;
    })}</div>
  </div>;
}

export function WallCardPlayer({track,playing,onExpand,expanded,onPlay,size}){
  const state=usePlayback(),clock=useClock(),[scrub,setScrub]=useState(null),pending=useRef(null);
  const live=playing?(state.playing||track):(state.selected?.id===track.id?state.selected:track);
  const sizing=wallCardSizing(size.width,size.height),available=Math.max(1,size.width-2*sizing.padding),side=Math.min(32,Math.max(22,available*.085));
  useEffect(()=>{setScrub(null);pending.current=null;},[track.id,playing]);
  useEffect(()=>{if(pending.current!==null&&(Math.abs(clock.time-pending.current)<1||performance.now()-pending.currentAt>1500)){pending.current=null;setScrub(null);}},[clock.time]);
  const commit=()=>{if(scrub===null)return;pending.current=scrub;pending.currentAt=performance.now();command('seek',{time:scrub}).catch(()=>{pending.current=null;setScrub(null);});};
  const time=scrub??clock.time,kinetic=state.wallLyricsStyle==='kinetic';
  return <div className={`wall-card-content ${playing?'has-playback':''} ${expanded?'is-immersive':''}`} style={{padding:sizing.padding,paddingTop:sizing.padding+(expanded?30:0),'--card-gap':size.width<300?'8px':'16px','--card-title':`${sizing.title}px`,'--card-artist':`${sizing.artist}px`,'--card-status':`${sizing.status}px`,'--card-space':`${sizing.spacing}px`,'--wall-button':`${side}px`}} onClick={event=>event.stopPropagation()} onDoubleClick={event=>event.stopPropagation()}>
    <header>{playing&&<div className={`wall-playback-status ${playing&&state.isPlaying?'animating':''}`}><span className="wall-waveform" aria-hidden="true"><i/><i/><i/></span><span>{playing?(state.preparing?'正在加载':state.isPlaying?'正在播放':'已暂停'):'预览'}</span></div>}<h2>{live.title}</h2><p>{live.artist}</p></header>
    {playing&&<WallLyrics track={live} kinetic={expanded&&kinetic}/>}
    <div className={`wall-card-transport ${available<340?'narrow':''}`}><div className="wall-transport-buttons">{playing&&<IconButton label="上一曲" onClick={()=>command('skip',{delta:-1})}><Icon name="previousOutline"/></IconButton>}<IconButton label={playing&&state.isPlaying?'暂停':'播放歌曲'} onClick={playing?()=>command('toggle'):onPlay}><Icon name={playing&&state.isPlaying?'pause':'play'}/></IconButton>{playing&&<><IconButton label="下一曲" onClick={()=>command('skip',{delta:1})}><Icon name="nextOutline"/></IconButton><IconButton label="收藏歌曲" active={state.favorites.includes(track.path)} onClick={()=>command('favorite',{id:track.id})}><Icon name={state.favorites.includes(track.path)?'favoriteFill':'favorites'}/></IconButton><PlaybackModeMenu/><span className="transport-spacer"/>{expanded&&<IconButton label={kinetic?'切换滚动歌词':'灵动逐字'} active={kinetic} onClick={()=>command('lyricsPresentation',{style:kinetic?'scrolling':'kinetic'})}><Icon name="kinetic"/></IconButton>}<IconButton label={expanded?'收起播放器':'展开播放器'} onClick={onExpand}><Icon name={expanded?'collapse':'expand'}/></IconButton></>}</div>{playing&&<><span className="wall-playback-time">{seconds(time).padStart(5,'0')} / {seconds(live.duration).padStart(5,'0')}</span><input aria-label="播放进度" type="range" style={{'--wall-progress':`${Math.max(0,Math.min(100,time/Math.max(1,live.duration||1)*100))}%`}} min="0" max={live.duration||1} step=".1" value={Math.min(time,live.duration||1)} onChange={event=>setScrub(Number(event.target.value))} onPointerUp={commit} onPointerCancel={()=>{setScrub(null);pending.current=null;}} onKeyUp={commit}/></>}</div>
  </div>;
}
