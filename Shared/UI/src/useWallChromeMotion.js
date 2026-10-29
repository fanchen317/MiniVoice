import {useLayoutEffect,useRef,useState} from 'react';
import {WALL_EXPANSION_MS,WALL_CHROME_MS} from './wallMotion.js';
/** Retain chrome and its dock shape while the artwork owns the full viewport. */
export function useWallChromeMotion(expanded){
 const [phase,setPhase]=useState(expanded?'hidden':'visible'),previous=useRef(expanded);
 useLayoutEffect(()=>{
  const media=matchMedia('(prefers-reduced-motion:reduce)');let settle,enter;
  const stop=()=>{clearTimeout(settle);clearTimeout(enter);};
  const apply=()=>{
   stop();
   if(expanded){setPhase('hidden');return;}
   if(media.matches||!previous.current){setPhase('visible');return;}
   setPhase('hidden');
   settle=setTimeout(()=>{setPhase('entering');enter=setTimeout(()=>setPhase('visible'),WALL_CHROME_MS);},WALL_EXPANSION_MS);
  };
  apply();previous.current=expanded;
  const changed=()=>{stop();setPhase(expanded?'hidden':'visible');};media.addEventListener('change',changed);
  return()=>{stop();media.removeEventListener('change',changed);};
 },[expanded]);
 return {phase:expanded?'hidden':phase,concealed:expanded||phase==='hidden',paused:expanded||phase!=='visible'};
}
