import {usePopoverPosition} from './usePopoverPosition';
import React, { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { command, usePlayback } from './store';
import { Icon, IconButton } from './components';
const modes=[['single','单曲播放'],['list','列表播放'],['shuffle','随机播放'],['repeatOne','单曲循环'],['repeatAll','列表循环']];
export function PlaybackModeMenu(){
  const state=usePlayback(),root=useRef(),popover=useRef(),[open,setOpen]=useState(false);
  const title=modes.find(m=>m[0]===state.mode)?.[1]||'列表播放';
  const position=usePopoverPosition(root,popover,open,{above:true,align:'center'});
  function toggle(){setOpen(value=>!value);}
  useEffect(()=>{if(!open)return;const outside=event=>{if(!root.current?.contains(event.target)&&!popover.current?.contains(event.target))setOpen(false);},key=event=>{if(event.key==='Escape'){event.preventDefault();event.stopImmediatePropagation();setOpen(false);}};window.addEventListener('pointerdown',outside,true);window.addEventListener('wheel',outside,{capture:true,passive:true});window.addEventListener('keydown',key,true);const resize=()=>setOpen(false);window.addEventListener('resize',resize);popover.current?.querySelector('.selected')?.focus({preventScroll:true});return()=>{window.removeEventListener('pointerdown',outside,true);window.removeEventListener('wheel',outside,true);window.removeEventListener('keydown',key,true);window.removeEventListener('resize',resize);};},[open]);
  return <span className="mode-menu-anchor" ref={root}><IconButton label={`播放模式：${title}`} aria-expanded={open} onClick={toggle}><Icon name={state.mode||'list'}/></IconButton>{open&&createPortal(<div ref={popover} className={`playback-mode-popover ${document.querySelector('.style-wall')?'wall-mode-popover':''}`} role="dialog" aria-label="播放模式" style={position}><strong>播放模式</strong>{modes.map(([value,label])=><button key={value} className={state.mode===value?'selected':''} onClick={()=>{command('mode',{value});setOpen(false);}}><Icon name={value}/><span>{label}</span>{state.mode===value&&<span>✓</span>}</button>)}</div>,document.body)}</span>;
}
