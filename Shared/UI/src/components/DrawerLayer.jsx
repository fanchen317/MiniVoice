import React,{useRef} from 'react';
import {useSurfaceMotion} from './useSurfaceMotion.js';
export default function DrawerLayer({children,...props}){
 const layer=useRef(null);
 useSurfaceMotion(layer,true,{surface:'drawer'});
 return <div ref={layer} data-mv-component="drawer-layer" {...props}>{children}</div>;
}
