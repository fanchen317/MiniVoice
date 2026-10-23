import React,{memo,useEffect,useState} from 'react';
import {Icon} from './components/PlayerControls.jsx';
export default memo(function Artwork({src,alt='',...props}){
 const [failed,setFailed]=useState(false);useEffect(()=>setFailed(false),[src]);
 return src&&!failed?<img src={src} alt={alt} {...props} decoding="async" onError={()=>setFailed(true)}/>:<span className="mv-art-fallback" role={alt?'img':undefined} aria-label={alt||undefined} aria-hidden={!alt}><Icon name="music"/></span>;
});
