import React,{useLayoutEffect,useState} from 'react';
import {DrawerSample,sameDrawerScene,useDrawerSamples} from './drawerSampling.jsx';
/** Full viewport wall retained underneath the recessed interactive scene. */
export default function WallDrawerBackdrop({open,wall,sourceKey}){
 const [candidate,setCandidate]=useState(null),[visible,setVisible]=useState(open),samples=useDrawerSamples(candidate);
 useLayoutEffect(()=>{
  const timer=!open?setTimeout(()=>setVisible(false),340):null;
  if(open)setVisible(true);else if(candidate)return()=>clearTimeout(timer);
  let frame=0,attempt=0,previous=[],stable=0;
  const publish=cells=>setCandidate(value=>value&&sameDrawerScene(value.cells,cells)?value:{mode:'wall',cells});
  const initial=wall.current?.backdrop?.()||[];if(initial.length)publish(initial);
  const capture=()=>{const next=wall.current?.backdrop?.()||[];stable=next.length&&sameDrawerScene(previous,next)?stable+1:0;previous=next;
   if(next.length&&(stable>=4||attempt>=59)){publish(next);return;}
   if(++attempt<60)frame=requestAnimationFrame(capture);
  };
  const restart=()=>{cancelAnimationFrame(frame);attempt=0;stable=0;previous=[];frame=requestAnimationFrame(capture);};restart();window.addEventListener('resize',restart);
  return()=>{clearTimeout(timer);cancelAnimationFrame(frame);window.removeEventListener('resize',restart);};
 },[open,wall,sourceKey]);
 return <div className="mv-wall-drawer-backdrop" hidden={!visible||!samples.layers.length} data-mv-component="wall-drawer-backdrop" aria-hidden="true">{samples.layers.map(snapshot=><DrawerSample key={snapshot.token} snapshot={snapshot} pending={snapshot===samples.pending} retired={snapshot===samples.retired} kind="backdrop" onReady={samples.ready} recessed={open}/>)}</div>;
}
