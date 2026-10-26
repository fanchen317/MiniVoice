import React,{useEffect,useRef,useState} from 'react';
import {sliderValue,sliderAt,sliderKey} from './sliderModel.js';
/** MiniVoice owns hit testing, preview and commit. Platform polling cannot move a held thumb. */
export default function Slider({label,min=0,max=1,step=.01,value=0,disabled=false,resetKey,onValueChange,onCommit,onCancel,valueText,className='',style,marks=[]}){
 const root=useRef(null),active=useRef(null),pending=useRef(null),live=useRef(value),timer=useRef(null),generation=useRef(0),[draft,setDraft]=useState(null);
 const normalized=sliderValue(value,min,max,step),shown=draft===null?normalized:sliderValue(draft,min,max,step);live.current=shown;
 function clear(){clearTimeout(timer.current);pending.current=null;active.current=null;setDraft(null);}
 useEffect(()=>{generation.current++;clear();},[resetKey,disabled]);
 useEffect(()=>()=>{generation.current++;clearTimeout(timer.current);},[]);
 useEffect(()=>{if(!active.current&&(pending.current===null||Math.abs(normalized-pending.current)<=Math.max(.0001,step*2))){pending.current=null;clearTimeout(timer.current);setDraft(null);}},[normalized,step]);
 function preview(next){live.current=next;setDraft(next);onValueChange?.(next);}
 function commit(){const next=live.current,token=++generation.current;active.current=null;pending.current=next;setDraft(next);clearTimeout(timer.current);timer.current=setTimeout(()=>{if(token===generation.current){pending.current=null;setDraft(null);}},1500);try{Promise.resolve(onCommit?.(next)).catch(()=>{if(token===generation.current)clear();});}catch(error){clear();throw error;}}
 function cancel(){if(!active.current)return;generation.current++;clear();onCancel?.();}
 function point(event){const rect=event.currentTarget.getBoundingClientRect();return sliderAt(event.clientX,rect.left,rect.width,min,max,step);}
 const fraction=(shown-min)/Math.max(.00001,max-min)*100;
 return <div ref={root} className={`mv-slider ${className}`} data-mv-component="slider" data-dragging={Boolean(active.current)} role="slider" tabIndex={disabled?-1:0} aria-label={label} aria-disabled={disabled||undefined} aria-valuemin={min} aria-valuemax={max} aria-valuenow={shown} aria-valuetext={valueText?.(shown)} style={{...style,'--mv-slider-progress':`${Math.max(0,Math.min(100,fraction))}%`}}
 onClick={event=>event.stopPropagation()} onDoubleClick={event=>event.stopPropagation()}
 onPointerDown={event=>{if(disabled||event.button!==0||active.current)return;event.preventDefault();event.stopPropagation();clearTimeout(timer.current);pending.current=null;const mark=event.target.closest('[data-slider-mark]');active.current={pointer:event.pointerId,startX:event.clientX,mark:mark?Number(mark.dataset.sliderMark):null,moved:false};event.currentTarget.setPointerCapture(event.pointerId);if(event.pointerType==='mouse')event.currentTarget.focus({preventScroll:true});preview(active.current.mark??point(event));}}
 onPointerMove={event=>{if(active.current?.pointer!==event.pointerId)return;event.preventDefault();event.stopPropagation();if(Math.abs(event.clientX-active.current.startX)>4)active.current.moved=true;preview(point(event));}}
 onPointerUp={event=>{if(active.current?.pointer!==event.pointerId)return;event.preventDefault();event.stopPropagation();preview(active.current.mark!==null&&!active.current.moved?active.current.mark:point(event));commit();}}
 onPointerCancel={cancel} onLostPointerCapture={cancel}
 onKeyDown={event=>{if(disabled)return;if(event.key==='Escape'&&active.current){event.preventDefault();event.stopPropagation();cancel();return;}const next=sliderKey(event.key,live.current,min,max,step);if(next===null)return;event.preventDefault();event.stopPropagation();active.current={keyboard:true};preview(next);}}
 onKeyUp={event=>{if(!active.current?.keyboard||sliderKey(event.key,live.current,min,max,step)===null)return;event.preventDefault();event.stopPropagation();commit();}}
 onBlur={()=>{if(active.current?.keyboard)commit();else cancel();}}><span className="mv-slider-track" aria-hidden="true"><span className="mv-slider-fill"/></span>{[...new Set(marks)].filter(mark=>mark>=min&&mark<=max).map(mark=><span key={mark} data-slider-mark={mark} className="mv-slider-mark" aria-hidden="true" style={{left:`${(mark-min)/(max-min)*100}%`}}><i/></span>)}<span className="mv-slider-knob" aria-hidden="true"/></div>;
}
