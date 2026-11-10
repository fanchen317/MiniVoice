import React,{useLayoutEffect,useRef} from 'react';
/** Retained drawer: reversal samples the same node, never clones the catalog. */
export default function DrawerLayer({children,open=true,...props}){
 const layer=useRef(null),motion=useRef(null),previous=useRef(null),watch=useRef(null);
 useLayoutEffect(()=>{
  const node=layer.current,panel=node.querySelector('.mv-drawer');if(!panel)return;
  const media=matchMedia('(prefers-reduced-motion:reduce)'),reduced=()=>media.matches||document.documentElement.classList.contains('reduce-motion');
  // Sample before cancelling: a reversal starts at its currently displayed
  // position, not the previous intent's inline terminal transform.
  const first=previous.current===null,from=motion.current?getComputedStyle(panel).transform:first?'translateX(-110%)':open?'translateX(-110%)':'none';
  watch.current?.();watch.current=null;motion.current?.cancel();motion.current=null;previous.current=open;
  const to=open?'none':'translateX(-110%)';panel.style.transform=to;
  if(reduced()||first&&!open)return;
  const animation=panel.animate([{transform:from},{transform:to}],{duration:320,easing:'cubic-bezier(.2,.8,.2,1)'});motion.current=animation;
  const cleanup=()=>{observer.disconnect();media.removeEventListener('change',changed);};
  const changed=()=>{if(reduced()&&motion.current===animation){cleanup();watch.current=null;motion.current=null;animation.cancel();}};
  const observer=new MutationObserver(changed);observer.observe(document.documentElement,{attributes:true,attributeFilter:['class']});media.addEventListener('change',changed);watch.current=cleanup;
  animation.finished.then(()=>{cleanup();if(motion.current===animation){motion.current=null;watch.current=null;}},()=>{cleanup();if(motion.current===animation){motion.current=null;watch.current=null;}});
 },[open]);
 useLayoutEffect(()=>()=>{watch.current?.();motion.current?.cancel();},[]);
 return <div ref={layer} data-mv-component="drawer-layer" data-open={open} inert={!open} aria-hidden={!open} {...props}>{children}</div>;
}
