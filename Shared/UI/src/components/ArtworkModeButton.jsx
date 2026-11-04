import React,{createContext,useContext,useState} from 'react';
import ActionButton from './ActionButton.jsx';
import {Icon} from './PlayerControls.jsx';
const Mode=createContext(null);
/** Scope owns the render mode; changing it updates both icon and real pixels. */
export function ArtworkModeScope({as:Element='section',children,...props}){
 const [blurred,setBlurred]=useState(false);
 return <Mode.Provider value={{blurred,setBlurred}}><Element {...props} data-artwork-mode={blurred?'blurred':'solid'}>{children}</Element></Mode.Provider>;
}
export function ArtworkBlur({src}){
 const mode=useContext(Mode),[loaded,setLoaded]=useState('');
 return src?<img className="mv-artwork-blur" src={src} alt="" draggable={false} decoding="async" aria-hidden="true" onLoad={()=>setLoaded(src)} style={{opacity:mode?.blurred&&loaded===src?1:0}}/>:null;
}
export default function ArtworkModeButton(){
 const scoped=useContext(Mode),[local,setLocal]=useState(false),blurred=scoped?.blurred??local;
 return <ActionButton className="mv-button artwork-mode-toggle" aria-label={blurred?'切换清晰插图':'切换高斯模糊插图'} aria-pressed={blurred} onClick={()=>scoped?scoped.setBlurred(!blurred):setLocal(!blurred)}><Icon name={blurred?'artworkSoft':'artworkSharp'}/></ActionButton>;
}
