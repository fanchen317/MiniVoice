import {projectWallFrame} from './wallProjection.js';
import {WALL_EXPANSION_MS} from './wallMotion.js';
import {useActivationFeedback,emitActivationFeedback} from './components/FeedbackContext.jsx';
import ActionButton from './components/ActionButton.jsx';
import React,{forwardRef,useEffect,useLayoutEffect,useImperativeHandle,useMemo,useRef,useState} from 'react';
import Artwork from './Artwork.jsx';
import {createScene,visibleReflowTiles,nearestInstance,nearestRenderedInstance,playingInstance,reflowFrame,focusProgress} from './wallGeometry.js';
import {clampZoom,mobileWallViewport,mixRect,initialWallCamera} from './wallLayout.js';
// Keep mounted coverage beyond the 140px camera refresh threshold, including
// focus transitions; a smaller window exposes gaps before React mounts posters.
const WALL_OVERSCAN=360;
const NATIVE_SCROLL_EXTENT=16384,NATIVE_SCROLL_ANCHOR=8192;
const reduced=()=>matchMedia('(prefers-reduced-motion:reduce)').matches||document.documentElement.classList.contains('reduce-motion');
const safeCamera=initialWallCamera;
// Stable values must not dirty layout on every camera frame.
function writeStyle(node,key,value){if(node.style[key]!==value)node.style[key]=value;}
// Never reveal a replacement cover before its pixels are decoded. The
// retained poster below owns the image until this layer can take over.
function FocusArtwork({src,preview,shouldDefer,smoothUpgrade=false}){
 const [shown,setShown]=useState(null),[revealed,setRevealed]=useState([]),requested=useRef(src),revealFrame=useRef(0);requested.current=src;
 useEffect(()=>()=>clearTimeout(revealFrame.current),[]);
 const sources=[...new Set((smoothUpgrade?[preview,...revealed,shown,src]:[shown,preview,src]).filter(Boolean))];
 return sources.map(source=><Artwork key={source} className="mv-wall-focused-art" src={source} draggable={false} style={smoothUpgrade?{visibility:'visible',opacity:source===preview||revealed.includes(source)||shown===source?1:0,zIndex:source===preview?0:1,transition:reduced()?'none':'opacity 180ms ease-out'}:{visibility:shown===source?'visible':'hidden'}} onLoad={async event=>{
  const node=event.currentTarget;
  try{await node.decode();}catch{return;}
  const reveal=()=>{if(!node.isConnected||requested.current!==source)return;if(source!==preview&&shouldDefer?.()){revealFrame.current=setTimeout(reveal,80);return;}if(smoothUpgrade)setRevealed(previous=>[...previous.filter(value=>value!==source),source].slice(-3));setShown(source);};
  if(source===requested.current){clearTimeout(revealFrame.current);reveal();}
  else if(source===preview&&node.isConnected){setShown(previous=>previous||source);}
 }}/>);
}
/** A full-surface wall. Camera, focus reflow and expansion have distinct ownership. */
export default forwardRef(function Wall({nativeScrolling=false,items,current,playingId=current,playing=false,page,onCamera,onScale,onSelect,onDoubleSelect,onContext,focused,expanded=false,blocked=false,recessed=false,focusContent,location=0,locationId=null,loading=false,grouped=false},api){
 const activateFeedback=useActivationFeedback();
 const touchPress=useRef(null);
 function clearTouchPress(){const press=touchPress.current;if(press)press.node.classList.remove("is-touch-pressed");touchPress.current=null;}
 function startTouchPress(event){clearTouchPress();if(event.touches.length!==1||blocked||expanded)return;const node=event.target.closest(".mv-wall-card,.mv-wall-focused");if(!node||event.target.closest(".mv-wall-focused button,[role=slider]"))return;const point=event.touches[0];touchPress.current={node,x:point.clientX,y:point.clientY};node.classList.add("is-touch-pressed");}
 function moveTouchPress(event){const press=touchPress.current,point=event.touches[0];if(press&&(event.touches.length!==1||!point||Math.hypot(point.clientX-press.x,point.clientY-press.y)>8))clearTouchPress();}
 useEffect(()=>{window.addEventListener('blur',clearTouchPress);const hidden=()=>{if(document.hidden)clearTouchPress();};document.addEventListener('visibilitychange',hidden);return()=>{clearTouchPress();window.removeEventListener('blur',clearTouchPress);document.removeEventListener('visibilitychange',hidden);};},[]);
 useEffect(()=>{if(blocked||expanded)clearTouchPress();},[blocked,expanded]);
 const view=useRef(null),scene=useMemo(()=>createScene(items.length),[items.length]);
 const [viewport,setViewport]=useState(()=>mobileWallViewport(0,0)),[cameraSnapshot,setCamera]=useState(()=>safeCamera(page.camera)),[focus,setFocus]=useState(null),[progress,setProgress]=useState(1),[expansion,setExpansion]=useState(expanded?1:0);
 const live=useRef(cameraSnapshot),latest=useRef({}),motion=useRef(0),focusMotion=useRef(0),focusCamera=useRef(false),expandMotion=useRef(0),saveTimer=useRef(null),hold=useRef(null),pointers=useRef(new Map()),gesture=useRef(null),lastTap=useRef(null),opened=useRef(0),transition=useRef(null),focusSide=useRef(320),restored=useRef(false),handledLocation=useRef(null),oldViewport=useRef(null);
 const plane=useRef(null),focusedNode=useRef(null),posterNodes=useRef(new Map()),paintFrame=useRef(0),mountedCamera=useRef(cameraSnapshot),progressValue=useRef(1),expansionValue=useRef(expanded?1:0),renderedCells=useRef([]),paintedScale=useRef(null),pendingMount=useRef(false),suppressedClick=useRef(null);
 const depth=useRef(1),depthMotion=useRef(0),paintedPosters=useRef(null),paintedFocus=useRef(null);
 // Scrolling changes the viewport without moving poster DOM nodes.
 // Rebase document coordinates only near the fixed scroll-document boundary.
 const nativeTap=useRef(null),nativePinchBoxes=useRef(new Map()),nativePinchContent=useRef(null),nativePinching=useRef(false),nativeTouch=useRef(false),nativeWrite=useRef(true),nativeOrigin=useRef(null),nativeRequested=useRef(null),nativeScrollTimer=useRef(0),nativeMoving=useRef(false);
 const planeGuard=0;
 function displayCamera(){const c=live.current,v=latest.current.viewport||viewport,s=depth.current;return {scale:c.scale*s,x:v.width/2+(c.x-v.width/2)*s,y:v.height/2+(c.y-v.height/2)*s};}
 const camera=displayCamera();
 latest.current={playingId,blocked,items,scene,viewport,focus,progress:progressValue.current,focused,expanded,expansion:expansionValue.current,current,onCamera,onScale,onSelect,onDoubleSelect,onContext};
 function rasterRect(r){if(!nativeScrolling)return r;const d=devicePixelRatio||1,x=Math.round(r.x*d)/d,y=Math.round(r.y*d)/d;return {x,y,width:Math.round((r.x+r.width)*d)/d-x,height:Math.round((r.y+r.height)*d)/d-y};}
 function paint(){
  if(!view.current||!plane.current)return;
  const state=latest.current,c=displayCamera();
  // Snapshot scroll geometry before poster writes to avoid a forced layout
  // when the focus surface is positioned later in this frame.
  let scrollX=0,scrollY=0;
  if(nativeScrolling&&view.current){
   const node=view.current;
   let origin=nativeOrigin.current;
   if(!origin||(!nativeMoving.current||nativeWrite.current)&&(origin.x-live.current.x<1024||origin.y-live.current.y<1024||origin.x-live.current.x>NATIVE_SCROLL_EXTENT-state.viewport.width-1024||origin.y-live.current.y>NATIVE_SCROLL_EXTENT-state.viewport.height-1024)){origin={x:NATIVE_SCROLL_ANCHOR+live.current.x,y:NATIVE_SCROLL_ANCHOR+live.current.y,scale:c.scale};nativeOrigin.current=origin;nativeWrite.current=true;}
   if(origin.scale!==c.scale){origin={...origin,scale:c.scale};nativeOrigin.current=origin;}
   const left=origin.x-live.current.x,top=origin.y-live.current.y;
   let wrote=false;
   if(nativeWrite.current&&Math.abs(node.scrollLeft-left)>.5){node.scrollLeft=left;wrote=true;}
   if(nativeWrite.current&&Math.abs(node.scrollTop-top)>.5){node.scrollTop=top;wrote=true;}
   scrollX=node.scrollLeft;scrollY=node.scrollTop;
   if(wrote)nativeRequested.current={x:scrollX,y:scrollY};nativeWrite.current=false;
  }
  // Project visible cells into the viewport. A promoted world-sized plane can
  // lose its entire raster during Android WebView reflow and texture eviction.
  const base=nativeScrolling?nativeOrigin.current:c,gpuPan=nativeScrolling&&state.progress>=1&&state.expansion===0&&depth.current===1&&c.scale===base.scale;
  const projection=gpuPan?base:nativeScrolling?{...c,x:c.x+scrollX,y:c.y+scrollY}:c;
  if(plane.current){plane.current.dataset.camera=JSON.stringify(live.current);plane.current.dataset.displayCamera=JSON.stringify(c);writeStyle(plane.current,'transform','none');if(plane.current.dataset.compositedPan!==String(gpuPan))plane.current.dataset.compositedPan=String(gpuPan);}
  if(paintedScale.current!==c.scale){paintedScale.current=c.scale;if(view.current)view.current.dataset.wallScale=String(c.scale);plane.current?.style.setProperty('--wall-camera-scale',String(c.scale));}
  if(!gpuPan||paintedPosters.current!==base){for(const cell of renderedCells.current){const node=posterNodes.current.get(cell.id);if(!node)continue;const r=rasterRect(projectWallFrame(frameFor(cell),projection,planeGuard));let target=nativeScrolling&&state.progress<1?projectWallFrame(frameFor(cell,true),projection,planeGuard):r;
   if(nativeScrolling&&depth.current!==1&&state.progress>=1)target={width:r.width/depth.current,height:r.height/depth.current};

   const transform=nativeScrolling&&(state.progress<1||depth.current!==1)?`translate(${r.x}px,${r.y}px) scale(${r.width/target.width},${r.height/target.height})`:`translate(${r.x}px,${r.y}px)`;
   writeStyle(node,'transformOrigin','0 0');writeStyle(node,'willChange','auto');if(node.style.transform!==transform)node.style.transform=transform;const width=`${target.width}px`,height=`${target.height}px`;if(node.style.width!==width)node.style.width=width;if(node.style.height!==height)node.style.height=height;}paintedPosters.current=gpuPan?base:null;}
  const cell=state.focus||(state.progress<1?transition.current?.previous:null),node=focusedNode.current;
  if(gpuPan&&paintedFocus.current?.base===base&&paintedFocus.current?.cell===cell&&paintedFocus.current?.node===node)return;
  paintedFocus.current=gpuPan?{base,cell,node}:null;
  if(cell&&node){const f=frameFor(cell),normal=projectWallFrame(f,projection,planeGuard),r=mixRect(normal,{x:nativeScrolling?scrollX:planeGuard,y:nativeScrolling?scrollY:planeGuard,width:state.viewport.width,height:state.viewport.height},state.expansion);writeStyle(node,'left','0px');writeStyle(node,'top','0px');writeStyle(node,'transform',`translate3d(${r.x}px,${r.y}px,0)`);writeStyle(node,'width',`${r.width}px`);writeStyle(node,'height',`${r.height}px`);const opacity=String(state.focus?state.progress:1-state.progress);if(node.style.getPropertyValue('--wall-surface-opacity')!==opacity)node.style.setProperty('--wall-surface-opacity',opacity);const content=node.querySelector('.mv-wall-focus-content');if(content){writeStyle(content,'opacity',String(state.focus?Math.min(1,Math.max(0,(state.progress-.15)/.85)):1-state.progress));
    writeStyle(content,'transform','none');if(nativeScrolling||state.progress>=1&&state.expansion===0&&!state.expanded){writeStyle(content,'width',`${r.width}px`);writeStyle(content,'height',`${r.height}px`);}
   }}
 }
 function flushPaint(){cancelAnimationFrame(paintFrame.current);paintFrame.current=0;paint();if(pendingMount.current){pendingMount.current=false;const next=live.current;mountedCamera.current={...next};setCamera({...next});latest.current.onScale?.(next.scale);}}
 function schedulePaint(){if(paintFrame.current)return;paintFrame.current=requestAnimationFrame(flushPaint);}

 useLayoutEffect(()=>{paintedPosters.current=null;paintedFocus.current=null;paint();},[cameraSnapshot,viewport,focus,progress,expansion,items,playingId]);
 useEffect(()=>()=>cancelAnimationFrame(paintFrame.current),[]);

 function stop(){focusCamera.current=false;cancelAnimationFrame(motion.current);motion.current=0;clearTimeout(saveTimer.current);}

 function save(commit=true){if(commit!==false)update({...live.current},true);const state=latest.current,cell=state.focus;state.onCamera?.({...live.current,focus:cell?{songId:state.items[cell.index]?.id,column:cell.column,row:cell.row}:null});}
 function scheduleSave(){clearTimeout(saveTimer.current);saveTimer.current=setTimeout(save,180);}
 function update(next,force=false,fromScroll=false){if(nativeScrolling&&!fromScroll&&(next.x!==live.current.x||next.y!==live.current.y||next.scale!==live.current.scale)){if(nativePinching.current&&view.current){nativeOrigin.current={x:next.x+view.current.scrollLeft,y:next.y+view.current.scrollTop,scale:next.scale};nativeWrite.current=false;}else nativeWrite.current=true;}live.current=next;schedulePaint();const previous=mountedCamera.current;if(force||Math.abs(next.x-previous.x)>140||Math.abs(next.y-previous.y)>140||Math.abs(next.scale-previous.scale)>(nativeScrolling?.001:.06)){if(force){pendingMount.current=false;mountedCamera.current={...next};setCamera({...next});latest.current.onScale?.(next.scale);}else pendingMount.current=true;}}
 function frameFor(cell,final=false){const state=latest.current,tween=transition.current,side=Math.max(Math.min(focusSide.current,state.viewport.side/Math.max(1,live.current.scale)),Math.min(240,state.viewport.side)/live.current.scale),target=targetFrame(cell,state.focus,side,tween);if(final||!tween||state.progress>=1)return target;const from=tween.frames.get(cell.id)||reflowFrame(cell,tween.layout?.focus,tween.layout?.size||{width:side,height:side});return mixRect(from,target,state.progress);}
 // Reflow targets stay fixed during a click transition; only interpolation changes.
 // Invalidate on focus/size changes so interrupted gestures use the latest geometry.
 function targetFrame(cell,focus,side,tween){if(!tween)return reflowFrame(cell,focus,{width:side,height:side});if(tween.targets?.focus!==focus||tween.targets?.side!==side)tween.targets={focus,side,frames:new Map()};const frames=tween.targets.frames;if(!frames.has(cell.id))frames.set(cell.id,reflowFrame(cell,focus,{width:side,height:side}));return frames.get(cell.id);}
 function focusSize(){const state=latest.current,side=Math.max(Math.min(focusSide.current,state.viewport.side/Math.max(1,live.current.scale)),Math.min(240,state.viewport.side)/live.current.scale);return {width:side,height:side};}
 function visibleScene(overscan=WALL_OVERSCAN){const state=latest.current;const cells=visibleReflowTiles(state.scene,displayCamera(),state.viewport,state.focus,focusSize(),overscan,transition.current?.layout),retained=transition.current?.cells;
  // A replacement animation starts at the *rendered* intermediate layout, not
  // the previous target. Keep those loaded posters until the handoff finishes.
  if(retained){const ids=new Set(cells.map(cell=>cell.id));for(const cell of retained)if(!ids.has(cell.id)){cells.push(cell);ids.add(cell.id);}}return cells;}
 function transitionCells(){return [...new Map([...renderedCells.current,...visibleScene(WALL_OVERSCAN)].map(cell=>[cell.id,cell])).values()];}
 function captureFrames(){const state=latest.current,cells=transitionCells();if(state.focus&&!cells.some(cell=>cell.id===state.focus.id))cells.push(state.focus);return new Map(cells.map(cell=>[cell.id,frameFor(cell)]));}
 function focusCell(cell,{animate=true,move=true}={}){
  if(!cell)return;stop();cancelAnimationFrame(focusMotion.current);focusCamera.current=move;const state=latest.current,old=live.current,cells=transitionCells(),frames=captureFrames();transition.current={cells,frames,previous:state.focus,layout:{focus:state.focus,size:focusSize()}};focusSide.current=state.viewport.side;setFocus(cell);latest.current.focus=cell;progressValue.current=0;setProgress(0);latest.current.progress=0;
  const target={...old,x:state.viewport.x-(cell.x+cell.width/2)*old.scale,y:state.viewport.y-(cell.y+cell.height/2)*old.scale},start=performance.now(),duration=animate&&!reduced()?520:0;
  const tick=now=>{const t=duration?Math.min(1,(now-start)/duration):1,e=focusProgress(t);latest.current.progress=e;progressValue.current=e;schedulePaint();if(move&&focusCamera.current)update({...old,x:old.x+(target.x-old.x)*e,y:old.y+(target.y-old.y)*e});if(nativeScrolling)flushPaint();if(t<1)focusMotion.current=requestAnimationFrame(tick);else{focusMotion.current=0;focusCamera.current=false;progressValue.current=1;setProgress(1);update({...live.current},true);transition.current=null;save();}};
  tick(start);
 }
 function clearFocus(){const state=latest.current;if(!state.focus)return;stop();cancelAnimationFrame(focusMotion.current);transition.current={cells:transitionCells(),frames:captureFrames(),previous:state.focus,layout:{focus:state.focus,size:focusSize()}};setFocus(null);latest.current.focus=null;progressValue.current=0;setProgress(0);latest.current.progress=0;const start=performance.now();const tick=now=>{const t=reduced()?1:Math.min(1,(now-start)/300),e=focusProgress(t);latest.current.progress=e;progressValue.current=e;schedulePaint();if(t<1)focusMotion.current=requestAnimationFrame(tick);else{focusMotion.current=0;focusCamera.current=false;progressValue.current=1;setProgress(1);update({...live.current},true);transition.current=null;save();}};tick(start);}
 function zoomAt(value,x,y){stop();const old=live.current,scale=clampZoom(value);latest.current.onScale?.(scale);update({scale,x:x-(x-old.x)*scale/old.scale,y:y-(y-old.y)*scale/old.scale});scheduleSave();}
 function revealCurrent(animate=true,allowRestore=false){const state=latest.current,index=state.items.findIndex(item=>item.id===state.current);if(index<0||!state.viewport.width)return false;let preserve=false,cell=state.focus&&state.items[state.focus.index]?.id===state.current?state.focus:null;
  if(cell){const rect=frameFor(cell),camera=live.current;if(rect.x*camera.scale+camera.x>state.viewport.width||(rect.x+rect.width)*camera.scale+camera.x<0||rect.y*camera.scale+camera.y>state.viewport.height||(rect.y+rect.height)*camera.scale+camera.y<0)cell=null;}
  const saved=page.camera?.focus;if(allowRestore&&!restored.current&&saved?.songId===state.current){const tile=state.scene.tiles[index],column=Number.isInteger(saved.column)?saved.column:0,row=Number.isInteger(saved.row)?saved.row:0;preserve=true;cell={...tile,id:`${index}:${column}:${row}`,column,row,x:tile.x+column*state.scene.world.width,y:tile.y+row*state.scene.world.height};}
  if(!cell){cell=nearestRenderedInstance(state.scene,index,live.current,{width:state.viewport.x*2,height:state.viewport.y*2},cell=>frameFor(cell));}restored.current=true;
  if(state.expanded){stop();cancelAnimationFrame(focusMotion.current);transition.current=null;focusSide.current=state.viewport.side;setFocus(cell);latest.current.focus=cell;progressValue.current=1;latest.current.progress=1;setProgress(1);schedulePaint();return true;}
  focusCell(cell,{animate,move:!preserve});return true;
 }
 useImperativeHandle(api,()=>({interrupt:()=>{stop();cancelGesture();lastTap.current=null;},zoomTo:value=>{const state=latest.current;zoomAt(value,state.viewport.x,state.viewport.y);},reset:()=>{stop();cancelAnimationFrame(focusMotion.current);transition.current=null;setFocus(null);latest.current.focus=null;progressValue.current=1;setProgress(1);latest.current.progress=1;update({x:12,y:80,scale:1});save();},locate:()=>revealCurrent(true),camera:()=>({...live.current}),backdrop:()=>{const state=latest.current,camera=displayCamera();return visibleScene(220).map(cell=>{const r=frameFor(cell);return {id:cell.id,artwork:state.items[cell.index]?.artworkWall||state.items[cell.index]?.artwork,x:camera.x+r.x*camera.scale,y:camera.y+r.y*camera.scale,width:r.width*camera.scale,height:r.height*camera.scale};});}}),[]);
 useLayoutEffect(()=>{const from=depth.current,to=recessed?.92:1,start=performance.now();cancelAnimationFrame(depthMotion.current);const tick=now=>{const t=reduced()||document.documentElement.classList.contains('reduce-motion')?1:Math.min(1,(now-start)/320);depth.current=from+(to-from)*focusProgress(t);schedulePaint();if(t<1)depthMotion.current=requestAnimationFrame(tick);else setCamera({...live.current});};tick(start);return()=>cancelAnimationFrame(depthMotion.current);},[recessed]);
 // Android densities produce fractional CSS bounds; clientWidth/clientHeight would leave a raster seam.
 useEffect(()=>{const element=view.current;const measure=()=>{const style=getComputedStyle(document.documentElement),safe={};for(const name of ['top','bottom','left','right'])safe[name]=parseFloat(style.getPropertyValue(`--mv-safe-${name}`))||0;const bounds=getComputedStyle(element);const next=mobileWallViewport(parseFloat(bounds.width),parseFloat(bounds.height),safe);setViewport(previous=>JSON.stringify(previous)===JSON.stringify(next)?previous:next);};const observer=new ResizeObserver(measure);observer.observe(element);window.addEventListener('minivoice-insets',measure);window.addEventListener('minivoice-flush',save);measure();return()=>{observer.disconnect();window.removeEventListener('minivoice-insets',measure);window.removeEventListener('minivoice-flush',save);stop();clearTimeout(hold.current);cancelAnimationFrame(expandMotion.current);cancelAnimationFrame(focusMotion.current);save(false);cancelAnimationFrame(paintFrame.current);};},[]);
 useEffect(()=>{if(!viewport.width)return;const state=latest.current;if(focused){const valid=state.focus&&items[state.focus.index]?.id===current;if(!valid)revealCurrent(restored.current||page.camera?.focus?.songId!==current,true);}else if(state.focus)clearFocus();},[items,current,focused,viewport.width>0]);
 useEffect(()=>{const before=oldViewport.current;oldViewport.current=viewport;if(before?.width&&latest.current.focus&&focused)focusCell(latest.current.focus,{animate:false});},[viewport.width,viewport.height,viewport.x,viewport.y,viewport.side]);
 // Consume a request only after its song and viewport are ready. Playback
 // navigation can deliver the token before focus/items in a later render.
 useEffect(()=>{if(location&&focused&&!expanded&&expansion===0&&(!locationId||current===locationId)&&handledLocation.current!==location&&revealCurrent(true))handledLocation.current=location;},[location,locationId,focused,expanded,expansion,current,items,viewport.width,viewport.height]);
 useLayoutEffect(()=>{cancelAnimationFrame(expandMotion.current);if(!nativeScrolling&&!expanded&&expansionValue.current>0&&latest.current.focus)focusCell(latest.current.focus,{animate:false});const start=performance.now(),from=latest.current.expansion,to=expanded?1:0;const tick=now=>{const t=reduced()?1:Math.min(1,(now-start)/WALL_EXPANSION_MS),next=from+(to-from)*focusProgress(t);latest.current.expansion=next;expansionValue.current=next;if(nativeScrolling)setExpansion(next);schedulePaint();if(t===1){expandMotion.current=0;setExpansion(next);}if(t<1)expandMotion.current=requestAnimationFrame(tick);};tick(start);return()=>cancelAnimationFrame(expandMotion.current);},[expanded]);
 useEffect(()=>{const element=view.current,wheel=event=>{if(latest.current.expansion>0||event.target.closest('.mv-wall-focused'))return;event.preventDefault();const rect=element.getBoundingClientRect();if(event.ctrlKey||event.metaKey)zoomAt(live.current.scale*Math.exp(-event.deltaY*.003),event.clientX-rect.left,event.clientY-rect.top);else{stop();update({...live.current,x:live.current.x-event.deltaX,y:live.current.y-event.deltaY});scheduleSave();}};element.addEventListener('wheel',wheel,{passive:false});return()=>element.removeEventListener('wheel',wheel);},[]);
 useEffect(()=>{
  if(!nativeScrolling)return;const node=view.current;let pinch=null;
  const scroll=()=>{if(nativePinching.current)return;const origin=nativeOrigin.current;if(!origin)return;const requested=nativeRequested.current;
   if(requested&&Math.abs(requested.x-node.scrollLeft)<.01&&Math.abs(requested.y-node.scrollTop)<.01){nativeRequested.current=null;return;}nativeRequested.current=null;if(focusCamera.current&&!nativeTouch.current)return;const next={...live.current,x:origin.x-node.scrollLeft,y:origin.y-node.scrollTop};
   if(Math.abs(next.x-live.current.x)>.5||Math.abs(next.y-live.current.y)>.5){stop();nativeMoving.current=true;lastTap.current=null;update(next,false,true);scheduleSave();}
   clearTimeout(nativeScrollTimer.current);nativeScrollTimer.current=setTimeout(()=>{nativeMoving.current=false;schedulePaint();},180);
  };
  const start=event=>{if(latest.current.expanded||latest.current.blocked)return;nativeTouch.current=true;if(event.touches.length!==2)return;stop();lastTap.current=null;nativePinchBoxes.current=new Map([...posterNodes.current].map(([id,poster])=>[id,{width:parseFloat(poster.style.width)||1,height:parseFloat(poster.style.height)||1}]));const content=focusedNode.current?.querySelector('.mv-wall-focus-content');nativePinchContent.current=content?{width:parseFloat(content.style.width)||1,height:parseFloat(content.style.height)||1,compact:live.current.scale<.7}:null;nativePinching.current=true;node.dataset.nativePinching='true';event.preventDefault();const origin=nativeOrigin.current;if(origin)live.current={...live.current,x:origin.x-node.scrollLeft,y:origin.y-node.scrollTop};const [a,b]=event.touches,r=node.getBoundingClientRect();pinch={camera:{...live.current},distance:Math.hypot(a.clientX-b.clientX,a.clientY-b.clientY),x:(a.clientX+b.clientX)/2-r.left,y:(a.clientY+b.clientY)/2-r.top};};
  const move=event=>{if(!nativePinching.current||!pinch||event.touches.length!==2)return;event.preventDefault();const [a,b]=event.touches,r=node.getBoundingClientRect(),x=(a.clientX+b.clientX)/2-r.left,y=(a.clientY+b.clientY)/2-r.top,scale=clampZoom(pinch.camera.scale*Math.hypot(a.clientX-b.clientX,a.clientY-b.clientY)/Math.max(1,pinch.distance));latest.current.onScale?.(scale);update({scale,x:x-(pinch.x-pinch.camera.x)*scale/pinch.camera.scale,y:y-(pinch.y-pinch.camera.y)*scale/pinch.camera.scale});scheduleSave();};
  const end=event=>{if(event.type!=='touchcancel'&&event.touches.length)return;nativeTouch.current=false;nativePinching.current=false;if(pinch){paintedPosters.current=null;paintedFocus.current=null;paint();pinch=null;save();}nativePinchBoxes.current.clear();nativePinchContent.current=null;delete node.dataset.nativePinching;};
  const cancel=()=>end({type:'touchcancel',touches:[]}),hidden=()=>{if(document.hidden)cancel();};window.addEventListener('blur',cancel);document.addEventListener('visibilitychange',hidden);
  node.addEventListener('scroll',scroll,{passive:true});node.addEventListener('touchstart',start,{passive:false});node.addEventListener('touchmove',move,{passive:false});node.addEventListener('touchend',end);node.addEventListener('touchcancel',end);
  return()=>{window.removeEventListener('blur',cancel);document.removeEventListener('visibilitychange',hidden);clearTimeout(nativeScrollTimer.current);node.removeEventListener('scroll',scroll);node.removeEventListener('touchstart',start);node.removeEventListener('touchmove',move);node.removeEventListener('touchend',end);node.removeEventListener('touchcancel',end);nativePinching.current=false;nativeTouch.current=false;delete node.dataset.nativePinching;};
 },[nativeScrolling]);
 function cancelGesture(){clearTimeout(hold.current);const ids=[...pointers.current.keys()];pointers.current.clear();gesture.current=null;for(const id of ids)if(view.current?.hasPointerCapture(id))view.current.releasePointerCapture(id);if(view.current){delete view.current.dataset.dragging;delete view.current.dataset.mvDragging;}}
 useLayoutEffect(()=>{if(blocked){nativePinching.current=false;nativeTouch.current=false;if(view.current)delete view.current.dataset.nativePinching;stop();cancelGesture();suppressedClick.current=null;save();}},[blocked]);
 useEffect(()=>{const cancel=()=>{stop();cancelGesture();lastTap.current=null;};window.addEventListener('blur',cancel);const hidden=()=>{if(document.hidden)cancel();};document.addEventListener('visibilitychange',hidden);return()=>{window.removeEventListener('blur',cancel);document.removeEventListener('visibilitychange',hidden);cancelGesture();};},[]);
 function playDouble(event,x,y){
  const first=lastTap.current,now=performance.now();
  if(!first||grouped||now-first.time>320||Math.hypot(x-first.x,y-first.y)>24)return;
  const item=latest.current.items.find(item=>item.id===first.songId);lastTap.current=null;
  if(item&&latest.current.onDoubleSelect){nativeTouch.current=false;event.preventDefault();event.stopPropagation();latest.current.onDoubleSelect(item,event);}
 }
 function nativeClick(event){swallowDragClick(event);if(nativeScrolling&&!event.defaultPrevented&&event.detail!==0)playDouble(event,event.clientX,event.clientY);}
 function nativeTapStart(event){if(!nativeScrolling)return;const point=event.touches.length===1?event.touches[0]:null;nativeTap.current=point?{id:point.identifier,x:point.clientX,y:point.clientY,moved:false}:null;}
 function nativeTapMove(event){const tap=nativeTap.current,point=[...event.touches].find(point=>point.identifier===tap?.id);if(!tap)return;if(event.touches.length!==1||!point||Math.hypot(point.clientX-tap.x,point.clientY-tap.y)>8){if(!tap.moved){stop();nativeWrite.current=false;}tap.moved=true;lastTap.current=null;}}
 function nativeTapEnd(event){if(!nativeScrolling)return;const tap=nativeTap.current;nativeTap.current=null;const point=[...event.changedTouches].find(point=>point.identifier===tap?.id);if(tap&&!tap.moved&&point&&Math.hypot(point.clientX-tap.x,point.clientY-tap.y)<=8)playDouble(event,point.clientX,point.clientY);}
 function swallowDragClick(event){const value=suppressedClick.current;if(!value||performance.now()>value.until)return;if(event.detail===0&&!event.nativeEvent?.pointerType&&!event.nativeEvent?.sourceCapabilities?.firesTouchEvents&&event.clientX===0&&event.clientY===0)return;event.preventDefault();event.stopPropagation();suppressedClick.current=null;}

 function down(event){if(event.button!==0||latest.current.blocked||expanded||expansion>0||event.target.closest('[role=slider]'))return;stop();suppressedClick.current=null;clearTimeout(hold.current);const control=event.target.closest('.mv-wall-focused button');if(!control&&event.isTrusted)event.currentTarget.setPointerCapture(event.pointerId);pointers.current.set(event.pointerId,{x:event.clientX,y:event.clientY});const points=[...pointers.current.values()],tile=event.target.closest('[data-wall-cell]'),id=tile?.dataset.wallCell;
  if(points.length===2){gesture.current={moved:true,pinched:true,pinch:{camera:live.current,distance:Math.hypot(points[0].x-points[1].x,points[0].y-points[1].y),x:(points[0].x+points[1].x)/2,y:(points[0].y+points[1].y)/2}};lastTap.current=null;return;}
  gesture.current={x:event.clientX,y:event.clientY,time:performance.now(),moved:false,vx:0,vy:0,cell:id,item:tile?.dataset.wallId,control:Boolean(control)};if(onContext&&tile&&!control)hold.current=setTimeout(()=>{const g=gesture.current;if(!g||g.moved)return;g.moved=true;opened.current=Date.now();lastTap.current=null;const item=latest.current.items.find(item=>item.id===g.item);if(item)latest.current.onContext?.(item);},500);
 }
 function move(event){if(!pointers.current.has(event.pointerId))return;const before=pointers.current.get(event.pointerId);pointers.current.set(event.pointerId,{x:event.clientX,y:event.clientY});const points=[...pointers.current.values()],g=gesture.current;if(!g)return;
  if(points.length===2&&g.pinch){clearTimeout(hold.current);const p=g.pinch,rect=view.current.getBoundingClientRect(),scale=clampZoom(p.camera.scale*Math.hypot(points[0].x-points[1].x,points[0].y-points[1].y)/Math.max(1,p.distance)),x=(points[0].x+points[1].x)/2-rect.left,y=(points[0].y+points[1].y)/2-rect.top;update({scale,x:x-(p.x-rect.left-p.camera.x)*scale/p.camera.scale,y:y-(p.y-rect.top-p.camera.y)*scale/p.camera.scale});return;}
  if(Math.hypot(event.clientX-g.x,event.clientY-g.y)>8){g.moved=true;clearTimeout(hold.current);lastTap.current=null;if(event.isTrusted&&(event.pointerType==='mouse'||!g.control))view.current?.setPointerCapture(event.pointerId);if(view.current){view.current.dataset.dragging='true';view.current.dataset.mvDragging='true';}}
  if(g.moved){const now=performance.now(),dt=Math.max(8,now-g.time);g.vx=(event.clientX-before.x)/dt;g.vy=(event.clientY-before.y)/dt;g.time=now;update({...live.current,x:live.current.x+event.clientX-before.x,y:live.current.y+event.clientY-before.y});}
 }
 function activate(cell,event){if(!cell)return;if(event?.isTrusted)emitActivationFeedback(activateFeedback);restored.current=true;const item=items[cell.index];if(grouped){onSelect(item,event);return;}if(latest.current.focus?.id!==cell.id)focusCell(cell);const now=performance.now(),double=lastTap.current?.id===cell.id&&now-lastTap.current.time<320;lastTap.current={id:cell.id,songId:item.id,x:event?.clientX,y:event?.clientY,time:now};if(!nativeScrolling&&double&&onDoubleSelect)onDoubleSelect(item,event);else onSelect(item,event);}
 function up(event){clearTimeout(hold.current);if(!pointers.current.has(event.pointerId))return;pointers.current.delete(event.pointerId);if(view.current?.hasPointerCapture(event.pointerId))view.current.releasePointerCapture(event.pointerId);const g=gesture.current;if(!g)return;
  if(pointers.current.size){const point=[...pointers.current.values()][0];gesture.current={...g,x:point.x,y:point.y,time:performance.now(),moved:true,pinched:true,pinch:null,vx:0,vy:0};return;}
  if(g.moved){suppressedClick.current={until:performance.now()+700};}if(view.current){delete view.current.dataset.dragging;delete view.current.dataset.mvDragging;}
  if(!g.moved&&g.cell&&!g.control){const cell=rendered.find(cell=>cell.id===g.cell);activate(cell,event);}else if(g.control&&!g.moved){gesture.current=null;return;}else if(!g.pinched&&performance.now()-g.time<100&&Math.hypot(g.vx,g.vy)>.1){const old=live.current,start=performance.now(),dx=Math.max(-800,Math.min(800,g.vx*200)),dy=Math.max(-800,Math.min(800,g.vy*200));const tick=now=>{const t=Math.min(1,(now-start)/420),e=1-(1-t)**3;update({...old,x:old.x+dx*e,y:old.y+dy*e});if(t<1)motion.current=requestAnimationFrame(tick);else{motion.current=0;save();}};motion.current=requestAnimationFrame(tick);}else save();gesture.current=null;
 }
 const displayFocus=focus||(progressValue.current<1?transition.current?.previous:null);
 // The mounted window must extend beyond the 140px rebase threshold. Keep its
 // identity across playback polling so a clock tick cannot rerasterize posters.
 const cells=useMemo(()=>visibleScene(WALL_OVERSCAN),[cameraSnapshot,viewport,focus,progress,expansion,items,nativeScrolling]);
 const rendered=useMemo(()=>displayFocus&&!cells.some(cell=>cell.id===displayFocus.id)?[...cells,displayFocus]:cells,[cells,displayFocus]);
 renderedCells.current=rendered;
 // Use the same document-space origin as paint and retained posters. Pairing
 // a sampled scroll offset with a later camera render makes focus wobble.
 const renderProjection=nativeScrolling&&progressValue.current>=1&&expansionValue.current===0&&depth.current===1&&nativeOrigin.current?nativeOrigin.current:nativeScrolling?{...camera,x:camera.x+(view.current?.scrollLeft??NATIVE_SCROLL_ANCHOR),y:camera.y+(view.current?.scrollTop??NATIVE_SCROLL_ANCHOR)}:camera;
 const focusRect=displayFocus?frameFor(displayFocus):null,normal=focusRect?projectWallFrame(focusRect,renderProjection,planeGuard):null;
 const finalFrame=displayFocus?frameFor(displayFocus,true):null,finalSize=nativeScrolling?mixRect({x:0,y:0,width:(finalFrame?.width||0)*camera.scale,height:(finalFrame?.height||0)*camera.scale},{x:0,y:0,width:viewport.width,height:viewport.height},expansionValue.current):nativePinching.current&&nativePinchContent.current?nativePinchContent.current:expanded?{width:viewport.width,height:viewport.height}:{width:(finalFrame?.width||0)*camera.scale,height:(finalFrame?.height||0)*camera.scale};
 const rect=normal?mixRect(normal,{x:nativeScrolling?(view.current?.scrollLeft??NATIVE_SCROLL_ANCHOR):planeGuard,y:nativeScrolling?(view.current?.scrollTop??NATIVE_SCROLL_ANCHOR):planeGuard,width:viewport.width,height:viewport.height},expansion):null,item=displayFocus?items[displayFocus.index]:null;
 const posterActions=useRef(null);posterActions.current={activate,onContext};
 const playingIndex=grouped?-1:items.findIndex(song=>song.id===playingId);
 const playingCell=playingInstance(scene,playingIndex,camera,{width:viewport.x*2,height:viewport.y*2},displayFocus);
 const posterCamera=nativeScrolling&&depth.current===1&&nativeOrigin.current?{...nativeOrigin.current,scale:camera.scale}:nativeScrolling?{...camera,x:camera.x+(view.current?.scrollLeft??NATIVE_SCROLL_ANCHOR),y:camera.y+(view.current?.scrollTop??NATIVE_SCROLL_ANCHOR)}:camera;
 const posters=useMemo(()=>rendered.map(cell=>{const song=items[cell.index],frame=projectWallFrame(frameFor(cell),posterCamera,planeGuard);return <ActionButton type="button" feedback="none" haptic={false} ref={node=>{if(node)posterNodes.current.set(cell.id,node);else posterNodes.current.delete(cell.id);}} className={`mv-wall-card ${cell.id===playingCell?.id?'active':''} ${cell.id===displayFocus?.id?'is-focus-underlay':''}`} aria-hidden={cell.id===displayFocus?.id||undefined} key={cell.id} data-wall-id={song.id} data-wall-cell={cell.id} style={{left:0,top:0,transform:`translate(${frame.x}px,${frame.y}px)`,width:frame.width,height:frame.height}} onContextMenu={event=>{event.preventDefault();clearTimeout(hold.current);if(gesture.current)gesture.current.moved=true;if(Date.now()-opened.current>250){opened.current=Date.now();posterActions.current.onContext?.(song);}}} onClick={event=>{if(nativeScrolling||event.detail===0)posterActions.current.activate(cell,event);}}><div className="mv-wall-press-surface">{(song.artworkWall||song.artwork)?<Artwork src={song.artworkWall||song.artwork} draggable={false}/>:<span className="mv-wall-placeholder">♫</span>}<div className="mv-wall-caption"><strong>{song.title}</strong><small>{song.artist||`${song.count} 首歌曲`}</small></div></div></ActionButton>;}),[rendered,items,playingId,displayFocus,cameraSnapshot,viewport,progress,expansion]);
 return <div ref={view} className={`mv-cover-wall ${playing?'is-playing':''} ${expansion>0?'is-expanding':''}`} aria-label="音乐墙" data-mv-component="wall" data-wall-renderer={nativeScrolling?'native-scroll-single-surface':'projected-single-surface'} data-wall-scale={camera.scale} data-wall-blocked={blocked||undefined} onClickCapture={nativeClick} onTouchStartCapture={event=>{startTouchPress(event);nativeTapStart(event);}} onTouchMoveCapture={event=>{moveTouchPress(event);nativeTapMove(event);}} onTouchEndCapture={event=>{clearTouchPress();nativeTapEnd(event);}} onTouchCancelCapture={()=>{clearTouchPress();nativeTap.current=null;lastTap.current=null;}} onPointerDown={nativeScrolling?undefined:down} onPointerMove={nativeScrolling?undefined:move} onPointerUp={nativeScrolling?undefined:up} onPointerCancel={cancelGesture} onLostPointerCapture={event=>{if(event.target===event.currentTarget&&pointers.current.has(event.pointerId))cancelGesture();}}>
  <div ref={plane} className="mv-wall-plane" data-native-scroll={nativeScrolling||undefined} data-camera={JSON.stringify(camera)} style={{'--wall-camera-scale':camera.scale,...(nativeScrolling?{width:NATIVE_SCROLL_EXTENT,height:NATIVE_SCROLL_EXTENT}:{} )}}>{posters}
  {rect&&item&&<section ref={focusedNode} className={`mv-wall-focused ${expanded?'is-expanded':''} ${item.id===playingId?'is-current':'is-preview'}`} onClick={event=>{if(nativeScrolling&&!event.target.closest('button,[role=slider]'))activate(displayFocus,event);}} aria-label="音乐墙播放卡片" data-wall-id={item.id} data-wall-cell={displayFocus.id} style={{left:0,top:0,transform:`translate3d(${rect.x}px,${rect.y}px,0)`,width:rect.width,height:rect.height,opacity:1,'--wall-surface-opacity':focus?progress:1-progress,'--wall-cover':item.artwork?`url("${item.artwork}")`:'none'}}><div className="mv-wall-press-surface"><FocusArtwork key={item.id} smoothUpgrade={nativeScrolling} preview={item.artworkWall||item.artwork} src={(expanded?item.artworkDetail:item.artworkCard)||item.artworkDetail||item.artwork} shouldDefer={()=>nativeMoving.current||pointers.current.size>0||!nativeScrolling&&(progressValue.current<1||expansionValue.current>0&&expansionValue.current<1)||motion.current!==0}/>{item.id===playingId&&<span className="mv-wall-current-outline" aria-hidden="true"/>}<div className="mv-wall-focus-content" style={{width:finalSize.width,height:finalSize.height,opacity:focus?Math.min(1,progress*2):1-progress}}>{focusContent(item,{width:finalSize.width,height:finalSize.height,compact:false,keepControls:true})}</div></div></section>}
  </div>
  {!items.length&&<div className="mv-wall-empty" role="status">{loading?<><span className="wp-loading"/>正在扫描音乐库…</>:'暂无歌曲，请在设置中添加音乐文件夹'}</div>}
 </div>;
});
