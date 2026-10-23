import ActionButton from './components/ActionButton.jsx';
import React,{useLayoutEffect,useRef,useState} from 'react';
import {Button} from './components/PlayerControls.jsx';
import Slider from './components/Slider.jsx';
import {lyricWindow,wallCardMetrics} from './wallLayout.js';
const time=value=>`${Math.floor(Math.max(0,value||0)/60000)}:${String(Math.floor(Math.max(0,value||0)/1000)%60).padStart(2,'0')}`;
export function WallLyrics({lines,frame,metrics,onSeek}){
 const window=lyricWindow(lines,frame.index,metrics.count),previous=useRef(window.first),motion=useRef(0),[offset,setOffset]=useState(0);
 useLayoutEffect(()=>{const difference=window.first-previous.current;previous.current=window.first;cancelAnimationFrame(motion.current);if(Math.abs(difference)===1&&!matchMedia('(prefers-reduced-motion:reduce)').matches){setOffset(difference*Math.max(18,metrics.lyricHeight/metrics.count));motion.current=requestAnimationFrame(()=>setOffset(0));}else setOffset(0);return()=>cancelAnimationFrame(motion.current);},[window.first,metrics.count]);
 return <div className="wp-lyrics" aria-label="音乐墙歌词" style={{'--wp-lyric-font':`${metrics.font}px`}}>{window.lines.length?<div className="wp-lyric-window" style={{gridTemplateRows:window.lines.map((_,i)=>window.first+i===window.active?'minmax(0,2.5fr)':'minmax(0,1fr)').join(' '),transform:`translateY(${offset}px)`,transition:offset?'none':undefined}}>{window.lines.map((line,i)=>{const index=window.first+i,active=index===window.active;return <ActionButton type="button" key={`${line.ms}:${index}`} className={`wp-line ${active?'is-active':''}`} data-active={active} aria-current={active?'true':undefined} onClick={()=>line.ms>=0&&onSeek(line.ms)}><span style={{'--ink':active?`${Math.min(100,frame.characters/Math.max(1,line.text.length)*100)}%`:'0%'}}>{line.text}</span>{active&&line.translation&&(!metrics.compact||metrics.lyricHeight/metrics.count>=28)&&<small>{line.translation}</small>}</ActionButton>;})}</div>:<p className="wp-no-lyrics">暂无歌词</p>}</div>;
}
export default function WallPlayer({song,card,current,playing,favorite,lines,frame,position,expanded,mode,onPlay,onToggle,onSkip,onFavorite,onExpand,onClose,onSeek,onMode}){
 const compact=!expanded&&(card.compact||card.height<270),metrics=wallCardMetrics(card.width,card.height,expanded,compact);
 return <div className={`wp-player ${compact?'is-compact':''} ${expanded?'is-expanded':''} ${current?'is-current':'is-preview'}`} style={{padding:metrics.padding}}>
  <header className="wp-header"><div className="wp-heading"><div className={`wp-status ${playing&&current?'is-playing':''}`}>{current&&<span className="wp-bars" aria-hidden="true"><i/><i/><i/></span>}{current?(playing?'正在播放':'已暂停'):'预览'}</div><h1 title={song.title}>{song.title}</h1><p>{song.artist||'未知歌手'}</p></div><Button label={expanded?'收起播放器':'收起播放卡片'} icon={expanded?'collapse':'close'} onClick={onClose}/></header>
  {current?<WallLyrics lines={lines} frame={frame} metrics={metrics} onSeek={onSeek}/>:<div className="wp-preview-space"/>}
  <footer className="wp-footer"><div className="wp-controls">
   <Button label={current?(playing?'暂停':'播放'):'播放这首歌曲'} icon={current&&playing?'pauseFilled':'play'} onClick={current?onToggle:onPlay} data-wall-transport="play"/>
   {!compact&&<Button label="上一首" icon="prev" disabled={!current} onClick={()=>onSkip(-1)}/>}
   {!compact&&<><Button label="下一首" icon="next" disabled={!current} onClick={()=>onSkip(1)}/><Button label={favorite?'取消收藏':'收藏歌曲'} icon="heart" selected={favorite} onClick={onFavorite}/></>}
   <Button label={expanded?'收起播放器':'展开播放器'} icon={expanded?'collapse':'expand'} onClick={onExpand}/>

  </div>{!compact&&<div className="wp-seek"><span>{time(position)}</span><Slider label="播放进度" min={0} max={Math.max(1,song.duration||1)} step={100} value={position} resetKey={song.id} disabled={!current||!song.duration} valueText={value=>`${time(value)} / ${time(song.duration)}`} onCommit={onSeek}/><span>{time(song.duration)}</span></div>}</footer>
 </div>;
}
