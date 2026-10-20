import {useLayoutEffect,useRef} from 'react';

const fields=['left','top','width','height','opacity','fontSize','lineHeight'];
const selectors='.row-cover,.row-title,.row-artist,.row-album,.row-duration,.row-favorite,.row-edit,.selection-circle';
const sample=node=>{const style=getComputedStyle(node);return Object.fromEntries(fields.map(key=>[key,style[key]]));};
// Resize follows the pointer directly until a column changes arrangement.
// Crossing a breakpoint starts one 220ms transition; continued dragging and
// reversals sample the visible frame and retain that transition's deadline.
export function useListColumnMotion(root,columns,enabled,rangeKey){
  const previous=useRef(new Map()),mode=useRef(),running=useRef(new Map()),deadline=useRef(0);
  const key=`${columns.compact}:${columns.album}:${columns.duration}:${columns.edit}:${columns.artwork.x}`;
  useLayoutEffect(()=>{
    if(!enabled||!root.current)return;
    const now=performance.now(),changed=mode.current!==undefined&&mode.current!==key,reduced=document.documentElement.classList.contains('reduce-motion')||matchMedia('(prefers-reduced-motion: reduce)').matches;
    const compactChanged=mode.current!==undefined&&mode.current.split(':')[0]!==String(columns.compact);
    mode.current=key;
    if(changed&&deadline.current<=now)deadline.current=now+220;
    const animate=!reduced&&deadline.current>now,next=new Map();
    for(const node of root.current.querySelectorAll(selectors)){
      const animation=running.current.get(node),from=animation?sample(node):previous.current.get(node);
      animation?.cancel();running.current.delete(node);
      const to=sample(node);next.set(node,to);
      if(!animate||!from||fields.every(field=>from[field]===to[field]))continue;
      // Briefly fade the artist at the crossing so it cannot overprint the
      // title while moving between the same row and the second line.
      const frames=compactChanged&&node.classList.contains('row-artist')?[from,{opacity:0,offset:.4},{opacity:0,offset:.6},to]:[from,to];
      const motion=node.animate(frames,{duration:Math.max(1,deadline.current-now),easing:changed?'ease-in-out':'linear'});
      running.current.set(node,motion);
      motion.finished.catch(()=>{}).finally(()=>{if(running.current.get(node)===motion)running.current.delete(node);});
    }
    for(const [node,animation] of running.current)if(!next.has(node)){animation.cancel();running.current.delete(node);}
    previous.current=next;
  },[columns,enabled,key,root,rangeKey]);
  useLayoutEffect(()=>()=>{for(const animation of running.current.values())animation.cancel();running.current.clear();},[]);
}
