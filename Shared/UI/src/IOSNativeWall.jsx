import React,{forwardRef,useImperativeHandle,useLayoutEffect,useRef,useState} from 'react';
import {mobileWallViewport,initialWallCamera} from './wallLayout.js';
import './iosNativeWall.css';

const send=value=>globalThis.webkit?.messageHandlers?.MiniVoice?.postMessage({nativeWall:value});
// This adapter carries semantic changes only. UIKit owns all per-frame geometry.
export default forwardRef(function IOSNativeWall(props,api){
 const root=useRef(null),sentItems=useRef(null),latest=useRef(props),session=useRef(`wall-${Date.now()}-${Math.random()}`),[surface,setSurface]=useState(null);
 latest.current=props;
 const command=value=>send({session:session.current,...value});
 useImperativeHandle(api,()=>({interrupt:()=>command({kind:'interrupt'}),zoomTo:scale=>command({kind:'zoom',scale})}),[]);
 useLayoutEffect(()=>{
  document.documentElement.classList.add('ios-native-wall');
  let frame=0,last='';
  const measure=()=>{cancelAnimationFrame(frame);frame=requestAnimationFrame(()=>{
   const node=root.current;if(!node)return;
   const rect=node.getBoundingClientRect(),style=getComputedStyle(document.documentElement),safe={};
   for(const edge of ['top','right','bottom','left'])safe[edge]=parseFloat(style.getPropertyValue(`--mv-safe-${edge}`))||0;
   const viewport=mobileWallViewport(rect.width,rect.height,safe);
   // Only actual web controls intercept touches. The canvas underneath receives native gestures.
   const regions=[...document.querySelectorAll('.mv-toolbar button,.mv-toolbar input,.mv-search,.mv-wall-dock,[data-wall-control],.mv-native-focus button,.mv-native-focus [role=slider],.mv-native-focus .wp-lyrics,.mv-modal-shade,.mv-drawer-shade')].filter(element=>{
    const s=getComputedStyle(element);return !element.closest('[inert]')&&s.visibility!=='hidden'&&s.display!=='none'&&Number(s.opacity)!==0;
   }).map(element=>{const r=element.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};}).filter(r=>r.width>0&&r.height>0);
   const value={kind:'geometry',dark:document.querySelector('main')?.classList.contains('theme-dark'),reduceMotion:matchMedia('(prefers-reduced-motion:reduce)').matches||document.documentElement.classList.contains('reduce-motion'),bounds:{x:rect.x,y:rect.y,width:rect.width,height:rect.height},viewport,regions};
   const key=JSON.stringify(value);if(key!==last){last=key;command(value);}
  });};
  const receive=event=>{const value=event.detail;if(value?.session!==session.current)return;const p=latest.current;
   if(value.kind==='surface')setSurface(previous=>value.visible?value:previous?{...previous,visible:false}:null);
   if(value.kind==='camera'){p.onCamera?.(value.camera);p.onScale?.(value.camera.scale);}
   if(value.kind==='scale')p.onScale?.(value.scale);
   if(value.kind==='select'||value.kind==='double'||value.kind==='context'){
    const item=p.items.find(item=>item.id===value.id);if(!item)return;
    if(value.kind==='select')p.onSelect?.(item);
    else if(value.kind==='double')p.onDoubleSelect?.(item);
    else p.onContext?.(item);
   }
  };
  window.addEventListener('minivoice-native-wall',receive);
  const motion=matchMedia('(prefers-reduced-motion:reduce)');motion.addEventListener('change',measure);
  window.addEventListener('minivoice-insets',measure);window.addEventListener('resize',measure);
  window.addEventListener('minivoice-flush',flush);
  function flush(){command({kind:'flush'});}
  const resize=new ResizeObserver(measure);resize.observe(document.documentElement);resize.observe(root.current);
  const chrome='.mv-scene,.mv-toolbar,.mv-search-control,.mv-wall-dock,[data-wall-control],.mv-native-focus,.wp-controls,.mv-modal-shade,.mv-drawer-shade';
  const mutations=new MutationObserver(records=>{if(records.some(record=>record.target===document.documentElement||record.target===root.current||record.target===document.querySelector('main')||record.target.matches?.(chrome)))measure();});
  mutations.observe(document.querySelector('main'),{subtree:true,childList:true,attributes:true,attributeFilter:['class','style','inert','hidden']});
  mutations.observe(document.documentElement,{attributes:true,attributeFilter:['class']});
  measure();
  return()=>{motion.removeEventListener('change',measure);command({kind:'detach'});cancelAnimationFrame(frame);resize.disconnect();mutations.disconnect();window.removeEventListener('minivoice-native-wall',receive);window.removeEventListener('minivoice-insets',measure);window.removeEventListener('resize',measure);window.removeEventListener('minivoice-flush',flush);document.documentElement.classList.remove('ios-native-wall');};
 },[]);
 useLayoutEffect(()=>{const items=sentItems.current===props.items?undefined:props.items.map(item=>({id:item.id,title:item.title,artist:item.artist||'',artwork:item.artwork||''}));sentItems.current=props.items;command({kind:'configure',...(items?{items}:{}),camera:{...props.page.camera,...initialWallCamera(props.page.camera)},current:props.current||'',playingId:props.playingId||'',playing:props.playing,focused:props.focused,expanded:props.expanded,blocked:props.blocked,recessed:props.recessed,grouped:props.grouped,location:props.location||0,reduceMotion:matchMedia('(prefers-reduced-motion:reduce)').matches||document.documentElement.classList.contains('reduce-motion')});},[props.items,props.current,props.playingId,props.playing,props.focused,props.expanded,props.blocked,props.recessed,props.grouped,props.location]);
 useLayoutEffect(()=>{
  if(!surface?.visible)return;
  let second=0;const first=requestAnimationFrame(()=>{second=requestAnimationFrame(()=>command({kind:'surfaceReady',epoch:surface.epoch}));});
  return()=>{cancelAnimationFrame(first);cancelAnimationFrame(second);};
 },[surface]);
 const item=props.focused&&surface&&props.items.find(item=>item.id===surface.id),r=surface?.rect;
 return <div ref={root} className={`mv-cover-wall mv-ios-native-wall ${props.playing?'is-playing':''} ${props.expanded?'is-expanding':''}`} data-mv-component="IOSNativeWall" aria-label="音乐墙" data-native-renderer="uikit">
  {item&&r&&<section className={`mv-native-focus mv-wall-focused ${props.expanded?'is-expanded':''} ${item.id===props.playingId?'is-current':'is-preview'}`} aria-label="音乐墙播放卡片" data-wall-id={item.id} style={{left:r.x,top:r.y,width:r.width,height:r.height,transform:'none',visibility:surface.visible?'visible':'hidden'}}><div className="mv-wall-focus-content" style={{width:r.width,height:r.height}}>{props.focusContent(item,{width:r.width,height:r.height,compact:surface.scale<.7})}</div></section>}
  {!props.items.length&&<div className="mv-empty">{props.loading?'正在载入音乐库…':'添加音乐文件夹，开始浏览音乐墙'}</div>}
 </div>;
});
