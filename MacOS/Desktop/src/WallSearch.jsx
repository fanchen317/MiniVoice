import React,{useEffect,useRef,useState} from 'react';
import {Icon} from './components';
import {createWallSearchMotion} from './wallSearchMotion';
export function WallSearch({query,onQuery,hidden,reduceMotion}){
  const [phase,setPhase]=useState('closed'),hover=useRef(false),input=useRef(),focusOnOpen=useRef(false),reduced=useRef(reduceMotion),motion=useRef();
  reduced.current=reduceMotion;
  if(!motion.current)motion.current=createWallSearchMotion(setPhase,{reduced:()=>reduced.current});
  const expanded=phase==='expanded';
  useEffect(()=>()=>motion.current.dispose(),[]);
  useEffect(()=>{if(hidden){hover.current=false;focusOnOpen.current=false;motion.current.reset();}},[hidden]);
  useEffect(()=>{if(!query&&!hover.current){input.current?.blur();motion.current.close();}},[query]);
  useEffect(()=>{if(expanded&&focusOnOpen.current){focusOnOpen.current=false;input.current?.focus({preventScroll:true});}},[expanded]);
  function enter(){if(hover.current)return;hover.current=true;motion.current.open();}
  function leave(){hover.current=false;focusOnOpen.current=false;input.current?.blur();if(!query)motion.current.close();}
  return <div className={`wall-search-field ${expanded?'expanded':''}`} data-phase={phase} inert={hidden} aria-hidden={hidden} onPointerEnter={enter} onPointerLeave={leave}>
    <button aria-label="搜索音乐" aria-expanded={expanded} className="wall-search-button" onClick={()=>{focusOnOpen.current=true;if(expanded){focusOnOpen.current=false;input.current?.focus({preventScroll:true});}else motion.current.open();}}><span className="wall-search-symbol"><Icon name="wall-search"/></span></button>
    <input ref={input} aria-label="搜索音乐" placeholder="搜索音乐" value={query} onChange={event=>onQuery(event.target.value)} tabIndex={expanded?0:-1} inert={!expanded}/>
    <button className="wall-clear-search" data-empty={!query} aria-label="清除搜索" aria-hidden={!query||!expanded} disabled={!query||!expanded} tabIndex={query&&expanded?0:-1} onClick={()=>onQuery('')}><Icon name="clearCircle"/></button>
  </div>;
}
