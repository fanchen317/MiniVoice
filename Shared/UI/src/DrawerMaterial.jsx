import React,{useLayoutEffect,useRef,useState} from 'react';
import Artwork from './Artwork.jsx';
/** Retains decoded app-owned sampling across styles instead of remounting to a solid tint. */
export default function DrawerMaterial({artwork,wall,sample,sampleKey,open=true}){
 const [scene,setScene]=useState(wall),root=useRef(null),cover=useRef(artwork),[origin,setOrigin]=useState({x:0,y:0});
 if(artwork)cover.current=artwork;
 useLayoutEffect(()=>{
  let frame=0,attempt=0;const node=root.current;
  const measure=()=>{const panel=node.closest('.mv-drawer'),r=node.getBoundingClientRect(),matrix=new DOMMatrixReadOnly(getComputedStyle(panel).transform),next={x:r.x-matrix.m41,y:r.y-matrix.m42};setOrigin(previous=>Math.abs(previous.x-next.x)+Math.abs(previous.y-next.y)<.5?previous:next);};
  // Opening already supplies a frozen wall sample. Do not query or repaint the
  // live wall repeatedly while its foreground panel is travelling.
  measure();
  if(!open)return;
  if(sampleKey!=='wall')setScene(null);
  else if(wall?.length)setScene(wall);
  else {const capture=()=>{const next=sample?.();if(next?.length){setScene(next);return;}if(++attempt<60)frame=requestAnimationFrame(capture);};frame=requestAnimationFrame(capture);}
  window.addEventListener('resize',measure);
  return()=>{cancelAnimationFrame(frame);window.removeEventListener('resize',measure);};
 },[sampleKey,wall,open]);
 return <div ref={root} className="mv-drawer-material" data-sampled={Boolean(sampleKey==='wall'?scene?.length:cover.current)} aria-hidden="true"><div className="mv-drawer-sample">{sampleKey!=='wall'&&cover.current&&<Artwork src={cover.current}/>} {(sampleKey==='wall'?scene:[])?.map(cell=><div key={cell.id} className="mv-drawer-poster" style={{left:cell.x-origin.x,top:cell.y-origin.y,width:cell.width,height:cell.height}}><Artwork src={cell.artwork}/></div>)}</div><div className="mv-drawer-tint"/></div>;
}
