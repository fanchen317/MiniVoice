import {useSurfaceMotion} from './surfaceMotion';
import {useLayoutEffect,useState} from 'react';
import {popoverPosition} from './popoverPosition';
export function usePopoverPosition(anchor,panel,open,{above=false,align='start'}={}){
  const [position,setPosition]=useState({left:8,top:8});
  useLayoutEffect(()=>{
    if(!open)return;
    const place=()=>{
      if(!anchor.current||!panel.current)return;
      const anchorRect=anchor.current.getBoundingClientRect();
      const next=popoverPosition(anchorRect,{width:panel.current.offsetWidth,height:panel.current.offsetHeight},{width:innerWidth,height:innerHeight},{above,align});
      panel.current.style.setProperty('--surface-origin-x',`${Math.max(0,Math.min(panel.current.offsetWidth,anchorRect.left+anchorRect.width/2-next.left))}px`);
      panel.current.style.setProperty('--surface-origin-y',`${Math.max(0,Math.min(panel.current.offsetHeight,anchorRect.top+anchorRect.height/2-next.top))}px`);
      setPosition(previous=>previous.left===next.left&&previous.top===next.top?previous:next);
    };
    let frame=0,until=0;
    const follow=()=>{until=performance.now()+700;if(frame)return;const tick=()=>{place();if(performance.now()<until)frame=requestAnimationFrame(tick);else frame=0;};frame=requestAnimationFrame(tick);};
    const transition=event=>{if(event.target instanceof Element&&event.target.contains(anchor.current))follow();};
    const mutations=new MutationObserver(follow);const app=document.querySelector('.app');if(app)mutations.observe(app,{attributes:true,attributeFilter:['class']});
    place();const observer=new ResizeObserver(place);observer.observe(panel.current);observer.observe(anchor.current);
    window.addEventListener('resize',follow);window.addEventListener('transitionrun',transition,true);window.addEventListener('scroll',place,true);
    return()=>{observer.disconnect();mutations.disconnect();cancelAnimationFrame(frame);window.removeEventListener('resize',follow);window.removeEventListener('transitionrun',transition,true);window.removeEventListener('scroll',place,true);};
  },[open,above,align,anchor,panel]);
  useSurfaceMotion(panel,open);
  return position;
}
