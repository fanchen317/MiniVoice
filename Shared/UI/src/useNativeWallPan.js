import {useLayoutEffect,useRef} from 'react';
/** Native overflow scrolling owns one-finger momentum; the wall still owns its camera. */
export function useNativeWallPan(view,enabled,viewport,live,latest,update,save,clearHold){
 const origin=useRef(null),pinch=useRef(null),syncing=useRef(false);
 const sync=(camera=live.current)=>{
  const node=view.current;if(!enabled||!node||!origin.current)return;
  const center={x:viewport.width*32,y:viewport.height*32};
  let left=origin.current.x-camera.x,top=origin.current.y-camera.y;
  if(left<viewport.width*2||left>viewport.width*62){left=center.x;origin.current.x=camera.x+left;}
  if(top<viewport.height*2||top>viewport.height*62){top=center.y;origin.current.y=camera.y+top;}
  syncing.current=true;
  // Reassigning even the same scroll offset can stop WebKit momentum.
  if(Math.abs(node.scrollLeft-left)>.01)node.scrollLeft=left;
  if(Math.abs(node.scrollTop-top)>.01)node.scrollTop=top;
  syncing.current=false;
 };
 const state=useRef({});state.current={viewport,update,save,clearHold,sync};
 useLayoutEffect(()=>{
  if(!enabled||!viewport.width||!viewport.height)return;
  const node=view.current,center={x:viewport.width*32,y:viewport.height*32};
  origin.current={x:live.current.x+center.x,y:live.current.y+center.y};
  node.scrollLeft=center.x;node.scrollTop=center.y;
  // Initial positioning must finish before the first wall paint.
  state.current.update({...live.current},true);
 },[enabled,viewport.width,viewport.height]);
 useLayoutEffect(()=>{
  if(!enabled)return;
  const node=view.current;let timer;
  const scroll=()=>{
   if(syncing.current||!origin.current)return;
   const next={...live.current,x:origin.current.x-node.scrollLeft,y:origin.current.y-node.scrollTop};
   if(Math.abs(next.x-live.current.x)<.01&&Math.abs(next.y-live.current.y)<.01)return;
   state.current.clearHold();state.current.update(next);
   clearTimeout(timer);timer=setTimeout(()=>state.current.save(),180);
  };
  const touchmove=event=>{
   if(!pinch.current||event.touches.length!==2)return;
   event.preventDefault();const a=event.touches[0],b=event.touches[1],p=pinch.current,rect=node.getBoundingClientRect();
   const scale=Math.min(1.2,Math.max(.6,p.camera.scale*Math.hypot(a.clientX-b.clientX,a.clientY-b.clientY)/p.distance));
   const x=(a.clientX+b.clientX)/2-rect.left,y=(a.clientY+b.clientY)/2-rect.top;
   state.current.update({scale,x:x-p.x*scale/p.camera.scale,y:y-p.y*scale/p.camera.scale});
  };
  const end=()=>{if(!pinch.current)return;pinch.current=null;node.removeEventListener('touchmove',touchmove);state.current.save();};
  const start=event=>{
   if(event.touches.length!==2||latest.current.blocked||latest.current.expanded)return;
   event.preventDefault();state.current.clearHold();const a=event.touches[0],b=event.touches[1],rect=node.getBoundingClientRect(),c=live.current;
   pinch.current={camera:{...c},distance:Math.max(1,Math.hypot(a.clientX-b.clientX,a.clientY-b.clientY)),x:(a.clientX+b.clientX)/2-rect.left-c.x,y:(a.clientY+b.clientY)/2-rect.top-c.y};
   // A blocking move listener exists only during a two-finger zoom, never a pan.
   node.addEventListener('touchmove',touchmove,{passive:false});
  };
  node.addEventListener('scroll',scroll,{passive:true});node.addEventListener('touchstart',start,{passive:false});node.addEventListener('touchend',end,{passive:true});node.addEventListener('touchcancel',end,{passive:true});
  return()=>{clearTimeout(timer);node.removeEventListener('scroll',scroll);node.removeEventListener('touchstart',start);node.removeEventListener('touchend',end);node.removeEventListener('touchcancel',end);node.removeEventListener('touchmove',touchmove);origin.current=null;pinch.current=null;};
 },[enabled]);
 return {sync,offset:()=>enabled&&origin.current?{x:view.current.scrollLeft,y:view.current.scrollTop}:{x:0,y:0}};
}
