import {useEffect,useRef} from 'react';
/** Gesture ownership shared by touch list items. Small jitter is not a scroll. */
export function useLongPress(onOpen,{delay=500,tolerance=8}={}){
 const open=useRef(onOpen),pending=useRef(null),timer=useRef(null),suppress=useRef(false),opened=useRef(0);open.current=onOpen;
 const cancel=()=>{clearTimeout(timer.current);pending.current=null;};
 useEffect(()=>{const blur=()=>cancel();window.addEventListener('blur',blur);return()=>{cancel();window.removeEventListener('blur',blur);};},[]);
 return {
  onPointerDown(event,item){if(event.button!==0||!open.current||event.target.closest('button,input,[role=slider],[role=scrollbar]'))return;cancel();suppress.current=false;pending.current={id:event.pointerId,x:event.clientX,y:event.clientY,item};timer.current=setTimeout(()=>{const value=pending.current;if(!value)return;suppress.current=true;opened.current=Date.now();pending.current=null;open.current?.(value.item);},delay);},
  onPointerMove(event){const value=pending.current;if(value&&(event.pointerId!==value.id||Math.hypot(event.clientX-value.x,event.clientY-value.y)>tolerance))cancel();},
  onPointerUp:cancel,onPointerCancel:cancel,onScroll:cancel,
  onContextMenu(event,item){if(!open.current)return;event.preventDefault();cancel();if(Date.now()-opened.current<250)return;suppress.current=true;opened.current=Date.now();open.current(item);},
  consumeClick(){if(!suppress.current)return false;suppress.current=false;return true;}
 };
}
