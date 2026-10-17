import React, { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { command, usePlayback } from './store';
import { Icon, IconButton } from './components';
const modes=[['list','顺序播放'],['shuffle','随机播放'],['repeatOne','单曲循环'],['repeatAll','列表循环'],['single','单曲播放']];
export function PlaybackModeMenu(){
  const state=usePlayback(),root=useRef(),popover=useRef(),[position,setPosition]=useState(null);
  const title=modes.find(m=>m[0]===state.mode)?.[1]||'顺序播放';
  function toggle(){if(position){setPosition(null);return;}const rect=root.current.getBoundingClientRect(),height=240;setPosition({left:Math.max(8,Math.min(innerWidth-216,rect.x+rect.width/2-104)),top:Math.max(8,Math.min(innerHeight-height-8,rect.top>height+12?rect.top-height-12:rect.bottom+12))});}
  useEffect(()=>{if(!position)return;const outside=event=>{if(!root.current?.contains(event.target)&&!popover.current?.contains(event.target))setPosition(null);},key=event=>{if(event.key==='Escape'){event.preventDefault();event.stopImmediatePropagation();setPosition(null);}};window.addEventListener('pointerdown',outside,true);window.addEventListener('wheel',outside,{capture:true,passive:true});window.addEventListener('keydown',key,true);const resize=()=>setPosition(null);window.addEventListener('resize',resize);popover.current?.querySelector('.selected')?.focus({preventScroll:true});return()=>{window.removeEventListener('pointerdown',outside,true);window.removeEventListener('wheel',outside,true);window.removeEventListener('keydown',key,true);window.removeEventListener('resize',resize);};},[position]);
  return <span className="mode-menu-anchor" ref={root}><IconButton label={`播放模式：${title}`} aria-expanded={Boolean(position)} onClick={toggle}><Icon name={state.mode||'list'}/></IconButton>{position&&createPortal(<div ref={popover} className={`playback-mode-popover ${document.querySelector('.style-wall')?'wall-mode-popover':''}`} role="dialog" aria-label="播放模式" style={position}><strong>播放模式</strong>{modes.map(([value,label])=><button key={value} className={state.mode===value?'selected':''} onClick={()=>{command('mode',{value});setPosition(null);}}><Icon name={value}/><span>{label}</span>{state.mode===value&&<span>✓</span>}</button>)}</div>,document.body)}</span>;
}
