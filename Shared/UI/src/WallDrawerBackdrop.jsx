import React,{useLayoutEffect,useState} from 'react';
import Artwork from './Artwork.jsx';
/** Full viewport wall retained underneath the recessed interactive scene. */
export default function WallDrawerBackdrop({open,wall}){
 const [cells,setCells]=useState([]);
 useLayoutEffect(()=>{if(!open)return;const capture=()=>{const next=wall.current?.backdrop?.();if(next?.length)setCells(next);};capture();window.addEventListener('resize',capture);return()=>window.removeEventListener('resize',capture);},[open,wall]);
 return <div className="mv-wall-drawer-backdrop" data-mv-component="wall-drawer-backdrop" aria-hidden="true">{cells.map(cell=><div key={cell.id} style={{position:'absolute',left:cell.x,top:cell.y,width:cell.width,height:cell.height,overflow:'hidden'}}><Artwork src={cell.artwork}/></div>)}</div>;
}
