import {ArtworkModeScope,ArtworkBlur} from '../../../Shared/UI/src/components/ArtworkModeButton.jsx';
import {stableArtworkFocus,warmArtworkSubjects,copyArtworkPresentation} from '../../../Shared/UI/src/components/artworkFocus.js';
import {artworkViewport} from '../../../Shared/UI/src/components/artworkViewport.js';
import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import Slider from '../../../Shared/UI/src/components/Slider.jsx';
import {wallZoomStops,nextWallZoomStop} from './wallZoom';
import {usePopoverPosition} from './usePopoverPosition';
import { createPortal } from 'react-dom';
import {SortMenuItem} from './SortMenuItem';
import React, { memo, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { command,state as playbackState,artwork as artworkURL } from './store';
import { WallClickSequence } from './wallClick';
import { createScene, visibleTiles, wheelStep, releaseDistance, reflowFrame, focusProgress, reflowProgress, nearestInstance, nearestRenderedInstance, playingInstance, restoredPlayerCamera, wallFocusSide } from './wallGeometry';
import { Cover, Icon, WallCardPlayer } from './components';
import { springEasing,springProgress,posterArtworkMotion } from './motion';

const reflowEasing=`linear(${Array.from({length:53},(_,i)=>`${reflowProgress(i*10).toFixed(5)} ${(i/52*100).toFixed(2)}%`).join(',')})`;
function imageCoordinateSpace(image){try{return new URL(image.currentSrc||image.src,location.href).hostname==='detail'?'original':'preview';}catch{return 'preview';}}
const Poster = memo(function Poster({ tile, track, onFocus, focused, playing, onMenu,onPlay,onExpand,expanded,transitioning,reduceMotion,visible,onReveal,grouped,onGroupMenu,displayScale=1 }) {
  const cropDecisions=useRef(new Map());
  const element=useRef(),previous=useRef(),animation=useRef(),artwork=useRef(),artworkAnimation=useRef(),blurAnimation=useRef(),artworkTransition=useRef(null),settleFrame=useRef(0),latest=useRef(null),previousAnalysis=useRef(0),pendingFocusTransition=useRef(false);
  latest.current={tile,track,expanded,displayScale};
  const [analysisRevision,setAnalysisRevision]=useState(0);
  function targetViewport(){
    const state=latest.current,node=element.current,surface=node?.closest('.wall-surface');
    const target=artworkViewport({width:surface?.clientWidth||state.tile.width,height:surface?.clientHeight||state.tile.height});
    return target;
  }
  // Planning always targets the final wall surface, not an interpolated card or
  // physical screen dimensions. A windowed/fullscreen app can use either display.
  useEffect(()=>{
    let active=true;const surface=element.current?.closest('.wall-surface');
    if(focused&&surface){const viewport=artworkViewport({width:surface.clientWidth,height:surface.clientHeight});warmArtworkSubjects(artworkURL(track,false),context=>command('artworkSubjects',{id:track.id,viewport:context},{reportError:false}),viewport).then(()=>{if(active)setAnalysisRevision(value=>value+1);});}
    return()=>{active=false;};
  },[focused,expanded,track.id,track.artworkRevision,tile.width,tile.height,displayScale]);
  function presentArtwork(image=artwork.current?.querySelector('img.cover'),{animateFocus=false}={}){
    if(!image?.naturalWidth||!image.naturalHeight)return;
    const oldTransform=animateFocus?getComputedStyle(image).transform:null;
    const state=latest.current,focal=stableArtworkFocus(image,{key:artworkURL(state.track,false),viewport:targetViewport(),coordinateSpace:imageCoordinateSpace(image),useSubjects:true},cropDecisions.current),transition=artworkTransition.current,parent=animation.current;
    const running=transition&&parent?.playState==='running',motion=running?posterArtworkMotion(transition.from,state.tile,image.naturalWidth/image.naturalHeight,transition.progressAt,transition.samples,focal,transition.fromFocal):posterArtworkMotion(state.tile,state.tile,image.naturalWidth/image.naturalHeight,p=>p,2,focal);
    artworkAnimation.current?.cancel();blurAnimation.current?.cancel();artworkAnimation.current=null;blurAnimation.current=null;
    image.style.left='0';image.style.top='0';image.style.transformOrigin='0 0';image.style.width=`${motion.width}px`;image.style.height=`${motion.height}px`;image.style.transform=motion.frames.at(-1).transform;
    const blur=artwork.current?.querySelector('.mv-artwork-blur');copyArtworkPresentation(image,blur);
    if(!running&&animateFocus&&!reduceMotion&&oldTransform&&oldTransform!=='none'){
      const frames=[{transform:oldTransform},{transform:motion.frames.at(-1).transform}];artworkAnimation.current=image.animate(frames,{duration:240,easing:'cubic-bezier(.2,.8,.2,1)'});if(blur)blurAnimation.current=blur.animate(frames,{duration:240,easing:'cubic-bezier(.2,.8,.2,1)'});
    }
    if(running){
      // Original pixels may decode halfway through a FLIP. Rebuild their aspect
      // compensation at the parent's exact current time instead of dropping load.
      artworkAnimation.current=image.animate(motion.frames,{duration:transition.duration,easing:'linear'});artworkAnimation.current.currentTime=parent.currentTime;
      if(blur){blurAnimation.current=blur.animate(motion.frames,{duration:transition.duration,easing:'linear'});blurAnimation.current.currentTime=parent.currentTime;}
    }
  }
  function settleArtwork(){cancelAnimationFrame(settleFrame.current);settleFrame.current=requestAnimationFrame(()=>{settleFrame.current=0;const animateFocus=pendingFocusTransition.current;pendingFocusTransition.current=false;presentArtwork(undefined,{animateFocus});});}
  useLayoutEffect(()=>{
    const before=previous.current;previous.current=tile;const analysisChanged=previousAnalysis.current!==analysisRevision;previousAnalysis.current=analysisRevision;
    const node=element.current,matrix=new DOMMatrix(getComputedStyle(node).transform),image=artwork.current?.querySelector('img.cover');
    const fromFocal={x:Number(image?.dataset.focalX??.5),y:Number(image?.dataset.focalY??.5)};
    const changed=before&&Math.abs(before.x-tile.x)+Math.abs(before.y-tile.y)+Math.abs(before.width-tile.width)+Math.abs(before.height-tile.height)>=.01;
    if(!changed&&!reduceMotion){if(analysisChanged&&animation.current?.playState==='running')pendingFocusTransition.current=true;else presentArtwork(undefined,{animateFocus:analysisChanged});return;}
    const from=before&&(animation.current?{x:matrix.e,y:matrix.f,width:before.width*matrix.a,height:before.height*matrix.d}:before);
    animation.current?.cancel();artworkAnimation.current?.cancel();blurAnimation.current?.cancel();animation.current=null;artworkTransition.current=null;
    if(!before||reduceMotion){presentArtwork();return;}
    node.style.willChange='transform';
    const duration=transitioning?600:520,progressAt=p=>transitioning?focusProgress(p):reflowProgress(p*520),samples=transitioning?61:53;
    const current=node.animate([{transform:`translate3d(${from.x}px,${from.y}px,0) scale(${from.width/tile.width},${from.height/tile.height})`},{transform:`translate3d(${tile.x}px,${tile.y}px,0) scale(1,1)`}],{duration,easing:transitioning?'cubic-bezier(.22,1,.36,1)':reflowEasing});
    animation.current=current;artworkTransition.current={from,duration,progressAt,samples,fromFocal};presentArtwork();
    current.finished.catch(()=>{}).finally(()=>{if(animation.current===current){animation.current=null;artworkTransition.current=null;node.style.willChange='';settleArtwork();}});
  },[tile.x,tile.y,tile.width,tile.height,reduceMotion,expanded,analysisRevision]);
  useEffect(()=>()=>{cancelAnimationFrame(settleFrame.current);animation.current?.cancel();artworkAnimation.current?.cancel();blurAnimation.current?.cancel();},[]);
  return <ArtworkModeScope as="article" ref={element} className={`wall-poster ${focused?'focused':''} ${playing?'playing':''}`}
    style={{'--artwork-cover':`url("${artworkURL(track,expanded&&focused)}")`,'--caption-inset':`${Math.min(14,Math.max(8,tile.width*.06))}px`,'--poster-title':`${Math.min(30,Math.max(18,tile.width*.105))}px`,'--poster-subtitle':`${Math.min(13,Math.max(10,tile.width*.045))}px`,width:tile.width,height:tile.height,transform:`translate3d(${tile.x}px,${tile.y}px,0)`}}
    inert={!visible} onFocusCapture={event=>{const rect=event.target.getBoundingClientRect();if(rect.right<0||rect.left>innerWidth||rect.bottom<0||rect.top>innerHeight)onReveal();}} onClick={event=>onFocus(tile,track,event)} onContextMenu={event=>grouped?onGroupMenu(event):onMenu(event,track)} tabIndex={visible?0:-1} data-track-id={track.id} role="button" aria-label={grouped?`打开 ${track.title}`:`聚焦 ${track.title}，双击播放`} onKeyDown={event=>{if(event.key==='Enter'&&event.target===event.currentTarget)onFocus(tile,track,event);}}>
    <div className="poster-face"><div className="poster-artwork" ref={artwork} onLoadCapture={event=>{const image=event.target;if(image.matches('.mv-artwork-blur')){copyArtworkPresentation(artwork.current?.querySelector('img.cover'),image);return;}if(image.matches('img.cover'))presentArtwork(image);}}><Cover track={track} detail={focused} presentation="wall"/>{expanded&&focused&&<ArtworkBlur src={artworkURL(track,true)}/>}</div><div className="poster-shade"/>{!focused&&<><span className="poster-number">{String(tile.index+1).padStart(3,'0')}</span><div className="poster-caption"><h2>{track.title}</h2><p>{track.artist}</p></div></>}
    {focused&&<WallCardPlayer size={tile} track={track} playing={playing} onPlay={onPlay} onExpand={onExpand} expanded={expanded}/>}</div>
  </ArtworkModeScope>;
});
export function Wall({ tracks, playingID, onMenu, locateToken, selectedID,locateID,locateAnimated=true, reduceMotion,onImmersive,onChromeHidden,leadingInset=0,groups,onOpenGroup,sorting,emptyTitle,contentKey,onEscapeSidebar,onFocusChange }) {
  const grouped=Boolean(groups);
  const surface = useRef(), plane = useRef(), camera = useRef({ x: 0, y: 0, scale: 1 });
  const borderScale=useRef(0);
  const viewport = useRef({ width: 1, height: 1 }), mountedAt = useRef({ x: Infinity, y: Infinity, scale: 1 });
  const animation = useRef(0), gesture = useRef(null), pendingWheel = useRef({ x: 0, y: 0 });
  const inset=useRef(leadingInset),resizingUntil=useRef(0),tools=useRef(),toolsButton=useRef(),clickSequence=useRef(new WallClickSequence()),previousImmersive=useRef(false),savedCamera=useRef(null),expansionTimer=useRef(),restoring=useRef(false);
  const drag = useRef(null), suppressClick = useRef(false), wheelSource = useRef({ time: -Infinity, precise: false });
  const layoutSource=useRef(),handledLocation=useRef(0),[groupMenu,setGroupMenu]=useState(null);
  const [showTools,setShowTools]=useState(false),[immersive,setImmersive]=useState(false),[transitioning,setTransitioning]=useState(false);
  const [tiles, setTiles] = useState([]), [focus, setFocus] = useState(null), [scale, setScale] = useState(1),[preferredSide,setPreferredSide]=useState(480);
  const toolsPosition=usePopoverPosition(toolsButton,tools,showTools&&!immersive,{above:true,align:'end'});
  const scene = useMemo(() => createScene(tracks.length), [tracks.length]);
  const live = useRef({ scene, tracks, reduceMotion }); live.current = { scene, tracks, reduceMotion,immersive };
  function stop() { cancelAnimationFrame(animation.current); animation.current = 0; pendingWheel.current = { x: 0, y: 0 }; gesture.current = null; }
  function apply(force = false) {
    const c = camera.current;
    if (plane.current) {
      plane.current.style.transform = `translate3d(${c.x}px,${c.y}px,0) scale(${c.scale})`;
      if(borderScale.current!==c.scale){borderScale.current=c.scale;plane.current.style.setProperty('--wall-camera-scale',String(c.scale));}
    }
    const mounted = mountedAt.current;
    if (force || Math.abs(c.x-mounted.x) > 180 || Math.abs(c.y-mounted.y) > 180 || c.scale !== mounted.scale) {
      mountedAt.current = { ...c }; setTiles(visibleTiles(live.current.scene, c, viewport.current));
    }
  }
  function travel(target,animate=true,duration=420){
    stop();const c=camera.current,start={...c};
    if(!animate||live.current.reduceMotion){Object.assign(c,target);apply(true);return;}
    const began=performance.now();
    function tick(now){const p=Math.min(1,(now-began)/duration),eased=focusProgress(p);c.x=start.x+(target.x-start.x)*eased;c.y=start.y+(target.y-start.y)*eased;apply();if(p<1)animation.current=requestAnimationFrame(tick);else{animation.current=0;apply(true);}}
    animation.current=requestAnimationFrame(tick);
  }
  function center(tile,animate=true){const c=camera.current;travel({x:(viewport.current.width+inset.current)/2-(tile.x+tile.width/2)*c.scale,y:viewport.current.height/2-(tile.y+tile.height/2)*c.scale},animate);}
  function prepareFocus(tile){if(focus?.tile.id!==tile.id)setPreferredSide(wallFocusSide(surface.current?.clientHeight||viewport.current.height));}
  const sequence=tracks.map(track=>track.id).join('|');
  useLayoutEffect(() => {
    const before=layoutSource.current;layoutSource.current={contentKey,grouped};
    const preserve=before&&before.contentKey===contentKey&&before.grouped===grouped;
    const previous=focus?.tile,previousTrack=focus?.track.id;
    if(preserve){
      const index=tracks.findIndex(track=>track.id===previousTrack);
      if(previous&&index>=0&&!grouped){
        const tile=nearestInstance(scene,index,camera.current,viewport.current);
        const dx=(tile.x+tile.width/2-previous.x-previous.width/2)*camera.current.scale,dy=(tile.y+tile.height/2-previous.y-previous.height/2)*camera.current.scale;
        camera.current.x-=dx;camera.current.y-=dy;
        setFocus({tile,track:tracks[index]});
      }else if(previous){setFocus(null);setImmersive(false);setTransitioning(false);savedCamera.current=null;onImmersive?.(false);onChromeHidden?.(false);}
      apply(true);return;
    }
    clearTimeout(expansionTimer.current);clickSequence.current.reset();savedCamera.current=null;restoring.current=false;setTransitioning(false);setImmersive(false);onImmersive?.(false);onChromeHidden?.(false);
    const playingIndex=grouped?-1:tracks.findIndex(t=>t.id===playingID);
    const tile=playingIndex>=0?{...scene.tiles[playingIndex],id:`${playingIndex}:0:0`}:null;
    if(tile){prepareFocus(tile);setFocus({tile,track:tracks[playingIndex]});center(tile,false);}else{setFocus(null);camera.current.x=leadingInset+12;camera.current.y=80;apply(true);}
  }, [scene, sequence, grouped,contentKey]);
  useLayoutEffect(()=>{
    const previous=inset.current;inset.current=immersive?0:leadingInset;
    const changed=previousImmersive.current!==immersive;previousImmersive.current=immersive;
    if(!focus)return;
    if(changed&&!immersive&&savedCamera.current){
      const saved=savedCamera.current;savedCamera.current=null;restoring.current=false;
      travel(restoredPlayerCamera(saved,focus.tile,viewport.current,inset.current,camera.current.scale),true,600);
    }else if(changed)center(focus.tile);
    else if(!restoring.current){
      // React's resize commit may precede ResizeObserver. Detect live resizing
      // from the viewport too, so a sidebar inset change cannot start a spring
      // that subsequently overwrites the observer's camera displacement.
      const node=surface.current,resizing=document.documentElement.classList.contains('is-resizing')||performance.now()<resizingUntil.current||node?.clientWidth!==viewport.current.width||node?.clientHeight!==viewport.current.height;
      travel({x:camera.current.x+(inset.current-previous)/2,y:camera.current.y},!resizing,280);
    }
  },[leadingInset,immersive]);
  useEffect(()=>()=>clearTimeout(expansionTimer.current),[]);
  useEffect(() => {
    const observer = new ResizeObserver(entries => {
      const rect = entries[0].contentRect, previous = viewport.current;resizingUntil.current=performance.now()+140;
      // A pending focus/inertia tick still owns an old viewport target. Stop
      // it before shifting the camera; otherwise the next tick undoes resize.
      if(rect.width!==previous.width||rect.height!==previous.height)stop();
      viewport.current = { width: rect.width, height: rect.height };
      camera.current.x += (rect.width-previous.width)/2; camera.current.y += (rect.height-previous.height)/2; apply(true);
    }); observer.observe(surface.current); return () => observer.disconnect();
  }, [scene]);
  useEffect(() => {
    if (!locateToken||grouped||handledLocation.current===locateToken) return;
    const side=Math.max(260,Math.min(preferredSide,viewport.current.width-leadingInset-40,viewport.current.height-150));
    const tile=nearestRenderedInstance(scene,tracks.findIndex(t=>t.id===(locateID||selectedID)),camera.current,viewport.current,cell=>reflowFrame(cell,focus?.tile,{width:side,height:Math.max(320,side)}));if(tile){handledLocation.current=locateToken;prepareFocus(tile);setFocus({tile,track:tracks[tile.index]});center(tile,locateAnimated&&!live.current.immersive);}
  }, [locateToken,locateID,selectedID,grouped,sequence]);
  useEffect(() => {
    const node = surface.current;
    function wheel(event) {
      // Controls belong to the card's pan surface: hovering a lyric, transport
      // button or seek slider must never interrupt an ongoing trackpad gesture.
      // Floating tools retain their own wheel behavior outside the card.
      if (live.current.immersive||(!event.target.closest('.wall-card-content')&&event.target.closest('button,input,[role=slider],.wall-zoom,.wall-tools-popover'))) return;
      event.preventDefault();clickSequence.current.reset();
      const c = camera.current;
      if (event.ctrlKey || event.metaKey) {
        stop(); const r = node.getBoundingClientRect(), x = event.clientX-r.left, y = event.clientY-r.top;
        const next = Math.min(1.2,Math.max(.6,c.scale*Math.exp(-event.deltaY*.007)));
        c.x = x-(x-c.x)*next/c.scale; c.y = y-(y-c.y)*next/c.scale; c.scale = next; setScale(next); apply(true); return;
      }
      const multiplier = event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? viewport.current.height : 1;
      const dx = (event.shiftKey && !event.deltaX ? event.deltaY : event.deltaX)*multiplier;
      const dy = (event.shiftKey && !event.deltaX ? 0 : event.deltaY)*multiplier;
      const source = wheelSource.current;
      if (event.timeStamp-source.time > 120) source.precise = false;
      source.time = event.timeStamp;
      source.precise ||= !event.deltaMode && ((event.deltaX && event.deltaY) || Math.max(Math.abs(dx),Math.abs(dy)) < 50);
      if (source.precise || live.current.reduceMotion) { stop(); c.x -= dx; c.y -= dy; apply(); return; }
      if (gesture.current !== 'wheel') { stop(); gesture.current = 'wheel'; }
      pendingWheel.current.x -= dx; pendingWheel.current.y -= dy;
      if (animation.current) return;
      let previous = performance.now();
      function tick(now) {
        const result = wheelStep(pendingWheel.current, now-previous); previous = now;
        pendingWheel.current = result.pending; c.x += result.step.x; c.y += result.step.y; apply();
        if (result.pending.x || result.pending.y) animation.current = requestAnimationFrame(tick);
        else { animation.current = 0; gesture.current = null; }
      }
      animation.current = requestAnimationFrame(tick);
    }
    node.addEventListener('wheel',wheel,{ passive:false });
    return () => { node.removeEventListener('wheel',wheel); stop(); };
  }, []);
  function down(event) {
    if(immersive||event.button!==0||event.target.closest('input,[role=slider],.wall-tools-popover')||(event.target.closest('button')&&!event.target.closest('.wall-card-content')))return;
    stop(); drag.current = { pointer:event.pointerId, x:event.clientX, y:event.clientY, lastX:event.clientX, lastY:event.clientY, time:event.timeStamp, vx:0,vy:0, start:{ ...camera.current }, moved:false };
  }
  function move(event) {
    const d = drag.current; if (!d) return;
    const dx = event.clientX-d.x,dy = event.clientY-d.y,dt = event.timeStamp-d.time;
    if (!d.moved && Math.hypot(dx,dy)>6) { d.moved = true;clickSequence.current.reset(); surface.current.setPointerCapture(event.pointerId); }
    if (dt>0) { d.vx = (event.clientX-d.lastX)/dt*1000; d.vy = (event.clientY-d.lastY)/dt*1000; }
    d.lastX=event.clientX; d.lastY=event.clientY; d.time=event.timeStamp;
    if (d.moved) { camera.current.x=d.start.x+dx; camera.current.y=d.start.y+dy; apply(); }
  }
  function up(event) {
    const d = drag.current; drag.current=null; if (!d) return;
    if (surface.current.hasPointerCapture(event.pointerId)) surface.current.releasePointerCapture(event.pointerId);
    suppressClick.current = d.moved;
    if (!d.moved || live.current.reduceMotion || event.timeStamp-d.time>80) return;
    const speed=Math.hypot(d.vx,d.vy); if(speed<40)return;
    const start={ ...camera.current }, began=performance.now();
    function tick(now) {
      const distance=releaseDistance(speed,now-began);
      camera.current.x=start.x+distance*d.vx/speed; camera.current.y=start.y+distance*d.vy/speed; apply();
      if(Math.min(speed,4000)*.3-distance>.5)animation.current=requestAnimationFrame(tick); else animation.current=0;
    }
    animation.current=requestAnimationFrame(tick);
  }
  function zoomTo(requested,animate=true){
    stop();const c=camera.current,target=Math.min(1.2,Math.max(.6,requested)),start=c.scale,anchor={x:(viewport.current.width+inset.current)/2,y:viewport.current.height/2},world={x:(anchor.x-c.x)/start,y:(anchor.y-c.y)/start},began=performance.now();
    function tick(now){const p=!animate||live.current.reduceMotion?1:Math.min(1,(now-began)/280),next=start+(target-start)*(1-Math.cos(p*Math.PI))/2;c.x=anchor.x-world.x*next;c.y=anchor.y-world.y*next;c.scale=next;setScale(next);apply(true);if(p<1)animation.current=requestAnimationFrame(tick);else animation.current=0;}
    tick(began);
  }
  useEffect(()=>{if(!showTools)return;const outside=event=>{if(!tools.current?.contains(event.target)&&!toolsButton.current?.contains(event.target))setShowTools(false);},key=event=>{if(event.key==='Escape'){event.preventDefault();event.stopImmediatePropagation();setShowTools(false);toolsButton.current?.focus();}};window.addEventListener('pointerdown',outside,true);window.addEventListener('keydown',key,true);return()=>{window.removeEventListener('pointerdown',outside,true);window.removeEventListener('keydown',key,true);};},[showTools]);
  useEffect(()=>{if(!groupMenu)return;const close=()=>setGroupMenu(null);window.addEventListener('pointerdown',close);return()=>window.removeEventListener('pointerdown',close);},[groupMenu]);
  const expansionRequest=useRef(0);
  async function expand(){
    const request=++expansionRequest.current;
    if(!immersive&&focus?.track){try{await prepareWallpaper(focus.track);}catch{return;}if(!surface.current||request!==expansionRequest.current)return;}
    stop();clearTimeout(expansionTimer.current);const next=!immersive;
    if(next){savedCamera.current={...camera.current,sourceID:focus?.tile.id};setShowTools(false);}else restoring.current=true;
    setTransitioning(true);onChromeHidden?.(true);setImmersive(next);onImmersive?.(next);
    expansionTimer.current=setTimeout(()=>{setTransitioning(false);if(!next)onChromeHidden?.(false);},reduceMotion?1:600);
  }
  useEffect(()=>{const key=event=>{if(document.querySelector('[aria-modal="true"]'))return;if(event.key==='Escape'){if(immersive)expand();else if(onEscapeSidebar)onEscapeSidebar();else setFocus(null);}};window.addEventListener('keydown',key);return()=>window.removeEventListener('keydown',key);},[immersive,focus,onEscapeSidebar]);
  async function prepareWallpaper(track){
    const target=artworkViewport(viewport.current),image=new Image();image.src=artworkURL(track,true);
    await Promise.all([image.decode(),warmArtworkSubjects(artworkURL(track,false),context=>command('artworkSubjects',{id:track.id,viewport:context},{reportError:false}),target)]);
  }
  useEffect(()=>{
    if(!playingID||grouped)return;
    let active=true;
    const track=tracks.find(track=>track.id===playingID);
    if(!track||focus?.track.id===playingID)return;
    const reveal=()=>{if(!active)return;const tile=nearestInstance(live.current.scene,live.current.tracks.findIndex(t=>t.id===playingID),camera.current,viewport.current);if(!tile)return;prepareFocus(tile);setFocus({tile,track});center(tile,Boolean(focus)&&!live.current.immersive);};
    if(live.current.immersive)prepareWallpaper(track).then(reveal).catch(()=>{});else reveal();
    return()=>{active=false;};
  },[playingID,grouped]);
  useEffect(()=>{onFocusChange?.(grouped?null:focus?.track||null);},[focus,grouped,onFocusChange]);
  function playPoster(id){command('play',{id,ids:tracks.map(track=>track.id),preservePosition:true});}
  function continuedClick(event){
    if(suppressClick.current){suppressClick.current=false;clickSequence.current.reset();event.stopPropagation();event.preventDefault();return;}
    const poster=event.target.closest('.wall-poster');
    const result=clickSequence.current.click({id:poster?.dataset.trackId,x:event.clientX,y:event.clientY,time:event.timeStamp,
      control:Boolean(event.target.closest('button,input,[role=slider],.wall-tools-popover')),group:Boolean(groups),keyboard:event.detail===0},playbackState.get().doubleClickIntervalMs??500);
    if(result.type==='play'){event.stopPropagation();event.preventDefault();playPoster(result.id);}
  }
  // Group covers borrow their first track's artwork/ID, but must never borrow
  // its playback state or an old song focus while navigation effects settle.
  const activeFocus=grouped?null:focus;
  const playingCell=playingInstance(scene,grouped?-1:tracks.findIndex(track=>track.id===playingID),camera.current,viewport.current,activeFocus?.tile);
  const rendered = activeFocus && !tiles.some(t => t.id === activeFocus.tile.id) ? [...tiles, activeFocus.tile] : tiles;
  return <section ref={surface} className={`wall-surface ${immersive?'is-immersive':''} ${transitioning?'is-expanding':''} ${playingID&&!groups?'has-playing-track':''}`} aria-label="音乐墙" onClickCapture={continuedClick} onPointerDown={down} onPointerMove={move} onPointerUp={up}
    onPointerCancel={() => { drag.current=null;clickSequence.current.reset(); stop(); }}>
    <div className="wall-plane" ref={plane}>{rendered.map(tile => {
      const track=tracks[tile.index]; if(!track)return null;
      const focused=activeFocus?.tile.id===tile.id;
      const side=Math.max(260,Math.min(preferredSide,viewport.current.width-leadingInset-40,viewport.current.height-150));
      const size=immersive?{width:viewport.current.width/camera.current.scale,height:viewport.current.height/camera.current.scale}:{width:side,height:Math.max(320,side)};
      const frame=reflowFrame(tile,activeFocus?.tile,size),c=camera.current,visible=frame.x*c.scale+c.x<viewport.current.width+200&&(frame.x+frame.width)*c.scale+c.x> -200&&frame.y*c.scale+c.y<viewport.current.height+200&&(frame.y+frame.height)*c.scale+c.y> -200;
      return <Poster key={immersive&&focused?`wallpaper:${tile.id}:${track.artworkRevision||0}`:tile.id} tile={frame} grouped={grouped} visible={visible} onReveal={()=>center(tile,false)} track={track} focused={focused} playing={playingCell?.id===tile.id} onMenu={onMenu} onGroupMenu={event=>{event.preventDefault();setGroupMenu({name:groups[tile.index].name,x:Math.max(8,Math.min(event.clientX,innerWidth-248)),y:Math.max(8,Math.min(event.clientY,innerHeight-80))});}} expanded={immersive} displayScale={camera.current.scale} transitioning={transitioning} reduceMotion={reduceMotion||(immersive&&!transitioning)||performance.now()<resizingUntil.current} onExpand={expand} onPlay={()=>groups?onOpenGroup(groups[tile.index].name):playPoster(track.id)}
        onFocus={(_,__,event)=>{if(suppressClick.current){suppressClick.current=false;return;}if(groups){onOpenGroup(groups[tile.index].name);return;}if(focus?.tile.id===tile.id)return;prepareFocus(tile);setFocus({tile,track});center(tile);}}/>

    })}</div>
    {!tracks.length && <div className="empty"><h2>{emptyTitle||'让音乐铺满整个窗口'}</h2>{!emptyTitle&&<p>添加音乐文件夹，或尝试其他搜索词。</p>}</div>}
    <ActionButton ref={toolsButton} className="wall-settings icon-button" inert={immersive} aria-label="音乐墙设置" title="音乐墙设置" aria-expanded={showTools} onClick={()=>setShowTools(v=>!v)}><Icon name="wall-settings"/></ActionButton>{showTools&&!immersive&&createPortal(<div ref={tools} style={toolsPosition} className="wall-tools-popover anchored-popover" role="dialog" aria-label="音乐墙设置"><header><strong>音乐墙</strong><ActionButton aria-label="关闭设置" onClick={()=>setShowTools(false)}><Icon name="close"/></ActionButton></header><div className="wall-scale-label"><span>显示比例</span><b>{Math.round(scale*100)}%</b></div><div className="wall-scale-controls"><ActionButton aria-label="缩小" disabled={scale<=.601} onClick={()=>zoomTo(nextWallZoomStop(scale,-1))}><Icon name="zoomOut"/></ActionButton><div className="wall-scale-track"><Slider label="显示比例" valueText={value=>`${Math.round(value)}%`} min={60} max={120} step={1} marks={wallZoomStops} value={Number((scale*100).toFixed(1))} onValueChange={value=>zoomTo(value/100,false)}/></div><ActionButton aria-label="放大" disabled={scale>=1.199} onClick={()=>zoomTo(nextWallZoomStop(scale,1))}><Icon name="zoomIn"/></ActionButton></div><ActionButton className="wall-reset-zoom" disabled={Math.abs(scale-1)<.001} onClick={()=>zoomTo(1)}><Icon name="refresh"/>恢复 100%</ActionButton>{sorting&&<><hr/><strong className="wall-sort-heading"><Icon name="sort"/>列表排序</strong><div className="wall-sort-options">{(sorting?.grouping?[['name',sorting.artist?'歌手姓名':'专辑名称'],['count','歌曲数量']]:[['title','歌曲名称'],['artist','歌手姓名'],['album','专辑名称'],['sourceAdded','添加时间'],['added','更新时间']]).map(([value,label])=><SortMenuItem key={value} selected={Boolean(sorting?.sort===value||(sorting?.grouping&&value==='name'&&sorting?.sort!=='count'))} onClick={()=>sorting?.onSort(value)}>{label}</SortMenuItem>)}<hr/>{[[true,'正序'],[false,'降序']].map(([value,label])=><SortMenuItem key={label} selected={sorting?.ascending===value} onClick={()=>sorting?.onAscending(value)}>{label}</SortMenuItem>)}</div></>}</div>,document.body)}

    {groupMenu&&createPortal(<div className="context-menu" role="menu" style={{left:groupMenu.x,top:groupMenu.y}} onPointerDown={e=>e.stopPropagation()}><ActionButton role="menuitem" onClick={()=>{onOpenGroup(groupMenu.name);setGroupMenu(null);}}>打开</ActionButton></div>,document.body)}
  </section>;
}
