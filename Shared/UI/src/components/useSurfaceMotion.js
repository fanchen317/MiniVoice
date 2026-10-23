import {useLayoutEffect} from 'react';

const reduced=()=>document.documentElement.classList.contains('reduce-motion')||matchMedia('(prefers-reduced-motion: reduce)').matches;
const closing=new Set();
function snapshot(node){
  const style=getComputedStyle(node);return {rect:node.getBoundingClientRect(),opacity:style.opacity,variables:Object.fromEntries(['--bg','--text','--muted','--line','--border','--accent','--selected','--glass','--glass-line','--surface','--panel','--mint'].map(name=>[name,style.getPropertyValue(name)]))};
}
function exitSurface(node,modal,last){
  if(reduced()||!node)return;
  const sample=node.isConnected?snapshot(node):last,rect=sample?.rect;if(!rect)return;if(!rect.width||!rect.height)return;
  const ghost=node.cloneNode(true);
  ghost.dataset.surfaceExit=modal?'modal':'popover';ghost.setAttribute('aria-hidden','true');ghost.inert=true;
  for(const el of [ghost,...ghost.querySelectorAll('[role],[aria-modal],[id]')]){el.removeAttribute('role');el.removeAttribute('aria-modal');el.removeAttribute('id');}
  for(const [name,value] of Object.entries(sample.variables))ghost.style.setProperty(name,value);
  Object.assign(ghost.style,{position:'fixed',left:`${rect.left}px`,top:`${rect.top}px`,width:`${rect.width}px`,height:`${rect.height}px`,right:'auto',bottom:'auto',margin:'0',pointerEvents:'none',animation:'none',transform:'none',zIndex:modal?'1499':'1199'});
  ghost.classList.add('glass-in-motion');document.body.append(ghost);closing.add(ghost);
  const fade=ghost.animate([{opacity:Number(sample.opacity)||1},{opacity:0}],{duration:140,easing:'ease-out',fill:'forwards'});
  if(modal)ghost.querySelector('.name-dialog,.mv-modal')?.animate([{transform:'none'},{transform:'translateY(6px) scale(.985)'}],{duration:140,easing:'ease-out',fill:'forwards'});
  const remove=()=>{ghost.remove();closing.delete(ghost);clearTimeout(timeout);};
  const timeout=setTimeout(remove,240);fade.finished.catch(()=>{}).finally(remove);
}
// Geometry stays at its final position. Only the rendered surface approaches
// its anchor, so opening never feeds scaled dimensions into ResizeObserver.
export function useSurfaceMotion(ref,open,{modal=false,easing='cubic-bezier(.2,.8,.2,1)'}={}){
  useLayoutEffect(()=>{
    const node=ref.current;if(!open||!node)return;
    if(modal)for(const ghost of closing)if(ghost.dataset.surfaceExit==='modal'){ghost.remove();closing.delete(ghost);}
    const target=modal?node.querySelector('.name-dialog,.mv-modal'):node;
    let animation,fade,last=snapshot(node);
    const sample=()=>{if(node.isConnected)last=snapshot(node);};
    const frame=requestAnimationFrame(sample),observer=new ResizeObserver(sample);observer.observe(node);
    window.addEventListener('resize',sample);
    if(!reduced()){
      const travel=Math.min(10,Math.max(3,target.offsetHeight*.025)),origin=getComputedStyle(target).getPropertyValue('--surface-origin-y'),originY=origin.endsWith('%')?target.offsetHeight*parseFloat(origin)/100:parseFloat(origin)||0,shift=modal||originY>=target.offsetHeight/2?travel:-travel;
      animation=target.animate([{opacity:0,transform:`translateY(${shift}px) scale(.975)`},{opacity:1,transform:'none'}],{duration:260,easing});
      if(modal)fade=node.animate([{opacity:0},{opacity:1}],{duration:180,easing:'ease-out'});
    }
    animation?.finished.then(sample).catch(()=>{});
    const finish=()=>{animation?.finish();fade?.finish();};
    const media=matchMedia('(prefers-reduced-motion: reduce)');media.addEventListener('change',finish);
    return()=>{cancelAnimationFrame(frame);observer.disconnect();window.removeEventListener('resize',sample);animation?.cancel();fade?.cancel();media.removeEventListener('change',finish);exitSurface(node,modal,last);};
  },[ref,open,modal,easing]);
}
