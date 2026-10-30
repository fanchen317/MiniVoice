export function createWallProbe({delay}){
 const rootWall=()=>document.querySelector('.mv-cover-wall');
 const camera=()=>JSON.parse(document.querySelector('.mv-wall-plane').dataset.camera);
 const box=()=>document.querySelector('.mv-wall-focused');
 let touch=null;
 const native=()=>rootWall().dataset.wallRenderer==='native-scroll-single-surface';
 const touchEvent=(type,points)=>{const target=rootWall(),touches=points.map((point,i)=>new Touch({identifier:i+71,target,clientX:point.x,clientY:point.y}));target.dispatchEvent(new TouchEvent(type,{bubbles:true,cancelable:true,touches,targetTouches:touches,changedTouches:touches}));};
 const pointer=(target,type,id,x,y)=>target.dispatchEvent(new PointerEvent(type,{bubbles:true,cancelable:true,pointerId:id,pointerType:'touch',isPrimary:id===71,button:0,buttons:type==='pointercancel'?0:1,clientX:x,clientY:y}));
 const cancelTouch=()=>{if(touch){if(native())touchEvent('touchend',[]);else pointer(rootWall(),'pointercancel',71,touch.x,touch.y);touch=null;}};
 const probe=async({operation,dx=0,dy=0,index=0,scale=1}={})=>{
  const wall=rootWall();let scrolled=null;if(native()&&(operation==='pan'||operation==='panStep'))scrolled=new Promise(resolve=>{const done=()=>{wall.removeEventListener('scroll',done);resolve();};wall.addEventListener('scroll',done,{once:true});setTimeout(done,1000);});
  if(operation==='select'){
   const nodes=[...wall.querySelectorAll('.mv-wall-card:not(.is-focus-underlay)')];nodes[index%nodes.length]?.click();
  }else if(operation==='tapFocused'){
   const target=box(),r=target.getBoundingClientRect();if(native())target.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,detail:1,clientX:r.x+r.width/2,clientY:r.y+20}));else{pointer(target,'pointerdown',71,r.x+r.width/2,r.y+20);pointer(target,'pointerup',71,r.x+r.width/2,r.y+20);}
  }else if(operation==='cancelZoom'){
   if(native())touchEvent('touchcancel',touch?[touch]:[]);
  }else if(operation==='beginPan'){
   cancelTouch();touch={x:innerWidth/2,y:innerHeight*.4};if(!native())pointer(wall,'pointerdown',71,touch.x,touch.y);
  }else if(operation==='panStep'){
   touch.x-=dx;touch.y-=dy;if(native())wall.scrollBy(dx,dy);else pointer(wall,'pointermove',71,touch.x,touch.y);
  }else if(operation==='endPan'){
   cancelTouch();dispatchEvent(new Event('minivoice-flush'));
  }else if(operation==='pan'){
   if(native())wall.scrollBy(dx,dy);else wall.dispatchEvent(new WheelEvent('wheel',{deltaX:dx,deltaY:dy,bubbles:true,cancelable:true}));
  }else if(operation==='zoom'){
   const c=camera();wall.dispatchEvent(new WheelEvent('wheel',{deltaY:-Math.log(scale/c.scale)/.003,ctrlKey:true,clientX:innerWidth/2,clientY:innerHeight/2,bubbles:true,cancelable:true}));
  }else if(operation==='motionZoom'){
   cancelTouch();touch={x:innerWidth/2-50,y:innerHeight*.4};
   if(native()){const before=camera().scale;touchEvent('touchstart',[touch,{x:touch.x+100,y:touch.y}]);touchEvent('touchmove',[touch,{x:touch.x+100*scale/before,y:touch.y}]);}
   else{pointer(wall,'pointerdown',71,touch.x,touch.y);pointer(wall,'pointerdown',72,touch.x+100,touch.y);pointer(wall,'pointermove',72,touch.x+100*scale/camera().scale,touch.y);}
  }
  if(scrolled)await scrolled;
  await delay(24);
  // Read after the scheduled paint, not after an assumed frame duration.
  await new Promise(resolve=>requestAnimationFrame(resolve));
  const c=camera(),plane=wall.querySelector('.mv-wall-plane'),f=box(),r=f?.getBoundingClientRect(),content=f?.querySelector('.mv-wall-focus-content'),cr=content?.getBoundingClientRect();
  const images=[...wall.querySelectorAll('.mv-wall-card img')];
  const visible=images.filter(node=>{const r=node.getBoundingClientRect();return r.right>0&&r.bottom>0&&r.left<innerWidth&&r.top<innerHeight;});
  const mask=f&&getComputedStyle(f,'::after'),outline=f?.querySelector('.mv-wall-current-outline'),or=outline?.getBoundingClientRect();
  return {active:wall.dataset.wallRenderer==='native-scroll-single-surface',mounted:images.length,decoded:visible.filter(n=>n.complete&&n.naturalWidth>0).length,visibleBlank:visible.filter(n=>!n.complete||!n.naturalWidth).length,boundedArtwork:visible.every(n=>n.naturalWidth<=320&&n.naturalHeight<=320),
   ...c,focused:f?.dataset.wallId||'',square:r&&Math.abs(r.width-r.height)<1.5,
   maskAligned:!f||(Math.abs(parseFloat(mask.width)-r.width)<1.5&&Math.abs(parseFloat(mask.height)-r.height)<1.5),
   contourAligned:!outline||(Math.abs(or.width-r.width)<1.5&&Math.abs(or.height-r.height)<1.5),
   contourVisible:!!outline&&getComputedStyle(outline).display!=='none',
   contentAligned:!content||(Math.abs(cr.width-r.width)<1.5&&Math.abs(cr.height-r.height)<1.5),
   depth:JSON.parse(plane.dataset.displayCamera).scale/c.scale,
   liveContent:!!content&&content.isConnected&&getComputedStyle(content).visibility==='visible',
   planeBounds:{width:plane.offsetWidth,height:plane.offsetHeight},frame:r&&{x:r.x,y:r.y,width:r.width,height:r.height}};
 };

 return {rootWall,camera,box,probe};
}
