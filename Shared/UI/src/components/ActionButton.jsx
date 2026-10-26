import {useActivationFeedback,emitActivationFeedback} from './FeedbackContext.jsx';
import React,{useEffect,useRef} from 'react';
/** Shared semantics; each product family supplies its own visual skin. */
export default function ActionButton({label,children,selected,disabled=false,busy=false,type='button',className='',feedback='standard',haptic=true,onClick,onPointerDown,onPointerUp,onPointerCancel,...props}){
 const activate=useActivationFeedback(),motion=useRef(null);
 useEffect(()=>()=>motion.current?.cancel(),[]);
 useEffect(()=>{if(disabled||busy)motion.current?.cancel();},[disabled,busy]);
 function spring(node){
  if(feedback!=='standard'||disabled||busy||!node.closest('[data-presentation=mobile]')||document.documentElement.classList.contains('reduce-motion')||matchMedia('(prefers-reduced-motion:reduce)').matches)return;
  const from=Math.min(.96,parseFloat(getComputedStyle(node).scale)||1);motion.current?.cancel();
  motion.current=node.animate([{scale:String(from)},{scale:'1.045',offset:.5},{scale:'.992',offset:.78},{scale:'1'}],{duration:380,easing:'cubic-bezier(.22,.9,.25,1)'});
 }

 return <button {...props} onPointerDown={event=>{motion.current?.cancel();onPointerDown?.(event);}} onPointerUp={event=>{onPointerUp?.(event);if(!event.defaultPrevented)spring(event.currentTarget);}} onPointerCancel={event=>{motion.current?.cancel();onPointerCancel?.(event);}} onClick={event=>{if(disabled||busy)return;if(event.detail===0&&event.isTrusted)spring(event.currentTarget);if(haptic&&(onClick||type==='submit')&&event.isTrusted&&!event.defaultPrevented)emitActivationFeedback(activate);onClick?.(event);}} type={type} className={className} data-mv-feedback={feedback} title={label??props.title} aria-label={label??props['aria-label']} aria-pressed={selected===undefined?props['aria-pressed']:Boolean(selected)} aria-busy={busy||undefined} disabled={disabled||busy} data-mv-component={props['data-mv-component']||'action-button'}>{children}</button>;
}
