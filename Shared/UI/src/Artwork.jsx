import React,{useEffect,useState} from 'react';
export default function Artwork({src,alt='',...props}){
 const [failed,setFailed]=useState(false);useEffect(()=>setFailed(false),[src]);
 return src&&!failed?<img src={src} alt={alt} {...props} onError={()=>setFailed(true)}/>:<span className="mv-art-fallback" role={alt?'img':undefined} aria-label={alt||undefined} aria-hidden={!alt}><span className="mv-native-icon" style={{maskImage:'url(./assets/icons/icon_navigation_all.png)',WebkitMaskImage:'url(./assets/icons/icon_navigation_all.png)'}}/></span>;
}
