import {scrollMetrics,dragPosition,keyboardPosition} from './scrollModel.js';
const hosts=new WeakMap();let serial=0;
/** MiniVoice paints and owns the thumb; no OS/browser scrollbar interaction is used. */
export function mountScrollbar(view,{input='keyboard-mouse',label='滚动内容'}={}){
 const doc=view.ownerDocument,win=doc.defaultView,host=view.parentElement;if(!host)return()=>{};
 let entry=hosts.get(host);if(!entry){entry={count:0,position:host.style.position};if(win.getComputedStyle(host).position==='static')host.style.position='relative';hosts.set(host,entry);}entry.count++;
 const rail=doc.createElement('div'),thumb=doc.createElement('button');rail.className='mv-custom-scroll-rail';rail.dataset.input=input;thumb.className='mv-custom-scroll-thumb';thumb.type='button';thumb.setAttribute('role','scrollbar');thumb.setAttribute('aria-label',label);thumb.setAttribute('aria-orientation','vertical');thumb.setAttribute('aria-valuemin','0');
 const oldId=view.id;if(!oldId)view.id=`mv-scroll-${++serial}`;thumb.setAttribute('aria-controls',view.id);rail.append(thumb);host.append(rail);view.classList.add('mv-custom-scroll-view');
 let metric=scrollMetrics(0,0,0),drag=null,timer=null,hover=false,disposed=false;
 const hideLater=()=>{win.clearTimeout(timer);if(!drag&&!hover)timer=win.setTimeout(()=>rail.classList.remove('is-visible'),input==='touch'?800:1400);};
 const reveal=()=>{if(!metric.overflow)return;rail.classList.add('is-visible');hideLater();};
 const measure=()=>{
  if(disposed)return;metric=scrollMetrics(view.clientHeight,view.scrollHeight,view.scrollTop);
  const a=view.getBoundingClientRect(),b=host.getBoundingClientRect(),sx=host.offsetWidth?b.width/host.offsetWidth:1,sy=host.offsetHeight?b.height/host.offsetHeight:1;
  const layer=parseInt(win.getComputedStyle(view).zIndex,10);rail.style.zIndex=Number.isFinite(layer)?String(layer+1):'8';
  rail.hidden=!metric.overflow||a.width<=0||a.height<=0;
  Object.assign(rail.style,{left:`${(a.right-b.left)/(sx||1)+host.scrollLeft-host.clientLeft-(input==='touch'?28:20)}px`,top:`${(a.top-b.top)/(sy||1)+host.scrollTop-host.clientTop}px`,height:`${metric.viewport}px`});
  Object.assign(thumb.style,{height:`${metric.height}px`,transform:`translateY(${metric.top}px)`});thumb.setAttribute('aria-valuemax',String(Math.round(metric.range)));thumb.setAttribute('aria-valuenow',String(Math.round(metric.position)));
 };
 const scroll=()=>{measure();reveal();};
 const down=event=>{if(event.button!==0)return;event.preventDefault();event.stopPropagation();if(input!=='touch')thumb.focus({preventScroll:true});measure();thumb.setPointerCapture(event.pointerId);drag={id:event.pointerId,y:event.clientY,scroll:view.scrollTop,scale:view.getBoundingClientRect().height/Math.max(1,view.offsetHeight)};rail.classList.add('is-dragging');win.clearTimeout(timer);reveal();};
 const move=event=>{if(!drag||event.pointerId!==drag.id)return;view.scrollTop=dragPosition(drag.scroll,(event.clientY-drag.y)/(drag.scale||1),metric);measure();};
 const up=event=>{if(!drag||event.pointerId!==drag.id)return;drag=null;rail.classList.remove('is-dragging');hideLater();};
 const enter=()=>{hover=true;};const leave=()=>{hover=false;hideLater();};
 const key=event=>{const next=keyboardPosition(event.key,view.scrollTop,metric);if(next===null)return;event.preventDefault();event.stopPropagation();view.scrollTop=next;measure();reveal();};
 const blur=()=>{drag=null;hover=false;rail.classList.remove('is-dragging');hideLater();};
 view.addEventListener('scroll',scroll,{passive:true});thumb.addEventListener('pointerdown',down);thumb.addEventListener('pointermove',move);thumb.addEventListener('pointerup',up);thumb.addEventListener('pointercancel',up);thumb.addEventListener('lostpointercapture',up);thumb.addEventListener('keydown',key);thumb.addEventListener('focus',reveal);thumb.addEventListener('blur',hideLater);rail.addEventListener('pointerenter',enter);rail.addEventListener('pointerleave',leave);win.addEventListener('blur',blur);win.addEventListener('resize',measure);win.addEventListener('scroll',measure,true);
 const resize=new win.ResizeObserver(measure);resize.observe(view);resize.observe(host);let content=null;const observeContent=()=>{if(content===view.firstElementChild)return;if(content)resize.unobserve(content);content=view.firstElementChild;if(content)resize.observe(content);};observeContent();
 const mutation=new win.MutationObserver(()=>{observeContent();measure();});mutation.observe(view,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['style']});measure();
 return()=>{disposed=true;win.clearTimeout(timer);resize.disconnect();mutation.disconnect();view.removeEventListener('scroll',scroll);win.removeEventListener('blur',blur);win.removeEventListener('resize',measure);win.removeEventListener('scroll',measure,true);rail.remove();view.classList.remove('mv-custom-scroll-view');if(!oldId)view.removeAttribute('id');if(!--entry.count){host.style.position=entry.position;hosts.delete(host);}};
}
