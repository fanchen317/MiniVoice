import React,{useLayoutEffect,useRef,useState} from 'react';
import Artwork from './Artwork.jsx';

export function sameDrawerScene(a=[],b=[]){return a.length===b.length&&a.every((cell,index)=>{const next=b[index];return cell.id===next.id&&cell.artwork===next.artwork&&cell.x===next.x&&cell.y===next.y&&cell.width===next.width&&cell.height===next.height;});}
function sameSample(a,b){return Boolean(a&&b&&a.mode===b.mode&&a.artwork===b.artwork&&a.origin?.x===b.origin?.x&&a.origin?.y===b.origin?.y&&sameDrawerScene(a.cells,b.cells));}
/** A pending sample never replaces decoded pixels during a drawer/style transition. */
export function useDrawerSamples(candidate){
 const [layers,setLayers]=useState({shown:null,pending:null,underlay:null}),serial=useRef(0),retirement=useRef(0);
 useLayoutEffect(()=>{
  if(!candidate)return;
  const token=++serial.current;
  setLayers(previous=>sameSample(previous.shown,candidate)?{...previous,pending:null}:sameSample(previous.pending,candidate)?previous:{...previous,pending:{...candidate,token}});
 },[candidate]);
 const ready=token=>setLayers(previous=>previous.pending?.token===token?{shown:previous.pending,pending:null,underlay:previous.shown}:previous);
 useLayoutEffect(()=>{
  if(!layers.underlay)return;const shown=layers.shown;
  retirement.current=requestAnimationFrame(()=>{retirement.current=requestAnimationFrame(()=>setLayers(previous=>previous.shown===shown?{...previous,underlay:null}:previous));});
  return()=>cancelAnimationFrame(retirement.current);
 },[layers.shown,layers.underlay]);
 return {layers:[layers.underlay,layers.shown,layers.pending].filter(Boolean),shown:layers.shown,pending:layers.pending,retired:layers.underlay,ready};
}
/** Keep this exact staged node when committing it, so decoding is not discarded. */
export function DrawerSample({snapshot,pending,onReady,kind='material',recessed=false,retired=false}){
 const root=useRef(null);
 useLayoutEffect(()=>{
  if(!pending)return;let cancelled=false,frame=0;const cleanups=[];
  const waitImage=image=>new Promise(resolve=>{
   let settled=false;
   const finish=()=>{if(settled)return;settled=true;image.removeEventListener('load',loaded);image.removeEventListener('error',failed);resolve();};
   const loaded=()=>{let decode;try{decode=image.decode();}catch{finish();return;}Promise.resolve(decode).then(finish,finish);};
   const failed=()=>finish();cleanups.push(finish);
   if(image.complete){if(image.naturalWidth)loaded();else finish();}
   else{image.addEventListener('load',loaded,{once:true});image.addEventListener('error',failed,{once:true});}
  });
  Promise.all([...root.current.querySelectorAll('img')].map(waitImage)).then(()=>{
   if(cancelled)return;
   // Let Artwork commit a confirmed-error placeholder before publishing it.
   frame=requestAnimationFrame(()=>{frame=requestAnimationFrame(()=>{if(!cancelled)onReady(snapshot.token);});});
  });
  return()=>{cancelled=true;cancelAnimationFrame(frame);cleanups.forEach(cleanup=>cleanup());};
 },[snapshot,pending]);
 const origin=snapshot.origin||{x:0,y:0};
 return <div ref={root} className={kind==='material'?'mv-drawer-sample':`mv-wall-drawer-extension ${recessed?'is-recessed':''}`} data-mv-component="drawer-sample" data-sample-token={snapshot.token} data-sample-pending={pending||undefined} data-sample-retired={retired||undefined} style={pending||retired?{visibility:'hidden'}:undefined}>
  {snapshot.mode==='cover'&&snapshot.artwork&&<Artwork src={snapshot.artwork}/>}
  {snapshot.cells?.map(cell=><div className={kind==='material'?'mv-drawer-poster':'mv-wall-backdrop-poster'} key={cell.id} style={kind==='material'?{left:cell.x-origin.x,top:cell.y-origin.y,width:cell.width,height:cell.height}:{position:'absolute',left:cell.x,top:cell.y,width:cell.width,height:cell.height,overflow:'hidden'}}><Artwork src={cell.artwork}/></div>)}
 </div>;
}
