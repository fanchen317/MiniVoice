import React,{useEffect,useRef,useState} from 'react';
import {Icon} from './components';
export function WallSearch({query,onQuery,hidden,reduceMotion}){
  const [expanded,setExpanded]=useState(false),[bounce,setBounce]=useState(0),hover=useRef(false),timer=useRef(),input=useRef();
  useEffect(()=>()=>clearTimeout(timer.current),[]);
  useEffect(()=>{if(!query&&!hover.current){input.current?.blur();setExpanded(false);}},[query]);
  function enter(){if(hover.current)return;hover.current=true;clearTimeout(timer.current);if(!reduceMotion)setBounce(value=>value+1);timer.current=setTimeout(()=>setExpanded(true),reduceMotion?0:140);}
  function leave(){hover.current=false;clearTimeout(timer.current);input.current?.blur();if(!query)setExpanded(false);}
  return <div className={`wall-search-field ${expanded?'expanded':''}`} inert={hidden} aria-hidden={hidden} onPointerEnter={enter} onPointerLeave={leave}>
    <button aria-label="搜索音乐" className="wall-search-button" onClick={()=>{clearTimeout(timer.current);setExpanded(true);if(!reduceMotion)setBounce(value=>value+1);requestAnimationFrame(()=>input.current?.focus({preventScroll:true}));}}><span key={bounce} className={`wall-search-symbol ${bounce?'search-bounce':''}`}><Icon name="wall-search"/></span></button>
    <input ref={input} aria-label="搜索音乐" placeholder="搜索音乐" value={query} onChange={event=>onQuery(event.target.value)} tabIndex={expanded?0:-1} inert={!expanded}/>
    {query&&expanded&&<button className="wall-clear-search" aria-label="清除搜索" onClick={()=>onQuery('')}><Icon name="clearCircle"/></button>}
  </div>;
}
