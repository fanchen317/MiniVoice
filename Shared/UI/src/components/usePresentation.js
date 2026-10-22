import {useLayoutEffect,useState} from 'react';
import {layoutFor} from '../presentation.js';
/** Observe content space, not physical display pixels or an operating-system name. */
export function usePresentation(target,presentation){
 const [layout,setLayout]=useState(()=>layoutFor(presentation));
 useLayoutEffect(()=>{
  const node=typeof target==='function'?target():target.current;if(!node)return;
  const measure=()=>{const next=layoutFor(presentation,{width:node.clientWidth,height:node.clientHeight});setLayout(previous=>JSON.stringify(previous)===JSON.stringify(next)?previous:next);node.dataset.presentation=presentation.family;node.dataset.reference=presentation.reference;node.dataset.primaryInput=next.input;if(presentation.family==='mobile')node.dataset.input='touch';node.dataset.layout=next.size;node.dataset.device=next.device;node.dataset.orientation=next.orientation;node.dataset.dialogPlacement=next.dialog;node.style.setProperty('--mv-minimum-target',`${next.minimumTarget}px`);};
  const observer=new ResizeObserver(measure);observer.observe(node);measure();return()=>observer.disconnect();
 },[target,presentation]);
 return layout;
}
