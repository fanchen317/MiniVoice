import React,{useLayoutEffect,useRef,useState} from 'react';
import Artwork from './Artwork.jsx';
/** Retains decoded app-owned sampling across styles instead of remounting to a solid tint. */
export default function DrawerMaterial({artwork,wall,sample,sampleKey}){
 const [scene,setScene]=useState(wall),root=useRef(null),cover=useRef(artwork),[origin,setOrigin]=useState({x:0,y:0});
 if(artwork)cover.current=artwork;
 useLayoutEffect(()=>{
  let frame=0,attempt=0;const node=root.current;
  const measure=()=>{const panel=node.closest('.mv-drawer'),r=node.getBoundingClientRect(),matrix=new DOMMatrixReadOnly(getComputedStyle(panel).transform),next={x:r.x-matrix.m41,y:r.y-matrix.m42};setOrigin(previous=>Math.abs(previous.x-next.x)+Math.abs(previous.y-next.y)<.5?previous:next);};
  const read=()=>{measure();const next=sample?.()||wall;if(next?.length)setScene(next);else if(sampleKey==='wall'&&attempt++<4)frame=requestAnimationFrame(read);};
  if(sampleKey!=='wall')setScene(null);read();
  const observer=new ResizeObserver(measure);observer.observe(node);
  return()=>{cancelAnimationFrame(frame);observer.disconnect();};
 },[sampleKey,wall]);
 return <div ref={root} className="mv-drawer-material" data-sampled={Boolean(scene?.length||cover.current)} aria-hidden="true"><div className="mv-drawer-sample">{cover.current&&<Artwork src={cover.current}/>} {scene?.map(cell=><div key={cell.id} className="mv-drawer-poster" style={{left:cell.x-origin.x,top:cell.y-origin.y,width:cell.width,height:cell.height}}><Artwork src={cell.artwork}/></div>)}</div><div className="mv-drawer-tint"/></div>;
}
