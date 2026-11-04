import {createWallSearchMotion} from './searchMotion.js';
import React,{useLayoutEffect,useEffect,useRef,useState} from 'react';
import {Button,Icon} from './PlayerControls.jsx';
export default function SearchControl({open,onOpenChange,value,onValueChange,wall=false}){
 const input=useRef(null),root=useRef(null),pending=useRef(null),[draft,setDraft]=useState(value);
 const [phase,setPhase]=useState(open?'expanded':'closed'),motion=useRef(null);if(!motion.current)motion.current=createWallSearchMotion(setPhase,{reduced:()=>document.documentElement.classList.contains('reduce-motion')||matchMedia('(prefers-reduced-motion:reduce)').matches});
 useEffect(()=>{if(open)motion.current.open();else motion.current.close();},[open]);useEffect(()=>()=>motion.current.dispose(),[]);
 // Editing stays synchronous while the host persists controlled queries asynchronously.
 useEffect(()=>{if(!open||pending.current===null||value===pending.current){pending.current=null;setDraft(value);}},[value,open]);
 // Hide only toolbar actions actually covered by the animated search surface.
 useLayoutEffect(()=>{
  const search=root.current,toolbar=search?.parentElement;
  if(!toolbar?.closest('[data-presentation=mobile]'))return;
  const actions=[...toolbar.children].filter(node=>node!==search&&node.matches('.mv-button,.mv-back'));
  const measure=()=>{
   const box=toolbar.getBoundingClientRect(),visualWidth=Math.min(toolbar.clientWidth,innerWidth>innerHeight?440:toolbar.clientWidth),left=box.right-visualWidth;
   const coverage=actions.map(action=>{const rect=action.getBoundingClientRect();return open&&left<rect.right&&box.right>rect.left;});
   const sample=`${toolbar.clientWidth}px`,target=`${visualWidth/1.16}px`;
   if(search.style.getPropertyValue('--search-expanded-width')!==sample)search.style.setProperty('--search-expanded-width',sample);
   if(search.style.getPropertyValue('--search-target-width')!==target)search.style.setProperty('--search-target-width',target);
   actions.forEach((action,index)=>{const covered=coverage[index];if(action.dataset.searchOccluded!==String(covered))action.dataset.searchOccluded=String(covered);if(action.inert!==covered)action.inert=covered;});
  };
  const observer=new ResizeObserver(measure);observer.observe(toolbar);measure();
  globalThis.addEventListener('minivoice-insets',measure);
  return()=>{observer.disconnect();globalThis.removeEventListener('minivoice-insets',measure);actions.forEach(action=>{delete action.dataset.searchOccluded;action.inert=false;});};
 },[open]);
 useEffect(()=>{if(!open){input.current?.blur();return;}if(phase!=='expanded')return;const reduced=document.documentElement.classList.contains('reduce-motion')||matchMedia('(prefers-reduced-motion:reduce)').matches;const timer=setTimeout(()=>input.current?.focus({preventScroll:true}),reduced?0:360);return()=>clearTimeout(timer);},[open,phase]);
 useEffect(()=>{if(!open||draft)return;const outside=event=>{if(!root.current?.contains(event.target))onOpenChange(false);};document.addEventListener('pointerdown',outside,true);return()=>document.removeEventListener('pointerdown',outside,true);},[open,draft,onOpenChange]);
 return <div ref={root} className="mv-search mv-search-control" data-mv-component="search-control" data-open={open&&phase==='expanded'} data-phase={phase}><span className="mv-search-leading" aria-hidden="true"><Icon name="search"/></span><input ref={input} aria-label="搜索音乐" placeholder="搜索歌曲、歌手或专辑" value={draft} onChange={event=>{const next=event.target.value;pending.current=next;setDraft(next);onValueChange(next);}} tabIndex={open?0:-1} disabled={!open} aria-hidden={!open} enterKeyHint="search" onKeyDown={event=>{if(event.key==='Escape'){event.preventDefault();event.stopPropagation();onOpenChange(false);}if(event.key==='Enter')event.currentTarget.blur();}}/><Button label={open?'收起搜索':'搜索音乐'} feedback="none" icon={wall?'wallSearch':'search'} aria-expanded={open} onClick={()=>{if(open){pending.current="";setDraft("");onValueChange("");}onOpenChange(!open);}}/></div>;
}
