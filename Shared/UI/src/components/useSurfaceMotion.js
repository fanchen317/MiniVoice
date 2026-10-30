import {useLayoutEffect} from 'react';

const reduced=()=>document.documentElement.classList.contains('reduce-motion')||matchMedia('(prefers-reduced-motion: reduce)').matches;
const closing=new Set();
function snapshot(node){
  const style=getComputedStyle(node);return {rect:node.getBoundingClientRect(),opacity:style.opacity,zIndex:style.zIndex,variables:Object.fromEntries(['--bg','--text','--muted','--line','--border','--accent','--selected','--glass','--glass-line','--surface','--panel','--mint','--mv-safe-left','--mv-safe-right','--mv-safe-top','--mv-safe-bottom'].map(name=>[name,style.getPropertyValue(name)]))};
}
function exitSurface(node,modal,last,surface){
  if(reduced()||!node)return;
  const sample=node.isConnected?snapshot(node):last,rect=sample?.rect;if(!rect)return;if(!rect.width||!rect.height)return;
  const ghost=node.cloneNode(true);
  ghost.dataset.surfaceExit=surface;ghost.setAttribute('aria-hidden','true');ghost.inert=true;
  for(const el of [ghost,...ghost.querySelectorAll('[role],[aria-modal],[id]')]){el.removeAttribute('role');el.removeAttribute('aria-modal');el.removeAttribute('id');}
  const workspace=node.closest('.mv-workspace');if(workspace?.dataset.presentation)ghost.dataset.presentation=workspace.dataset.presentation;if(workspace)for(const token of workspace.classList)if(token.startsWith('theme-')||token.startsWith('style-'))ghost.classList.add(token);
  if(workspace?.dataset.presentation==='mobile'){ghost.classList.add('mv-workspace');ghost.style.flexDirection='row';ghost.style.gap='0';}
  for(const [name,value] of Object.entries(sample.variables))ghost.style.setProperty(name,value);
  Object.assign(ghost.style,{position:'fixed',left:`${rect.left}px`,top:`${rect.top}px`,width:`${rect.width}px`,height:`${rect.height}px`,right:'auto',bottom:'auto',margin:'0',pointerEvents:'none',animation:'none',transform:'none',zIndex:sample.zIndex==='auto'?'70':sample.zIndex});
  // Pin the exit panel to its measured opening layout. The detached portal
  // no longer inherits every ancestor selector, so recomputing flex/padding
  // here would move its origin (especially with phone cutout insets).
  const panelSelector=surface==='drawer'?'.mv-drawer':'.name-dialog,.mv-modal',sourcePanel=node.querySelector(panelSelector),exitPanel=ghost.querySelector(panelSelector);
  if(sourcePanel&&exitPanel){const bounds=sourcePanel.getBoundingClientRect(),matrix=new DOMMatrixReadOnly(getComputedStyle(sourcePanel).transform);Object.assign(exitPanel.style,{position:'absolute',left:`${bounds.left-rect.left-matrix.m41}px`,top:`${bounds.top-rect.top-matrix.m42}px`,width:`${bounds.width}px`,height:`${bounds.height}px`,maxWidth:'none',maxHeight:'none',margin:'0',boxSizing:'border-box'});}
  ghost.classList.add('glass-in-motion');document.body.append(ghost);closing.add(ghost);
  const fade=ghost.animate([{opacity:Number.isFinite(Number(sample.opacity))?Number(sample.opacity):1},{opacity:0}],{duration:surface==='drawer'?280:180,easing:'ease-out',fill:'forwards'});
  const selector=surface==='drawer'?'.mv-drawer':'.name-dialog,.mv-modal',target=ghost.querySelector(selector),original=node.querySelector(selector);
  if(target){const style=original&&node.isConnected?getComputedStyle(original):null,from=style?.transform||'none';target.animate([{transform:from,opacity:style?.opacity||1},{opacity:0,transform:surface==='drawer'?`translateX(-${target.getBoundingClientRect().right+16}px)`:'translateY(8px) scale(.985)'}],{duration:surface==='drawer'?280:180,easing:'cubic-bezier(.4,0,1,1)',fill:'forwards'});}
  const remove=()=>{ghost.remove();closing.delete(ghost);clearTimeout(timeout);};
  const timeout=setTimeout(remove,surface==='drawer'?360:240);fade.finished.catch(()=>{}).finally(remove);
}
// Geometry stays at its final position. Only the rendered surface approaches
// its anchor, so opening never feeds scaled dimensions into ResizeObserver.
export function useSurfaceMotion(ref,open,{modal=false,surface=modal?'modal':'popover',easing='cubic-bezier(.2,.8,.2,1)'}={}){
  useLayoutEffect(()=>{
    const node=ref.current;if(!open||!node)return;
    let interrupted=null;
    for(const ghost of closing)if(ghost.dataset.surfaceExit===surface){if(surface==='drawer'&&node.closest('[data-presentation=mobile]')){const panel=ghost.querySelector('.mv-drawer');if(panel){const style=getComputedStyle(panel);interrupted={transform:style.transform,opacity:style.opacity};}}ghost.remove();closing.delete(ghost);}
    const target=surface==='drawer'?node.querySelector('.mv-drawer'):modal?node.querySelector('.name-dialog,.mv-modal'):node;
    const mobileDrawer=surface==='drawer'&&node.closest('[data-presentation=mobile]');
    const mobileModal=modal&&node.closest('[data-presentation=mobile]');
    let animation,fade,last=snapshot(node);
    const sample=()=>{if(node.isConnected)last=snapshot(node);};
    const frame=requestAnimationFrame(sample),observer=new ResizeObserver(sample);observer.observe(node);
    window.addEventListener('resize',sample);
    if(!reduced()){
      const travel=Math.min(10,Math.max(3,target.offsetHeight*.025)),origin=getComputedStyle(target).getPropertyValue('--surface-origin-y'),originY=origin.endsWith('%')?target.offsetHeight*parseFloat(origin)/100:parseFloat(origin)||0,shift=modal||originY>=target.offsetHeight/2?travel:-travel;
      animation=target.animate([{opacity:interrupted?.opacity??(mobileDrawer||mobileModal?1:0),transform:interrupted?.transform??(surface==='drawer'?`translateX(-${target.getBoundingClientRect().right+16}px)`:`translateY(${shift}px) scale(.975)`)},{opacity:1,transform:'none'}],{duration:surface==='drawer'?360:260,easing});
      if(modal&&!mobileModal||surface==='drawer'&&!mobileDrawer)fade=node.animate([{opacity:0},{opacity:1}],{duration:180,easing:'ease-out'});
    }
    animation?.finished.then(sample).catch(()=>{});
    const finish=()=>{animation?.finish();fade?.finish();};
    const media=matchMedia('(prefers-reduced-motion: reduce)');media.addEventListener('change',finish);
    const preferences=new MutationObserver(()=>{if(reduced())finish();});preferences.observe(document.documentElement,{attributes:true,attributeFilter:['class']});
    return()=>{preferences.disconnect();cancelAnimationFrame(frame);observer.disconnect();window.removeEventListener('resize',sample);exitSurface(node,modal,last,surface);animation?.cancel();fade?.cancel();media.removeEventListener('change',finish);};
  },[ref,open,modal,surface,easing]);
}
