import {usePopoverPosition} from './usePopoverPosition';
import React,{useEffect,useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import {command,useCatalog,usePlayback} from './store';
import {Icon} from './components';
export function WallQueue({onClose}){
  const state=usePlayback(),catalog=useCatalog(),root=useRef(),anchor=useRef(document.querySelector('.dock-queue-slot')),close=useRef(onClose),[top,setTop]=useState(0);close.current=onClose;
  const byID=new Map(catalog.map(track=>[track.id,track])),tracks=(state.queue||[]).map(id=>byID.get(id)).filter(Boolean),first=Math.max(0,Math.floor(top/44)-2),last=Math.ceil((top+264)/44)+2;
  const position=usePopoverPosition(anchor,root,true,{above:true,align:'end'});
  useEffect(()=>{const outside=event=>{if(!root.current?.contains(event.target)&&!event.target.closest('.dock-queue-slot'))close.current();},key=event=>{if(event.key==='Escape'){event.preventDefault();event.stopImmediatePropagation();close.current();document.querySelector('.dock-queue-slot button')?.focus({preventScroll:true});}};window.addEventListener('pointerdown',outside,true);window.addEventListener('keydown',key,true);return()=>{window.removeEventListener('pointerdown',outside,true);window.removeEventListener('keydown',key,true);};},[]);
  return createPortal(<section ref={root} role="dialog" aria-label="播放队列" className="wall-queue-popover" style={position}><header><strong>播放队列</strong><small>{tracks.length} 首</small></header>{!tracks.length&&<p className="queue-empty">暂无播放队列</p>}<div className="wall-queue-scroll" style={{height:Math.min(tracks.length*44,264)}} onScroll={event=>setTop(event.currentTarget.scrollTop)}><div style={{position:'relative',height:tracks.length*44}}>{tracks.slice(first,last).map((track,i)=><button className={track.id===state.playing?.id?'current':''} key={track.id} style={{top:(first+i)*44}} onClick={()=>{command('play',{id:track.id});onClose();}}><Icon name={track.id===state.playing?.id?'speaker':'music'}/><span><strong>{track.title}</strong><small>{track.artist}</small></span></button>)}</div></div></section>,document.body);
}
