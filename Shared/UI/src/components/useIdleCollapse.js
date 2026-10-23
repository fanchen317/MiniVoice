import {useEffect,useRef,useState} from 'react';
/** Idle owns presentation only; timers never change playback. */
export function useIdleCollapse({enabled=true,blocked=false,identity,onChange,delay=3000}={}){
 const [collapsed,setCollapsed]=useState(false),timer=useRef(),flags=useRef({held:false,hover:false,focus:false}),latest=useRef();
 latest.current={enabled,blocked,onChange,delay};
 function change(value){setCollapsed(value);latest.current.onChange?.(value);}
 function stop(){clearTimeout(timer.current);}
 function schedule(){stop();if(latest.current.enabled&&!latest.current.blocked&&!Object.values(flags.current).some(Boolean))timer.current=setTimeout(()=>change(true),latest.current.delay);}
 function expand(){change(false);schedule();}
 useEffect(()=>{if(!enabled){flags.current={held:false,hover:false,focus:false};change(false);stop();return;}schedule();return stop;},[enabled,blocked,identity,delay]);
 return {collapsed,expand,events:{onPointerEnter:event=>{if(event.pointerType==='mouse'){flags.current.hover=true;stop();expand();}},onPointerLeave:()=>{flags.current.hover=false;schedule();},onPointerDown:()=>{flags.current.held=true;stop();},onPointerUp:()=>{flags.current.held=false;schedule();},onPointerCancel:()=>{flags.current.held=false;schedule();},onFocusCapture:event=>{flags.current.focus=event.target.matches(':focus-visible');if(flags.current.focus){stop();change(false);}},onBlurCapture:event=>{if(!event.currentTarget.contains(event.relatedTarget)){flags.current.focus=false;schedule();}}}};
}
