import React,{useLayoutEffect,useEffect,useRef,useState} from 'react';
import {Button,Icon} from './PlayerControls.jsx';
export default function SearchControl({open,onOpenChange,value,onValueChange,wall=false}){
 const input=useRef(null),root=useRef(null),pending=useRef(null),[draft,setDraft]=useState(value);
 // Editing stays synchronous while the host persists controlled queries asynchronously.
 useEffect(()=>{if(!open||pending.current===null||value===pending.current){pending.current=null;setDraft(value);}},[value,open]);
 // Hide only toolbar actions actually covered by the animated search surface.
 useLayoutEffect(()=>{
  const search=root.current,toolbar=search?.parentElement;
  if(!toolbar?.closest('[data-presentation=mobile]'))return;
  const actions=[...toolbar.children].filter(node=>node!==search&&node.matches('.mv-button,.mv-back'));
  const measure=()=>{
   const box=search.getBoundingClientRect();
   for(const action of actions){const rect=action.getBoundingClientRect(),covered=open&&box.left<rect.right&&box.right>rect.left&&box.top<rect.bottom&&box.bottom>rect.top;
    action.dataset.searchOccluded=String(covered);action.inert=covered;
   }
  };
  const observer=new ResizeObserver(measure);observer.observe(search);observer.observe(toolbar);actions.forEach(action=>observer.observe(action));measure();
  globalThis.addEventListener('minivoice-insets',measure);
  return()=>{observer.disconnect();globalThis.removeEventListener('minivoice-insets',measure);actions.forEach(action=>{delete action.dataset.searchOccluded;action.inert=false;});};
 },[open]);
 useLayoutEffect(()=>{if(open)input.current?.focus({preventScroll:true});else input.current?.blur();},[open]);
 useEffect(()=>{if(!open||draft)return;const outside=event=>{if(!root.current?.contains(event.target))onOpenChange(false);};document.addEventListener('pointerdown',outside,true);return()=>document.removeEventListener('pointerdown',outside,true);},[open,draft,onOpenChange]);
 return <div ref={root} className="mv-search mv-search-control" data-mv-component="search-control" data-open={open}><span className="mv-search-leading" aria-hidden="true"><Icon name="search"/></span><input ref={input} aria-label="搜索音乐" placeholder="搜索歌曲、歌手或专辑" value={draft} onChange={event=>{const next=event.target.value;pending.current=next;setDraft(next);onValueChange(next);}} tabIndex={open?0:-1} disabled={!open} aria-hidden={!open} enterKeyHint="search" onKeyDown={event=>{if(event.key==='Escape'){event.preventDefault();event.stopPropagation();onOpenChange(false);}if(event.key==='Enter')event.currentTarget.blur();}}/><Button label={open?'收起搜索':'搜索音乐'} icon={open?'close':wall?'wallSearch':'search'} aria-expanded={open} onClick={()=>{if(open){pending.current="";setDraft("");onValueChange("");}onOpenChange(!open);}}/></div>;
}
