import {useLayoutEffect,useState} from 'react';
import {popoverPosition} from './popoverPosition';
export function usePopoverPosition(anchor,panel,open,{above=false,align='start'}={}){
  const [position,setPosition]=useState({left:8,top:8});
  useLayoutEffect(()=>{
    if(!open)return;
    const place=()=>{
      if(!anchor.current||!panel.current)return;
      const next=popoverPosition(anchor.current.getBoundingClientRect(),panel.current.getBoundingClientRect(),{width:innerWidth,height:innerHeight},{above,align});
      setPosition(previous=>previous.left===next.left&&previous.top===next.top?previous:next);
    };
    place();const observer=new ResizeObserver(place);observer.observe(panel.current);observer.observe(anchor.current);
    window.addEventListener('resize',place);window.addEventListener('scroll',place,true);
    return()=>{observer.disconnect();window.removeEventListener('resize',place);window.removeEventListener('scroll',place,true);};
  },[open,above,align,anchor,panel]);
  return position;
}
