import React,{useLayoutEffect,useRef,useState} from 'react';
import {DrawerSample,sameDrawerScene,useDrawerSamples} from './drawerSampling.jsx';
/** Retains decoded app-owned sampling across styles instead of remounting to a solid tint. */
export default function DrawerMaterial({artwork,wall,sample,sampleKey,open=true}){
 const [candidate,setCandidate]=useState(null),root=useRef(null),cover=useRef(artwork),latest=useRef();
 if(artwork)cover.current=artwork;latest.current={sample,wall,sampleKey};
 const samples=useDrawerSamples(candidate);
 useLayoutEffect(()=>{
  let frame=0,attempt=0,cancelled=false;const node=root.current;
  const capture=()=>{
   const state=latest.current,panel=node.closest('.mv-drawer'),r=node.getBoundingClientRect(),matrix=new DOMMatrixReadOnly(getComputedStyle(panel).transform),origin={x:r.x-matrix.m41,y:r.y-matrix.m42};
   if(state.sampleKey!=='wall'){if(cover.current)setCandidate(previous=>previous?.mode==='cover'&&previous.artwork===cover.current?previous:{mode:'cover',artwork:cover.current});return;}
   const cells=state.wall?.length?state.wall:state.sample?.();
   if(cells?.length){setCandidate(previous=>previous?.mode==='wall'&&Math.abs(previous.origin.x-origin.x)+Math.abs(previous.origin.y-origin.y)<.5&&sameDrawerScene(previous.cells,cells)?previous:{mode:'wall',cells,origin});return;}
   if(!cancelled&&++attempt<60)frame=requestAnimationFrame(capture);
  };
  // Warm while closed, too. Every open captures the current frozen camera;
  // the already decoded material remains in place until that sample is ready.
  capture();window.addEventListener('resize',capture);
  return()=>{cancelled=true;cancelAnimationFrame(frame);window.removeEventListener('resize',capture);};
 },[sampleKey,wall,open,artwork]);
 return <div ref={root} className="mv-drawer-material" data-mv-component="drawer-material" data-sampled={Boolean(samples.shown)} aria-hidden="true">{samples.layers.map(snapshot=><DrawerSample key={snapshot.token} snapshot={snapshot} pending={snapshot===samples.pending} retired={snapshot===samples.retired} onReady={samples.ready}/>)}<div className="mv-drawer-tint"/></div>;
}
