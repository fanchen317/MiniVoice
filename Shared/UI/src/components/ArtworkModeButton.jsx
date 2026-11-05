import React,{createContext,useContext,useState,useRef,useEffect} from 'react';
import ActionButton from './ActionButton.jsx';
import {Icon} from './PlayerControls.jsx';
const Mode=createContext(null);
/** Scope owns the render mode; changing it updates both icon and real pixels. */
export function ArtworkModeScope({as:Element='section',children,...props}){
 const [blurred,setBlurred]=useState(false);
 return <Mode.Provider value={{blurred,setBlurred}}><Element {...props} data-artwork-mode={blurred?'blurred':'solid'}>{children}</Element></Mode.Provider>;
}
export function ArtworkBlur({src,onLoad,className=''}){
 const mode=useContext(Mode),[loaded,setLoaded]=useState(''),image=useRef();
 useEffect(()=>{const scope=image.current?.closest('[data-artwork-mode]');if(!scope)return;scope.dataset.artworkBlurReady=String(loaded===src);return()=>{delete scope.dataset.artworkBlurReady;};},[loaded,src]);
 return src?<img ref={image} className={`mv-artwork-blur ${className}`} src={src} alt="" draggable={false} decoding="async" aria-hidden="true" onLoad={async event=>{const node=event.currentTarget;try{await node.decode();}catch{return;}if(!node.isConnected||node.getAttribute('src')!==src)return;setLoaded(src);onLoad?.({currentTarget:node});}} style={{opacity:mode?.blurred&&loaded===src?1:0}}/>:null;
}
export default function ArtworkModeButton(){
 const scoped=useContext(Mode),[local,setLocal]=useState(false),blurred=scoped?.blurred??local;
 return <ActionButton className="mv-button artwork-mode-toggle" aria-label={blurred?'切换清晰插图':'切换高斯模糊插图'} aria-pressed={blurred} onClick={()=>scoped?scoped.setBlurred(!blurred):setLocal(!blurred)}><Icon name={blurred?'artworkSoft':'artworkSharp'}/></ActionButton>;
}
