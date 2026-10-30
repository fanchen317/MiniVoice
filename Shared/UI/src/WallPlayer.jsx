import KineticLyrics from './components/KineticLyrics.jsx';
import ScrollingLyrics from './components/ScrollingLyrics.jsx';
import ActionButton from './components/ActionButton.jsx';
import React,{useEffect,useRef,useState} from 'react';
import {Button,Icon} from './components/PlayerControls.jsx';
import Slider from './components/Slider.jsx';
import {lyricWindow,wallCardMetrics} from './wallLayout.js';
const time=value=>`${Math.floor(Math.max(0,value||0)/60000)}:${String(Math.floor(Math.max(0,value||0)/1000)%60).padStart(2,'0')}`;
export function WallLyrics({lines,time,duration,playing,onSeek}){return <ScrollingLyrics className="wp-lyrics" lineClass="wp-line" label="音乐墙歌词" lines={lines} time={time/1000} duration={duration/1000} playing={playing} onSeek={seconds=>onSeek(seconds*1000)}/>;}
export default function WallPlayer({song,card,current,playing,favorite,lines,frame,position,expanded,mode,onPlay,onToggle,onSkip,onFavorite,onExpand,onClose,onSeek,onMode,hasTranslation,showTranslation,onTranslation,kinetic=false,onKinetic}){
 const surface=useRef(null),[visible,setVisible]=useState(true);
 useEffect(()=>{const observer=new IntersectionObserver(entries=>setVisible(entries[0]?.isIntersecting??false));if(surface.current)observer.observe(surface.current);return()=>observer.disconnect();},[]);
 const compact=!expanded&&!card.keepControls&&(card.compact||card.height<270),metrics=wallCardMetrics(card.width,card.height,expanded,compact);
 return <div ref={surface} data-wall-visible={visible} className={`wp-player ${compact?'is-compact':''} ${expanded?'is-expanded':''} ${current?'is-current':'is-preview'}`} style={{padding:metrics.padding}}>
  <header className="wp-header"><div className="wp-heading"><div role="status" className={`wp-status ${playing&&current?'is-playing':''}`}>{current&&<span className="wp-bars" aria-hidden="true"><i/><i/><i/></span>}{current?(playing?'正在播放':'已暂停'):'预览'}</div><h1 title={song.title}>{song.title}</h1><p>{song.artist||'未知歌手'}</p></div><div className="wp-header-actions">{current&&hasTranslation&&<ActionButton className="wp-translation-toggle" aria-label={showTranslation?'隐藏译文':'显示译文'} aria-pressed={showTranslation} onClick={onTranslation}>译文</ActionButton>}</div></header>
  {current?(expanded&&kinetic?<KineticLyrics lines={lines} time={position/1000} duration={song.duration/1000} playing={playing&&visible} showTranslation={showTranslation}/>:<WallLyrics lines={lines} time={position} duration={song.duration} playing={playing&&current&&visible} onSeek={onSeek}/>):<div className="wp-preview-space"/>}
  <footer className="wp-footer"><div className="wp-controls">
   <Button label={current?(playing?'暂停':'播放'):'播放这首歌曲'} icon={current&&playing?'pauseFilled':'play'} onClick={current?onToggle:onPlay} data-wall-transport="play"/>
   {!compact&&<Button label="上一首" icon="prev" disabled={!current} onClick={()=>onSkip(-1)}/>}
   {!compact&&<><Button label="下一首" icon="next" disabled={!current} onClick={()=>onSkip(1)}/><Button label={favorite?'取消收藏':'收藏歌曲'} icon="heart" selected={favorite} onClick={onFavorite}/></>}
   {expanded&&current?<ActionButton className="mv-button wp-kinetic-toggle" aria-label={kinetic?'切换到滚动歌词':'切换到大字歌词'} aria-pressed={kinetic} onClick={onKinetic}><Icon name="lyricStyle"/></ActionButton>:<Button className="mv-button wp-expand-toggle" label={expanded?'收起播放器':'展开播放器'} icon={expanded?'collapse':'expand'} onClick={onExpand}/>}

   {expanded&&current&&<Button className="mv-button wp-collapse-toggle" label="收起播放器" icon="collapse" onClick={onExpand}/>}
  </div>{!compact&&<div className="wp-seek"><span>{time(position)}</span><Slider label="播放进度" min={0} max={Math.max(1,song.duration||1)} step={100} value={position} resetKey={song.id} disabled={!current||!song.duration} valueText={value=>`${time(value)} / ${time(song.duration)}`} onCommit={onSeek}/><span>{time(song.duration)}</span></div>}</footer>
 </div>;
}
