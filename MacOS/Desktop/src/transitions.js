import { flushSync } from 'react-dom';
import { fragmentCells, fragmentProgress, springEasing } from './motion';

export const reducedMotion=()=>document.documentElement.classList.contains('reduce-motion');
const active=new WeakMap();
// FLIP records the current visual rectangle before cancelling an interrupted
// transition. Layout happens once, then Chromium interpolates only transforms.
export function layoutTransition(update,selectors,duration=360,easing='ease-in-out'){
  if(reducedMotion()){flushSync(update);return;}
  const previous=[...document.querySelectorAll(selectors)].map(node=>[node,node.getBoundingClientRect()]);
  flushSync(update);
  for(const [node,from] of previous){
    active.get(node)?.cancel();
    if(!node.isConnected)continue;
    const to=node.getBoundingClientRect();
    if(!from.width||!from.height||!to.width||!to.height)continue;
    const dx=from.x-to.x,dy=from.y-to.y,sx=from.width/to.width,sy=from.height/to.height;
    if(Math.abs(dx)+Math.abs(dy)+Math.abs(sx-1)+Math.abs(sy-1)<.01)continue;
    const animation=node.animate([{transform:`translate(${dx}px,${dy}px) scale(${sx},${sy})`},{transform:'none'}],{duration,easing,transformOrigin:'0 0'});
    node.style.transformOrigin='0 0';active.set(node,animation);
    animation.finished.catch(()=>{}).finally(()=>{if(active.get(node)===animation){active.delete(node);node.style.transformOrigin='';}});
  }
}
export function springLayout(update,selectors,response=.46,damping=.9){layoutTransition(update,selectors,600,springEasing(response,damping));}

let sweeping=false,queued=null;
export async function styleTransition(update){
  if(sweeping){queued=queued?null:update;return;}
  if(reducedMotion()){flushSync(update);return;}
  sweeping=true;
  const icon=document.querySelector('.brand-logo')?.getBoundingClientRect();
  const origin=icon?{x:icon.x+icon.width/2,y:icon.y+icon.height/2}:{x:36,y:60};
  let canvas,frame=0;
  try{
    // Captures only this application's own content. No screen-recording access.
    const snapshot=await Promise.race([window.miniVoice.command('captureStyle'),new Promise(resolve=>setTimeout(()=>resolve(null),350))]);
    if(snapshot){
      const bitmap=new Image();bitmap.src=snapshot;await bitmap.decode();
      canvas=document.createElement('canvas');canvas.className='style-fragment-sweep';canvas.setAttribute('aria-hidden','true');
      const width=innerWidth,height=innerHeight,scale=Math.min(1,1000/width);
      canvas.width=Math.ceil(width*scale);canvas.height=Math.ceil(height*scale);canvas.style.width=`${width}px`;canvas.style.height=`${height}px`;
      const context=canvas.getContext('2d'),cells=fragmentCells(width,height),began=performance.now();
      document.body.append(canvas);
      const paint=now=>{
        context.setTransform(scale,0,0,scale,0,0);context.clearRect(0,0,width,height);
        cells.forEach((cell,index)=>{
          const center={x:cell.x+cell.width/2,y:cell.y+cell.height/2};
          const p=fragmentProgress(now-began,center,origin,{width,height});if(p>=1)return;
          const eased=p*p*(3-2*p),angle=Math.atan2(center.y-origin.y,center.x-origin.x),curl=Math.sin(p*Math.PI)*(index%7-3)*6,distance=eased*140;
          context.save();context.globalAlpha=1-eased;
          context.translate(center.x+Math.cos(angle)*distance-Math.sin(angle)*curl,center.y+Math.sin(angle)*distance+Math.cos(angle)*curl);
          context.rotate((index%9-4)*eased*8*Math.PI/180);context.scale(1-eased*.65,1-eased*.65);
          context.drawImage(bitmap,cell.x/width*bitmap.width,cell.y/height*bitmap.height,cell.width/width*bitmap.width,cell.height/height*bitmap.height,-cell.width/2,-cell.height/2,cell.width,cell.height);context.restore();
        });
        if(now-began<680)frame=requestAnimationFrame(paint);
      };
      paint(began);flushSync(update);
      await new Promise(resolve=>setTimeout(resolve,690));
    }else flushSync(update);
  }catch{flushSync(update);}
  finally{cancelAnimationFrame(frame);canvas?.remove();sweeping=false;const next=queued;queued=null;if(next)requestAnimationFrame(()=>styleTransition(next));}
}
export function fadeHeroOut(){
  if(reducedMotion())return;
  const source=document.querySelector('.simple-hero');if(!source)return;
  const rect=source.getBoundingClientRect(),ghost=document.createElement('div');
  ghost.className='style-simple transition-ghost';ghost.setAttribute('aria-hidden','true');ghost.inert=true;
  Object.assign(ghost.style,{position:'fixed',left:`${rect.x}px`,top:`${rect.y}px`,width:`${rect.width}px`,height:`${rect.height}px`,zIndex:'40',pointerEvents:'none',transformOrigin:'top left'});
  ghost.append(source.cloneNode(true));document.body.append(ghost);
  ghost.animate([{opacity:1,transform:'scale(1)'},{opacity:0,transform:'scale(.94)'}],{duration:600,easing:springEasing(.46,.9)}).finished.catch(()=>{}).finally(()=>ghost.remove());
}

// Same 20ms departure, 450ms easeInOut flight and 120ms landing fade as
// PlaybackArtworkFlight. Animate an independent cover, leaving list geometry alone.
export function flyPlaybackArtwork(source){
  if(!source||reducedMotion())return;
  const target=document.querySelector('.player:not(.compact) .mini-cover');if(!target)return;
  const from=source.getBoundingClientRect(),to=target.getBoundingClientRect(),ghost=source.cloneNode(true);
  ghost.querySelectorAll('.now-playing-indicator').forEach(node=>node.remove());
  ghost.className='playback-artwork-flight';ghost.setAttribute('aria-hidden','true');
  Object.assign(ghost.style,{position:'fixed',left:`${from.x}px`,top:`${from.y}px`,width:`${from.width}px`,height:`${from.height}px`,zIndex:80,pointerEvents:'none',overflow:'hidden',borderRadius:'8px',boxShadow:'0 4px 8px #0003'});
  document.body.append(ghost);
  const motion=ghost.animate([{transform:'none'},{transform:`translate(${to.x-from.x}px,${to.y-from.y}px) scale(${to.width/from.width},${to.height/from.height})`}],{duration:450,delay:20,easing:'ease-in-out',fill:'forwards'});
  motion.finished.then(()=>ghost.animate([{opacity:1},{opacity:0}],{duration:120,easing:'ease-out',fill:'forwards'}).finished).catch(()=>{}).finally(()=>ghost.remove());
  ghost.style.transformOrigin='top left';
}
