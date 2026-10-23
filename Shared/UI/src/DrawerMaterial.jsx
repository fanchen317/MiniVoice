import React,{useLayoutEffect,useRef,useState} from 'react';
import Artwork from './Artwork.jsx';
/** Frozen app-owned scene sampling. No nested WebView backdrop readback. */
export default function DrawerMaterial({artwork,wall,sample}){
 const [scene,setScene]=useState(wall),root=useRef(null),[origin,setOrigin]=useState({x:0,y:0});
 useLayoutEffect(()=>{const r=root.current.getBoundingClientRect();setOrigin({x:r.x,y:r.y});if(sample)setScene(sample());},[]);
 return <div ref={root} className="mv-drawer-material" aria-hidden="true"><div className="mv-drawer-sample">{scene?.length?scene.map(cell=><div key={cell.id} className="mv-drawer-poster" style={{left:cell.x-origin.x,top:cell.y-origin.y,width:cell.width,height:cell.height}}><Artwork src={cell.artwork}/></div>):artwork?<Artwork src={artwork}/>:null}</div><div className="mv-drawer-tint"/></div>;
}
