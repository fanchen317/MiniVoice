import {useEffect,useRef} from 'react';
import {sheetDragDismiss} from './sheetDragModel.js';
const reduced=()=>matchMedia('(prefers-reduced-motion:reduce)').matches||document.documentElement.classList.contains('reduce-motion');
/** The handle owns this gesture; content scrolling never enters this hook. */
export function useSheetDrag(panel,onClose,resetKey){
 const gesture=useRef(null),animation=useRef(null),frame=useRef(0),latest=useRef(onClose),suppress=useRef(false);
 latest.current=onClose;
 function settle(){
  const node=panel.current;if(!node)return;
  const style=getComputedStyle(node),from={translate:style.translate,transform:style.transform,opacity:style.opacity};
  animation.current?.cancel();node.style.translate='';node.style.transform='';node.style.opacity='';delete node.dataset.sheetDragging;
  if(!reduced())animation.current=node.animate([from,{translate:'0px 0px',transform:'none',opacity:1}],{duration:240,easing:'cubic-bezier(.2,.8,.2,1)'});
 }
 function release(state){try{if(state?.handle.hasPointerCapture(state.id))state.handle.releasePointerCapture(state.id);}catch{}}
 function cancel(){const state=gesture.current;if(!state)return;gesture.current=null;release(state);cancelAnimationFrame(frame.current);frame.current=0;settle();}
 useEffect(()=>{const abort=()=>{if(gesture.current){suppress.current=true;cancel();}};window.addEventListener('pointermove',move,true);window.addEventListener('pointerup',up,true);window.addEventListener('pointercancel',abort,true);window.addEventListener('blur',cancel);window.addEventListener('resize',cancel);return()=>{window.removeEventListener('pointermove',move,true);window.removeEventListener('pointerup',up,true);window.removeEventListener('pointercancel',abort,true);window.removeEventListener('blur',cancel);window.removeEventListener('resize',cancel);cancelAnimationFrame(frame.current);animation.current?.cancel();const state=gesture.current;gesture.current=null;release(state);const node=panel.current;if(node){node.style.translate='';node.style.transform='';node.style.opacity='';delete node.dataset.sheetDragging;}};},[resetKey]);
 function down(event){
  if(event.button!==0||gesture.current)return;
  const node=panel.current,style=getComputedStyle(node),start=parseFloat(style.translate.split(' ')[1])||0;
  for(const motion of node.getAnimations()){try{motion.commitStyles();}catch{}motion.cancel();}
  animation.current=null;suppress.current=false;event.preventDefault();event.currentTarget.setPointerCapture(event.pointerId);
  gesture.current={id:event.pointerId,start:event.clientY-start,lastY:event.clientY,lastTime:performance.now(),distance:start,velocity:0,handle:event.currentTarget};node.dataset.sheetDragging='true';
 }
 function move(event){
  const state=gesture.current;if(!state||event.pointerId!==state.id)return;
  const now=performance.now();state.velocity=(event.clientY-state.lastY)/Math.max(8,now-state.lastTime);state.lastY=event.clientY;state.lastTime=now;
  state.distance=Math.max(0,event.clientY-state.start);if(state.distance>6)suppress.current=true;
  if(!frame.current)frame.current=requestAnimationFrame(()=>{frame.current=0;if(gesture.current&&panel.current)panel.current.style.translate=`0px ${gesture.current.distance}px`;});
 }
 function up(event){
  const state=gesture.current;if(!state||state.id!==event.pointerId)return;
  event.preventDefault();event.stopPropagation();
  cancelAnimationFrame(frame.current);frame.current=0;
  const node=panel.current;node.style.translate=`0px ${state.distance}px`;
  const velocity=performance.now()-state.lastTime<100?state.velocity:0,dismiss=sheetDragDismiss(state.distance,velocity,node.offsetHeight);
  gesture.current=null;release(state);delete node.dataset.sheetDragging;
  if(dismiss){suppress.current=true;latest.current?.();requestAnimationFrame(()=>{if(node.isConnected)settle();});}else settle();
 }
 return {onPointerDown:down,onLostPointerCapture:()=>{if(gesture.current){suppress.current=true;cancel();}},onClick:event=>{event.stopPropagation();if(suppress.current&&event.detail!==0){event.preventDefault();suppress.current=false;return;}suppress.current=false;latest.current?.();}};
}
