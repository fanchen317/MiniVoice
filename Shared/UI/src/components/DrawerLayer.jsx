import React,{useLayoutEffect,useRef} from 'react';
/** Retained drawer: reversal samples the same node, never clones the catalog. */
export default function DrawerLayer({children,open=true,...props}){
 const layer=useRef(null),motion=useRef(null),previous=useRef(null);
 useLayoutEffect(()=>{const node=layer.current,panel=node.querySelector('.mv-drawer');if(!panel)return;const reduced=matchMedia('(prefers-reduced-motion:reduce)').matches||document.documentElement.classList.contains('reduce-motion'),from=motion.current?getComputedStyle(panel).transform:previous.current===null?'translateX(-110%)':open?'translateX(-110%)':'none';motion.current?.cancel();previous.current=open;
  const to=open?'none':'translateX(-110%)';panel.style.transform=to;if(reduced)return;
  const animation=panel.animate([{transform:from},{transform:to}],{duration:320,easing:'cubic-bezier(.2,.8,.2,1)'});motion.current=animation;animation.finished.catch(()=>{}).finally(()=>{if(motion.current===animation)motion.current=null;});
 },[open]);
 useLayoutEffect(()=>()=>motion.current?.cancel(),[]);
 return <div ref={layer} data-mv-component="drawer-layer" data-open={open} inert={!open} aria-hidden={!open} {...props}>{children}</div>;
}
