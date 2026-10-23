import React,{useLayoutEffect,useEffect,useRef} from 'react';
import {Button,Icon} from './PlayerControls.jsx';
export default function SearchControl({open,onOpenChange,value,onValueChange,wall=false}){
 const input=useRef(null),root=useRef(null);
 useLayoutEffect(()=>{if(open)input.current?.focus({preventScroll:true});else input.current?.blur();},[open]);
 useEffect(()=>{if(!open||value)return;const outside=event=>{if(!root.current?.contains(event.target))onOpenChange(false);};document.addEventListener('pointerdown',outside,true);return()=>document.removeEventListener('pointerdown',outside,true);},[open,value,onOpenChange]);
 return <div ref={root} className="mv-search mv-search-control" data-mv-component="search-control" data-open={open}><span className="mv-search-leading" aria-hidden="true"><Icon name="search"/></span><input ref={input} aria-label="搜索音乐" placeholder="搜索歌曲、歌手或专辑" value={value} onChange={event=>onValueChange(event.target.value)} tabIndex={open?0:-1} disabled={!open} aria-hidden={!open} enterKeyHint="search" onKeyDown={event=>{if(event.key==='Escape'){event.preventDefault();event.stopPropagation();onOpenChange(false);}if(event.key==='Enter')event.currentTarget.blur();}}/><Button label={open?'收起搜索':'搜索音乐'} icon={open?'close':wall?'wallSearch':'search'} aria-expanded={open} onClick={()=>onOpenChange(!open)}/></div>;
}
