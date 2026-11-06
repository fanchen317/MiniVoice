import React,{useLayoutEffect,useState} from 'react';
import Artwork from './Artwork.jsx';
/** Full viewport wall retained underneath the recessed interactive scene. */
export default function WallDrawerBackdrop({open,wall,sourceKey}){
 const [cells,setCells]=useState([]);
 useLayoutEffect(()=>{
  if(!open){const timer=setTimeout(()=>setCells([]),340);return()=>clearTimeout(timer);}
  let frame=0,attempt=0,previous='',stable=0;
  // Fill exposed viewport edges before the first recessed frame is painted.
  // Later stable samples may refine restored camera geometry.
  const initial=wall.current?.backdrop?.()||[];
  if(initial.length)setCells(initial);
  const capture=()=>{const next=wall.current?.backdrop?.()||[],signature=JSON.stringify(next);stable=next.length&&signature===previous?stable+1:0;previous=signature;
   // Wall mount, measurement and camera restoration can span several frames.
   if(next.length&&(stable>=4||attempt>=59)){setCells(next);return;}
   if(++attempt<60)frame=requestAnimationFrame(capture);
  };
  const restart=()=>{cancelAnimationFrame(frame);attempt=0;stable=0;previous='';frame=requestAnimationFrame(capture);};restart();window.addEventListener('resize',restart);
  return()=>{cancelAnimationFrame(frame);window.removeEventListener('resize',restart);};
 },[open,wall,sourceKey]);
 return <div className="mv-wall-drawer-backdrop" hidden={!cells.length} data-mv-component="wall-drawer-backdrop" aria-hidden="true"><div className={`mv-wall-drawer-extension ${open?'is-recessed':''}`}>{cells.map(cell=><div className="mv-wall-backdrop-poster" key={cell.id} style={{position:'absolute',left:cell.x,top:cell.y,width:cell.width,height:cell.height,overflow:'hidden'}}><Artwork src={cell.artwork}/></div>)}</div></div>;
}
