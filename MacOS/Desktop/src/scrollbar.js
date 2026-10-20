import {useEffect} from 'react';

// The native PlayerScrollThumb appears during a scroll session, then fades
// after 1.4 seconds. Keep this bookkeeping out of React's scrolling hot path.
export function useScrollThumb(root){
  useEffect(()=>{
    const node=root.current;if(!node)return;
    let timer,held=false,overThumb=false;
    const schedule=()=>{clearTimeout(timer);if(!held&&!overThumb)timer=setTimeout(()=>node.classList.remove('scroll-thumb-visible'),1400);};
    const reveal=()=>{node.classList.add('scroll-thumb-visible');schedule();};
    const move=event=>{const rect=node.getBoundingClientRect();overThumb=event.clientX>rect.right-24&&node.classList.contains('scroll-thumb-visible');schedule();};
    const leave=()=>{overThumb=false;schedule();};
    const down=event=>{const rect=node.getBoundingClientRect();held=event.clientX>rect.right-24;if(held)reveal();};
    const up=()=>{held=false;schedule();};
    node.addEventListener('scroll',reveal,{passive:true});node.addEventListener('pointermove',move,{passive:true});node.addEventListener('pointerleave',leave);node.addEventListener('pointerdown',down);window.addEventListener('pointerup',up);
    return()=>{clearTimeout(timer);node.removeEventListener('scroll',reveal);node.removeEventListener('pointermove',move);node.removeEventListener('pointerleave',leave);node.removeEventListener('pointerdown',down);window.removeEventListener('pointerup',up);};
  },[root]);
}
