import {useLayoutEffect,useRef} from 'react';
import {dragArtworkAnchor,normalizeArtworkAnchor} from './artworkFraming.js';
const control='button,input,textarea,select,[role=slider],[contenteditable=true],a';
const isControl=target=>target.closest(control)&&!target.closest('.wp-lyrics,.wall-lyrics,.mv-kinetic-lyrics');
/** A gesture previews pixels only. The page persists exactly one successful end. */
export function useArtworkPan(root,{enabled,identity,presentation,getAnchor,getGeometry,onPreview,onCommit}){
 const latest=useRef();latest.current={getAnchor,getGeometry,onPreview,onCommit};
 useLayoutEffect(()=>{
  const node=root.current;if(!node||!enabled)return;
  let gesture=null,hold=0,suppressUntil=0;
  const swallow=event=>{event.preventDefault();event.stopImmediatePropagation();};
  const point=touches=>({x:(touches[0].clientX+touches[1].clientX)/2,y:(touches[0].clientY+touches[1].clientY)/2});
  function start(origin,kind,id){const geometry=latest.current.getGeometry();if(!geometry)return;gesture={kind,id,origin,geometry,anchor:normalizeArtworkAnchor(latest.current.getAnchor()),value:null,claimed:kind==='touch',moved:false};if(gesture.claimed)node.dataset.artworkPanning='true';}
  function moveTo(position){const g=gesture;if(!g)return;const dx=position.x-g.origin.x,dy=position.y-g.origin.y;if(!g.claimed){if(Math.hypot(dx,dy)>8)cancel();return;}g.moved||=Math.hypot(dx,dy)>2;g.value=dragArtworkAnchor(g.anchor,dx,dy,g.geometry);latest.current.onPreview(g.value);}
  function finish(commit){const g=gesture;clearTimeout(hold);gesture=null;delete node.dataset.artworkPanning;if(!g)return;try{if(g.kind==='mouse'&&node.hasPointerCapture(g.id))node.releasePointerCapture(g.id);}catch{}
   if(g.claimed){suppressUntil=performance.now()+750;if(commit&&g.moved&&g.value&&(g.value.x!==g.anchor.x||g.value.y!==g.anchor.y))latest.current.onCommit(g.value);else latest.current.onPreview(g.anchor);}
  }
  function cancel(){finish(false);}
  function touchStart(event){if(event.touches.length>2){cancel();return;}if(gesture||event.touches.length!==2||isControl(event.target))return;start(point(event.touches),'touch');if(gesture)swallow(event);}
  function touchMove(event){if(gesture?.kind!=='touch')return;if(event.touches.length!==2){cancel();swallow(event);return;}moveTo(point(event.touches));swallow(event);}
  function touchEnd(event){if(gesture?.kind!=='touch')return;finish(true);swallow(event);}
  function pointerDown(event){if(event.pointerType==='touch'||event.button!==0||isControl(event.target)||gesture)return;start({x:event.clientX,y:event.clientY},'mouse',event.pointerId);if(!gesture)return;
   hold=setTimeout(()=>{if(!gesture)return;gesture.claimed=true;node.dataset.artworkPanning='true';try{node.setPointerCapture(gesture.id);}catch{}},250);
  }
  function pointerMove(event){if(gesture?.kind!=='mouse'||event.pointerId!==gesture.id)return;const claimed=gesture.claimed;moveTo({x:event.clientX,y:event.clientY});if(claimed)swallow(event);}
  function pointerUp(event){if(gesture?.kind!=='mouse'||event.pointerId!==gesture.id)return;const claimed=gesture.claimed;finish(true);if(claimed)swallow(event);}
  function click(event){if(node.contains(event.target)&&performance.now()<suppressUntil&&event.detail!==0)swallow(event);}
  function key(event){if(event.key==='Escape'&&gesture?.claimed){swallow(event);cancel();}}
  function lost(event){if(gesture?.kind==='mouse'&&gesture.claimed&&event.pointerId===gesture.id)cancel();}
  function context(event){if(gesture?.claimed||performance.now()<suppressUntil){swallow(event);cancel();}}
  const options={capture:true,passive:false},events=presentation==='mobile'?{touchstart:touchStart,touchmove:touchMove,touchend:touchEnd,touchcancel:cancel}:{pointerdown:pointerDown};
  for(const [name,callback] of Object.entries({...events,contextmenu:context,lostpointercapture:lost,dragstart:context}))node.addEventListener(name,callback,options);
  window.addEventListener('click',click,true);window.addEventListener('dblclick',click,true);
  if(presentation!=='mobile'){window.addEventListener('pointermove',pointerMove,options);window.addEventListener('pointerup',pointerUp,options);window.addEventListener('pointercancel',cancel,options);}
  window.addEventListener('blur',cancel);window.addEventListener('resize',cancel);window.addEventListener('keydown',key,true);
  const hidden=()=>{if(document.hidden)cancel();};document.addEventListener('visibilitychange',hidden);
  const observer=new ResizeObserver(cancel);observer.observe(node);
  return()=>{cancel();observer.disconnect();for(const [name,callback] of Object.entries({...events,contextmenu:context,lostpointercapture:lost,dragstart:context}))node.removeEventListener(name,callback,options);window.removeEventListener('click',click,true);window.removeEventListener('dblclick',click,true);window.removeEventListener('pointermove',pointerMove,options);window.removeEventListener('pointerup',pointerUp,options);window.removeEventListener('pointercancel',cancel,options);window.removeEventListener('blur',cancel);window.removeEventListener('resize',cancel);window.removeEventListener('keydown',key,true);document.removeEventListener('visibilitychange',hidden);};
 },[root,enabled,identity,presentation]);
}
