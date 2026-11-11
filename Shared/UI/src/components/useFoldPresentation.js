import {useLayoutEffect,useRef,useState} from 'react';
// CSS interpolates from its current values; only surface lifetime is React state.
export function useFoldPresentation(root,target,animated){
 const previous=useRef(target),[retained,setRetained]=useState(target),[moving,setMoving]=useState(false);
 const changing=previous.current!==target;
 useLayoutEffect(()=>{
  const changed=previous.current!==target;previous.current=target;
  const node=root.current,media=matchMedia('(prefers-reduced-motion:reduce)');
  const reduced=()=>media.matches||document.documentElement.classList.contains('reduce-motion');
  if(!animated||reduced()){setRetained(target);setMoving(false);return;}
  if(!changed||!node)return;
  setRetained(true);setMoving(true);
  const finish=()=>{setRetained(target);setMoving(false);};
  const end=event=>{if(event.target===node&&event.propertyName==='--mv-fold-mid')finish();};
  const motionChanged=()=>{if(reduced())finish();};
  node.addEventListener('transitionend',end);media.addEventListener('change',motionChanged);
  const changes=new MutationObserver(motionChanged);changes.observe(document.documentElement,{attributes:true,attributeFilter:['class']});
  const timer=setTimeout(finish,470);
  return()=>{clearTimeout(timer);changes.disconnect();node.removeEventListener('transitionend',end);media.removeEventListener('change',motionChanged);};
 },[root,target,animated]);
 return {active:target||(animated&&retained),moving:animated&&(changing||moving)};
}
