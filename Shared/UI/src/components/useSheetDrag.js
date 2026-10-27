import {useEffect,useRef} from 'react';
import {sheetDragDismiss} from './sheetDragModel.js';
const reduced=()=>matchMedia('(prefers-reduced-motion:reduce)').matches||document.documentElement.classList.contains('reduce-motion');
/** The handle owns this gesture; content scrolling never enters this hook. */
export function useSheetDrag(panel,onClose,resetKey,options={}){
 const gesture=useRef(null),animation=useRef(null),frame=useRef(0),latest=useRef(onClose),suppress=useRef(false);
 const config=useRef(options);config.current=options;
 latest.current=onClose;
 function settle(){
  const node=panel.current;if(!node)return;
  const style=getComputedStyle(node),from={translate:style.translate,transform:style.transform,opacity:style.opacity};
  animation.current?.cancel();node.style.translate='';node.style.transform='';node.style.opacity='';node.style.height='';node.style.maxHeight='';delete node.dataset.sheetDragging;
  if(!reduced()&&!config.current.expandable)animation.current=node.animate([from,{translate:'0px 0px',transform:'none',opacity:1}],{duration:240,easing:'cubic-bezier(.2,.8,.2,1)'});
 }
 function release(state){try{if(state?.handle.hasPointerCapture(state.id))state.handle.releasePointerCapture(state.id);}catch{}}
 function cancel(){const state=gesture.current;if(!state)return;gesture.current=null;release(state);cancelAnimationFrame(frame.current);frame.current=0;settle();}
 useEffect(()=>{const abort=()=>{if(gesture.current){suppress.current=true;cancel();}};window.addEventListener('pointermove',move,true);window.addEventListener('pointerup',up,true);window.addEventListener('pointercancel',abort,true);window.addEventListener('blur',cancel);window.addEventListener('resize',cancel);return()=>{window.removeEventListener('pointermove',move,true);window.removeEventListener('pointerup',up,true);window.removeEventListener('pointercancel',abort,true);window.removeEventListener('blur',cancel);window.removeEventListener('resize',cancel);cancelAnimationFrame(frame.current);animation.current?.cancel();const state=gesture.current;gesture.current=null;release(state);const node=panel.current;if(node){node.style.translate='';node.style.transform='';node.style.opacity='';node.style.height='';node.style.maxHeight='';delete node.dataset.sheetDragging;}};},[resetKey]);
 function down(event){
  if(event.button!==0||gesture.current)return;
  const node=panel.current,style=getComputedStyle(node),start=parseFloat(style.translate.split(' ')[1])||0;
  for(const motion of node.getAnimations()){try{motion.commitStyles();}catch{}motion.cancel();}
  animation.current=null;suppress.current=false;event.preventDefault();event.currentTarget.setPointerCapture(event.pointerId);
  gesture.current={id:event.pointerId,start:event.clientY-start,lastY:event.clientY,lastTime:performance.now(),distance:start,velocity:0,handle:event.currentTarget,height:node.offsetHeight,maxHeight:node.parentElement.clientHeight-parseFloat(getComputedStyle(node.parentElement).paddingTop)-parseFloat(getComputedStyle(node.parentElement).paddingBottom)};node.dataset.sheetDragging='true';
 }
 function move(event){
  const state=gesture.current;if(!state||event.pointerId!==state.id)return;
  const now=performance.now();state.velocity=(event.clientY-state.lastY)/Math.max(8,now-state.lastTime);state.lastY=event.clientY;state.lastTime=now;
  state.distance=config.current.expandable?event.clientY-state.start:Math.max(0,event.clientY-state.start);if(Math.abs(state.distance)>6)suppress.current=true;
  if(!frame.current)frame.current=requestAnimationFrame(()=>{frame.current=0;if(gesture.current&&panel.current){const g=gesture.current,node=panel.current;if(config.current.expandable&&(g.distance<0||config.current.expanded)){node.style.maxHeight='100%';node.style.height=`${Math.max(160,Math.min(g.maxHeight,g.height-g.distance))}px`;node.style.translate='0px 0px';}else node.style.translate=`0px ${g.distance}px`;}});
 }
 function up(event){
  const state=gesture.current;if(!state||state.id!==event.pointerId)return;
  event.preventDefault();event.stopPropagation();
  cancelAnimationFrame(frame.current);frame.current=0;
  const node=panel.current;node.style.translate=`0px ${config.current.expandable&&(state.distance<0||config.current.expanded)?0:state.distance}px`;
  const velocity=performance.now()-state.lastTime<100?state.velocity:0,dismiss=sheetDragDismiss(state.distance,velocity,node.offsetHeight);
  gesture.current=null;release(state);delete node.dataset.sheetDragging;
  if(config.current.expandable&&(state.distance<-24||config.current.expanded&&state.distance>24)){suppress.current=true;config.current.onExpandedChange?.(state.distance<0);settle();return;}
  if(dismiss){suppress.current=true;latest.current?.();requestAnimationFrame(()=>{if(node.isConnected)settle();});}else settle();
 }
 return {onPointerDown:down,onLostPointerCapture:()=>{if(gesture.current){suppress.current=true;cancel();}},onClick:event=>{event.stopPropagation();if(suppress.current&&event.detail!==0){event.preventDefault();suppress.current=false;return;}suppress.current=false;if(config.current.expandable)config.current.onExpandedChange?.(!config.current.expanded);else latest.current?.();}};
}
