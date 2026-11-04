import React,{useLayoutEffect,useRef,useState} from 'react';
import ActionButton from './ActionButton.jsx';
import {Icon} from './PlayerControls.jsx';
/** Local visual preference; no playback or file mutation. */
export default function ArtworkModeButton(){
 const root=useRef(null),[blurred,setBlurred]=useState(false);
 useLayoutEffect(()=>{const surface=root.current?.closest('.wall-poster,.mv-wall-focused');if(surface)surface.dataset.artworkMode=blurred?'blurred':'solid';},[blurred]);
 return <ActionButton ref={root} className="mv-button artwork-mode-toggle" aria-label={blurred?'切换清晰插图':'切换高斯模糊插图'} aria-pressed={blurred} onClick={()=>setBlurred(value=>!value)}><Icon name="droplet"/></ActionButton>;
}
