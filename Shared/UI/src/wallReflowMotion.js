import {focusProgress} from './wallGeometry.js';
/** Fixed layout boxes, compositor-only transforms; artwork keeps its natural aspect. */
export function animateWallReflow(entries,{duration,elapsed=0}){
 const animations=[],restore=[];
 const remember=(node,names)=>{const previous=names.map(name=>[name,node.style.getPropertyValue(name),node.style.getPropertyPriority(name)]);restore.push(()=>{for(const [name,value,priority] of previous){if(value)node.style.setProperty(name,value,priority);else node.style.removeProperty(name);}});};
 for(const {node,rectAt,content=false,fadeFrom=1,fadeTo=1} of entries){
  if(!node)continue;
  const target=rectAt(1),w=Math.max(1,target.width),h=Math.max(1,target.height);
  node.style.left='0px';node.style.top='0px';node.style.width=w+'px';node.style.height=h+'px';
  node.style.transform=`translate(${target.x}px,${target.y}px)`;
  const samples=Array.from({length:33},(_,i)=>{const offset=i/32,r=rectAt(focusProgress(offset));return {offset,r,sx:Math.max(.001,r.width/w),sy:Math.max(.001,r.height/h)};});
  const run=(element,frames)=>{
   const animation=element.animate(frames,{duration,easing:'linear',fill:'both'});animation.currentTime=Math.min(duration,Math.max(0,elapsed));animations.push(animation);
  };
  run(node,samples.map(({offset,r,sx,sy})=>({offset,transform:`translate(${r.x}px,${r.y}px) scale(${sx},${sy})`,opacity:fadeFrom+(fadeTo-fadeFrom)*focusProgress(offset)})));
  for(const image of node.querySelectorAll(content?':scope > .mv-wall-focused-art':':scope > img')){
   remember(image,['position','inset','left','top','width','height','max-width','max-height','transform-origin']);
   const ratio=(image.naturalWidth||w)/(image.naturalHeight||h),iw=Math.max(w,h*ratio),ih=iw/ratio;
   Object.assign(image.style,{position:'absolute',inset:'auto',left:'50%',top:'50%',width:iw+'px',height:ih+'px',maxWidth:'none',maxHeight:'none',transformOrigin:'center'});
   run(image,samples.map(({offset,r,sx,sy})=>{const cover=Math.max(r.width/iw,r.height/ih);return {offset,transform:`translate(-50%,-50%) scale(${cover/sx},${cover/sy})`};}));
  }
  const text=node.querySelector(content?':scope > .mv-wall-focus-content':':scope > .mv-wall-caption');
  if(text){
   remember(text,['transform-origin','width']);text.style.transformOrigin=content?'0 0':'0 100%';
   if(!content)text.style.width=Math.max(...samples.map(s=>s.r.width))+'px';
   run(text,samples.map(({offset,sx,sy})=>({offset,transform:`scale(${1/sx},${1/sy})`})));
  }
 }
 return ()=>{animations.forEach(animation=>animation.cancel());restore.forEach(reset=>reset());};
}
