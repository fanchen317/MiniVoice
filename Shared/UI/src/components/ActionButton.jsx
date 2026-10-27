import {useActivationFeedback,emitActivationFeedback} from './FeedbackContext.jsx';
import React,{useEffect,useRef} from 'react';
/** Shared semantics; each product family supplies its own visual skin. */
export default function ActionButton({label,children,selected,disabled=false,busy=false,type='button',className='',feedback='standard',haptic=true,onClick,onPointerDown,onPointerUp,onPointerCancel,onTouchStart,onTouchMove,onTouchEnd,onTouchCancel,...props}){
 const activate=useActivationFeedback(),motion=useRef(null),touch=useRef(null);
 useEffect(()=>()=>motion.current?.cancel(),[]);
 useEffect(()=>{if(disabled||busy)motion.current?.cancel();},[disabled,busy]);
 function spring(node){
  if(feedback!=='standard'||disabled||busy||node.closest('[data-mv-dragging=true]')||!node.closest('[data-presentation=mobile]')||document.documentElement.classList.contains('reduce-motion')||matchMedia('(prefers-reduced-motion:reduce)').matches)return;
  const style=getComputedStyle(node),peak=Number.parseFloat(style.getPropertyValue('--mv-feedback-release'))||1.045,press=Number.parseFloat(style.getPropertyValue('--mv-feedback-press'))||.96,from=Math.min(press,parseFloat(style.scale)||1);motion.current?.cancel();
  motion.current=node.animate([{scale:String(from)},{scale:String(peak),offset:.5},{scale:'.992',offset:.78},{scale:'1'}],{duration:380,easing:'cubic-bezier(.22,.9,.25,1)'});
 }

 function activateButton(event){if(disabled||busy)return;if(haptic&&(onClick||type==='submit')&&event.isTrusted&&!event.defaultPrevented)emitActivationFeedback(activate);onClick?.(event);}
 function touchEnd(event){const press=touch.current;touch.current=null;onTouchEnd?.(event);const point=[...event.changedTouches].find(p=>p.identifier===press?.id);if(!press||press.moved||!point||Math.hypot(point.clientX-press.x,point.clientY-press.y)>8||event.defaultPrevented||!event.cancelable||!event.isTrusted||disabled||busy||event.currentTarget.disabled||type!=='button'||!onClick||!event.currentTarget.closest('[data-presentation=mobile]'))return;
  const rect=event.currentTarget.getBoundingClientRect(),width=Math.max(rect.width,event.currentTarget.offsetWidth),height=Math.max(rect.height,event.currentTarget.offsetHeight),cx=rect.left+rect.width/2,cy=rect.top+rect.height/2;if(Math.abs(point.clientX-cx)>width/2||Math.abs(point.clientY-cy)>height/2)return;
  event.preventDefault();const click={...event,type:'click',detail:1,clientX:point.clientX,clientY:point.clientY,pageX:point.pageX,pageY:point.pageY,screenX:point.screenX,screenY:point.screenY,button:0,buttons:0,defaultPrevented:false,preventDefault(){this.defaultPrevented=true;},stopPropagation(){event.stopPropagation();},isDefaultPrevented(){return this.defaultPrevented;},isPropagationStopped(){return event.isPropagationStopped();}};activateButton(click);
 }

 return <button {...props} onPointerDown={event=>{motion.current?.cancel();onPointerDown?.(event);}} onPointerUp={event=>{onPointerUp?.(event);if(!event.defaultPrevented)spring(event.currentTarget);}} onPointerCancel={event=>{motion.current?.cancel();onPointerCancel?.(event);}} onTouchStart={event=>{const point=event.touches.length===1?event.touches[0]:null;touch.current=point?{id:point.identifier,x:point.clientX,y:point.clientY,moved:false}:null;onTouchStart?.(event);}} onTouchMove={event=>{const press=touch.current,point=[...event.touches].find(p=>p.identifier===press?.id);if(press&&(!point||event.touches.length!==1||Math.hypot(point.clientX-press.x,point.clientY-press.y)>8))press.moved=true;onTouchMove?.(event);}} onTouchEnd={touchEnd} onTouchCancel={event=>{touch.current=null;motion.current?.cancel();onTouchCancel?.(event);}} onClick={event=>{if(disabled||busy)return;if(event.detail===0&&event.isTrusted)spring(event.currentTarget);activateButton(event);}} type={type} className={className} data-mv-feedback={feedback} title={label??props.title} aria-label={label??props['aria-label']} aria-pressed={selected===undefined?props['aria-pressed']:Boolean(selected)} aria-busy={busy||props['aria-busy']||undefined} disabled={disabled||busy} data-mv-component={props['data-mv-component']||'action-button'}>{children}</button>;
}
