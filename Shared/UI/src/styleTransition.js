import {fragmentKeyframes,prepareFragments} from './fragmentMotion.js';
const reduced=()=>document.documentElement.classList.contains('reduce-motion')||matchMedia('(prefers-reduced-motion:reduce)').matches;
const frames=()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
/** Same fragment grid, outward curl/rotation, 680ms sweep and icon origin as Mac. */
export async function transitionStyle(update,root=document.querySelector('.mv-workspace'),capture,mode='fragments'){
 if(reduced()||!root){await update();return;}
 let canvas,frame=0,timer=0,animation,stopWait,updated=false,updateFailure,interrupted=false;
 const began=performance.now();let captured=began,decoded=began,prepared=began;
 const fragments=[];
 const commit=async()=>{if(!updated){updated=true;try{await update();}catch(error){updateFailure=error;throw error;}}};
 const cleanup=()=>{cancelAnimationFrame(frame);canvas?.remove();fragments.forEach(value=>value.cancel());animation?.cancel();stopWait?.();};
 const abort=()=>{interrupted=true;cleanup();};
 const finish=()=>{if(reduced())abort();};
 const media=matchMedia('(prefers-reduced-motion:reduce)'),observer=new MutationObserver(finish);
 media.addEventListener('change',finish);observer.observe(document.documentElement,{attributes:true,attributeFilter:['class']});window.addEventListener('resize',abort);
 document.documentElement.dataset.mvStyleTransition='true';
 try{
  // WKWebView snapshot/readback can leave full-width raster seams on device.
  // This host policy keeps one live surface; no JPEG, tiles or screenshot wait.
  if(mode==='live'){
   root.dataset.styleRenderer='live';
   animation=root.animate([{opacity:1},{opacity:.35}],{duration:100,easing:'ease-out',fill:'forwards'});
   await animation.finished.catch(()=>{});
   await commit();await frames();
   animation.cancel();
   if(!interrupted&&!reduced()&&root.isConnected){
    animation=root.animate([{opacity:.35},{opacity:1}],{duration:180,easing:'ease-out'});
    await animation.finished.catch(()=>{});
   }
   return;
  }
  const icon=root.querySelector('.mv-brand-logo')?.getBoundingClientRect(),origin=icon?{x:icon.x+icon.width/2,y:icon.y+icon.height/2}:{x:36,y:60};
  await frames();
  const snapshot=capture?await Promise.race([capture().catch(()=>null),new Promise(resolve=>{timer=setTimeout(()=>resolve(null),180);})]):null;clearTimeout(timer);captured=performance.now();
  if(snapshot&&!reduced()&&!interrupted&&root.isConnected){
   const bitmap=new Image();bitmap.src=snapshot;
   await Promise.race([bitmap.decode(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('页面画面解码超时')),250);})]);clearTimeout(timer);decoded=performance.now();
   if(reduced()||interrupted||!root.isConnected){await commit();return;}
   const width=innerWidth,height=innerHeight,scale=Math.min(devicePixelRatio||1,1.5,bitmap.width/width,Math.sqrt(1200000/(width*height)));
   canvas=document.createElement('div');canvas.className='mv-style-fragment-sweep';canvas.dataset.mvComponent='style-transition';canvas.dataset.renderer='compositor';canvas.dataset.elapsed='0';canvas.setAttribute('aria-hidden','true');canvas.inert=true;
   const plan=prepareFragments(width,height,origin,{maxCells:root.dataset.presentation==='mobile'?24:224}),tiles=document.createDocumentFragment();
   // Rasterize each region once. Animation frames never recrop the full-screen
   // JPEG or upload a newly painted full-screen canvas to the compositor.
   let batch=0;
   for(const cell of plan){
    if(batch++%8===0){await new Promise(resolve=>requestAnimationFrame(resolve));if(reduced()||interrupted){await commit();return;}}
    const tile=document.createElement('canvas');tile.width=Math.ceil(cell.width*scale);tile.height=Math.ceil(cell.height*scale);
    Object.assign(tile.style,{position:'absolute',left:`${cell.x}px`,top:`${cell.y}px`,width:`${cell.width}px`,height:`${cell.height}px`,transformOrigin:'center',willChange:'transform,opacity'});
    const context=tile.getContext('2d');if(!context)throw Error('页面动画画布暂不可用');
    context.drawImage(bitmap,cell.x/width*bitmap.width,cell.y/height*bitmap.height,cell.width/width*bitmap.width,cell.height/height*bitmap.height,0,0,tile.width,tile.height);
    tiles.append(tile);cell.tile=tile;
   }
   prepared=performance.now();
   canvas.append(tiles);document.body.append(canvas);await commit();await frames();
   if(canvas.isConnected&&!reduced()&&!interrupted){
    for(const cell of plan)fragments.push(cell.tile.animate(fragmentKeyframes(cell),{duration:480,delay:cell.delay,easing:'linear',fill:'both'}));
    frame=requestAnimationFrame(()=>{if(canvas?.isConnected)canvas.dataset.elapsed='1';});
    await new Promise(resolve=>{stopWait=resolve;timer=setTimeout(resolve,690);});
   }
  }else{
   await commit();await frames();
   if(!reduced()&&!interrupted){animation=root.animate([{opacity:.75,transform:'translateY(6px)'},{opacity:1,transform:'none'}],{duration:260,easing:'cubic-bezier(.22,1,.36,1)'});await animation.finished.catch(()=>{});}
  }
 }catch{if(updateFailure)throw updateFailure;await commit();}
 finally{if(root)root.dataset.styleTimings=JSON.stringify({capture:Math.round(captured-began),decode:Math.round(Math.max(0,decoded-captured)),prepare:Math.round(Math.max(0,prepared-decoded)),total:Math.round(performance.now()-began)});clearTimeout(timer);cleanup();observer.disconnect();media.removeEventListener('change',finish);window.removeEventListener('resize',abort);delete document.documentElement.dataset.mvStyleTransition;delete root?.dataset.styleRenderer;}
}
