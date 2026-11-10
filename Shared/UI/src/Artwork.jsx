import React,{memo,useEffect,useState} from 'react';
import {Icon} from './components/PlayerControls.jsx';
export default memo(function Artwork({src,alt='',onError,className='',style,...props}){
 const [failedSource,setFailedSource]=useState(null);
 // A new source may retry an older failure, while its own early error must
 // survive the effect instead of causing another request for the same image.
 useEffect(()=>setFailedSource(failure=>failure===src?failure:null),[src]);
 return src&&failedSource!==src?<img data-mv-component="artwork" src={src} alt={alt} {...props} className={className||undefined} style={style} decoding="async" onError={event=>{setFailedSource(src);onError?.(event);}}/>:<span data-mv-component="artwork" className={`mv-art-fallback${className?' '+className:''}`} style={style} role={alt?'img':undefined} aria-label={alt||undefined} aria-hidden={!alt}><Icon name="music"/></span>;
});
