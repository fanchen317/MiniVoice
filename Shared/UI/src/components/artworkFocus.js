import {compositionCrop,compositionViewport} from './artworkComposition.js';
// Bounded samples are keyed by both artwork identity and pixel coordinate space.
// A trimmed list thumbnail is not the same image as an uncropped original.
const cache=new Map(),subjects=new Map(),pendingSubjects=new Map(),subjectQualities=new Map(),subjectListeners=new Map();
let analysisRevision=0,subjectGeneration=0;const subjectRevisions=new Map();
function energyMap(pixels,width,height){
 const values=new Float32Array(width*height),stride=width+1,sums=Array.from({length:3},()=>new Float64Array((width+1)*(height+1)));
 for(let y=0;y<height;y++)for(let x=0;x<width;x++)for(let channel=0;channel<3;channel++){const index=(y+1)*stride+x+1;sums[channel][index]=pixels[(y*width+x)*4+channel]+sums[channel][index-1]+sums[channel][index-stride]-sums[channel][index-stride-1];}
 const mean=(channel,x,y,radius)=>{const x0=Math.max(0,x-radius),y0=Math.max(0,y-radius),x1=Math.min(width,x+radius+1),y1=Math.min(height,y+radius+1),sum=sums[channel];return (sum[y1*stride+x1]-sum[y0*stride+x1]-sum[y1*stride+x0]+sum[y0*stride+x0])/((x1-x0)*(y1-y0));};
 const global=sums.map(sum=>sum.at(-1)/(width*height)),small=Math.max(1,Math.round(Math.min(width,height)/24)),large=Math.max(2,Math.round(Math.min(width,height)/8));
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  let detail=0,regional=0,contrast=0;
  for(let channel=0;channel<3;channel++){const i=(y*width+x)*4+channel,value=pixels[i],near=mean(channel,x,y,small),far=mean(channel,x,y,large);detail+=Math.abs(value-pixels[(y*width+Math.min(width-1,x+1))*4+channel])+Math.abs(value-pixels[(Math.min(height-1,y+1)*width+x)*4+channel]);regional+=Math.abs(near-far);contrast+=Math.abs(far-global[channel]);}
  const nx=(x+.5)/width,ny=(y+.5)/height,prior=.85+.15*Math.exp(-((nx-.5)**2+(ny-.45)**2)*4);
  // Coherent colour shapes contribute at two scales. High-frequency grain is
  // compressed; no hue is interpreted as skin and off-centre subjects retain energy.
  values[y*width+x]=(Math.sqrt(detail)*2+regional*.8+contrast*.25+4)*prior;
 }
 return values;
}
// A conservative visual cue, not a person detector: only one large connected
// shape on an almost uniform or smooth-gradient image border is accepted. Complex scenes and
// multiple independent marks continue through the existing energy fallback.
export function visualArtworkSubject(pixels,width,height){
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<8||height<8||width*height>65536||pixels?.length<width*height*4)return null;
 const edge=[];for(let x=0;x<width;x++){edge.push(x,(height-1)*width+x);}for(let y=1;y<height-1;y++){edge.push(y*width,y*width+width-1);}
 const median=channel=>{const values=edge.map(i=>pixels[i*4+channel]).sort((a,b)=>a-b);return values[Math.floor(values.length/2)];};
 const bg=[median(0),median(1),median(2),median(3)];
 let distance=i=>{let sum=0;for(let c=0;c<4;c++){const v=pixels[i*4+c]-bg[c];sum+=v*v;}return sum;};
 if(edge.filter(i=>distance(i)<=20*20).length/edge.length<.92){
  // A smooth two-dimensional gradient is still background, not a second
  // object. Fit it from the corners but reject it unless it explains almost
  // the entire border. This deliberately does not extrapolate busy scenery.
  const corners=[0,width-1,(height-1)*width,height*width-1].map(i=>Array.from(pixels.slice(i*4,i*4+4)));
  distance=i=>{const x=(i%width)/(width-1),y=Math.floor(i/width)/(height-1);let sum=0;for(let c=0;c<4;c++){const predicted=corners[0][c]*(1-x)*(1-y)+corners[1][c]*x*(1-y)+corners[2][c]*(1-x)*y+corners[3][c]*x*y,v=pixels[i*4+c]-predicted;sum+=v*v;}return sum;};
  if(edge.filter(i=>distance(i)<=28*28).length/edge.length<.9)return null;
 }
 const mask=new Uint8Array(width*height),queue=new Int32Array(width*height);let total=0;
 for(let i=0;i<mask.length;i++)if(distance(i)>35*35){mask[i]=1;total++;}
 if(total<width*height*.02||total>width*height*.65)return null;
 // Bridge tiny 1-2px gaps inside multi-stroke graphics/illustrations while
 // keeping genuinely separated objects distinct and bounding boxes exact.
 const bridged=new Uint8Array(mask),gap=Math.max(1,Math.round(Math.min(width,height)/48));
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  if(mask[y*width+x]!==1)continue;
  for(let dy=-gap;dy<=gap;dy++){const yy=y+dy;if(yy<0||yy>=height)continue;
   for(let dx=-gap;dx<=gap;dx++){const xx=x+dx;if(xx>=0&&xx<width)bridged[yy*width+xx]=1;}
  }
 }
 let best=null;
 for(let start=0;start<bridged.length;start++){
  if(bridged[start]!==1)continue;let head=0,tail=0,fgCount=0,minX=width,minY=height,maxX=0,maxY=0;
  bridged[start]=2;queue[tail++]=start;
  while(head<tail){const i=queue[head++],x=i%width,y=Math.floor(i/width);
   if(mask[i]===1){fgCount++;minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
   for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){if(!dx&&!dy)continue;const xx=x+dx,yy=y+dy;if(xx<0||xx>=width||yy<0||yy>=height)continue;const next=yy*width+xx;if(bridged[next]===1){bridged[next]=2;queue[tail++]=next;}}
  }
  if(fgCount&&(!best||fgCount>best.count))best={minX,minY,maxX,maxY,count:fgCount};
 }
 if(!best||best.count/total<.78)return null;
 const w=best.maxX-best.minX+1,h=best.maxY-best.minY+1;
 if(w<width*.12||h<height*.12||best.count/(w*h)<.2||(w>width*.92&&h>height*.92))return null;
 return {x:best.minX/width,y:best.minY/height,width:w/width,height:h/height};
}
// Detect solid letterbox or polaroid-style outer borders so the crop locks onto
// the inner photograph instead of empty margins.
export function framedArtworkContent(pixels,width,height){
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<16||height<16||width*height>65536||pixels?.length<width*height*4)return null;
 const pxDist=(i,bg)=>{let s=0;for(let c=0;c<3;c++){const v=pixels[i*4+c]-bg[c];s+=v*v;}return s;};
 const rowMedian=y=>{const rs=[],gs=[],bs=[];for(let x=0;x<width;x++){const i=(y*width+x)*4;rs.push(pixels[i]);gs.push(pixels[i+1]);bs.push(pixels[i+2]);}rs.sort((a,b)=>a-b);gs.sort((a,b)=>a-b);bs.sort((a,b)=>a-b);const m=Math.floor(width/2);return [rs[m],gs[m],bs[m]];};
 const colMedian=x=>{const rs=[],gs=[],bs=[];for(let y=0;y<height;y++){const i=(y*width+x)*4;rs.push(pixels[i]);gs.push(pixels[i+1]);bs.push(pixels[i+2]);}rs.sort((a,b)=>a-b);gs.sort((a,b)=>a-b);bs.sort((a,b)=>a-b);const m=Math.floor(height/2);return [rs[m],gs[m],bs[m]];};
 const rowUniform=(y,bg)=>{let ok=0;for(let x=0;x<width;x++)if(pxDist(y*width+x,bg)<=18*18)ok++;return ok/width>=.94;};
 const colUniform=(x,bg)=>{let ok=0;for(let y=0;y<height;y++)if(pxDist(y*width+x,bg)<=18*18)ok++;return ok/height>=.94;};
 let top=0,bottom=height-1,left=0,right=width-1;
 const topBg=rowMedian(0);while(top<height*.45&&rowUniform(top,topBg))top++;
 const botBg=rowMedian(height-1);while(bottom>height*.55&&rowUniform(bottom,botBg))bottom--;
 const leftBg=colMedian(0);while(left<width*.45&&colUniform(left,leftBg))left++;
 const rightBg=colMedian(width-1);while(right>width*.55&&colUniform(right,rightBg))right--;
 const topFrac=top/height,botFrac=(height-1-bottom)/height,leftFrac=left/width,rightFrac=(width-1-right)/width;
 if(Math.max(topFrac,botFrac,leftFrac,rightFrac)<.1)return null;
 const iw=right-left+1,ih=bottom-top+1;
 if(iw<width*.35||ih<height*.35||iw>width*.92&&ih>height*.92)return null;
 return {x:left/width,y:top/height,width:iw/width,height:ih/height};
}
export function subjectCrop(regions,imageAspect,viewportAspect,options){return compositionCrop(regions,imageAspect,viewportAspect,options);}
export function clearArtworkSubjects(){subjectGeneration++;cache.clear();subjects.clear();pendingSubjects.clear();subjectQualities.clear();subjectRevisions.clear();}
export function subscribeArtworkSubjects(key,notify){key=identity(key);if(!subjectListeners.has(key))subjectListeners.set(key,new Set());const listeners=subjectListeners.get(key);listeners.add(notify);return ()=>{listeners.delete(notify);if(!listeners.size)subjectListeners.delete(key);};}
function subjectQuality(context){
 if(!context)return 0;
 const viewport=context.viewport||context,width=viewport.width,height=viewport.height;
 if(!(Number.isFinite(width)&&width>0&&Number.isFinite(height)&&height>0))return 1;
 const ratio=Math.max(width/height,height/width),pixels=Math.max(width,height)*(Number.isFinite(viewport.pixelRatio)?Math.max(1,viewport.pixelRatio):1);
 return Math.max(ratio>=2.25?3:ratio>=1.4?2:1,pixels>2560?3:pixels>1440?2:1);
}
// Fixed-resolution detectors do not benefit from viewport-based quality upgrades.
// Other callers retain the original viewport-sensitive policy by default.
export function warmArtworkSubjects(key,read,context,{fixedQuality=false}={}){
 key=identity(key);const quality=fixedQuality?1:subjectQuality(context);
 if(subjects.has(key)&&(subjectQualities.get(key)||0)>=quality)return Promise.resolve(subjects.get(key));
 const pending=pendingSubjects.get(key);
 if(pending){if(pending.quality>=quality)return pending.promise;return pending.promise.then(()=>warmArtworkSubjects(key,read,context,{fixedQuality}));}
 const generation=subjectGeneration;
 const task=Promise.resolve().then(()=>read(context)).then(value=>{
  if(!Array.isArray(value)||generation!==subjectGeneration)return [];
  const boxes=value;
  if(subjects.size>=64&&!subjects.has(key)){const oldest=subjects.keys().next().value;subjects.delete(oldest);subjectQualities.delete(oldest);subjectRevisions.delete(oldest);}
  subjects.set(key,boxes);subjectQualities.set(key,value.cacheable===false?0:quality);subjectRevisions.set(key,++analysisRevision);
  for(const sample of cache.get(key)?.samples.values()||[])sample.choices.clear();
  for(const notify of subjectListeners.get(key)||[])notify();return boxes;
 }).catch(()=>[]).finally(()=>{if(pendingSubjects.get(key)?.promise===task)pendingSubjects.delete(key);});
 pendingSubjects.set(key,{promise:task,quality});return task;
}
/** Join analysis already requested by the host before locking first presentation. */
export async function waitArtworkSubjects(key){
 key=identity(key);
 // A higher-quality request may be queued behind the current one.
 for(let i=0;i<3;i++){const task=pendingSubjects.get(key);if(!task)return;await task.promise;}
}
export function artworkFocus(pixels,width,height,{imageAspect=1,viewportAspect=1,viewport,regions=[]}={}){
 const valid=Number.isInteger(width)&&Number.isInteger(height)&&width>=2&&height>=2&&width*height<=262144&&pixels?.length>=width*height*4;
 const energy=valid?energyMap(pixels,width,height):null,visualSubject=valid?(visualArtworkSubject(pixels,width,height)||framedArtworkContent(pixels,width,height)):null;
 return compositionCrop(regions,imageAspect,viewportAspect,{energy,width,height,viewport,visualSubject})||{x:.5,y:.5};
}
function identity(src){try{const url=new URL(src,globalThis.location?.href);for(const key of ['quality','source'])url.searchParams.delete(key);if(url.protocol==='minivoice-art:')url.hostname='artwork';return url.href;}catch{return src;}}
function viewportKey(target){const rounded=value=>Math.round(value*10000)/10000;return `${Math.round(target.width)}x${Math.round(target.height)}:${rounded(target.aspect)}:${target.occlusions.map(box=>[box.x,box.y,box.right,box.bottom,box.weight].map(rounded).join(',')).join(';')}`;}
export function applyArtworkFocus(image,{key=image.currentSrc||image.src,viewportAspect=globalThis.innerWidth/globalThis.innerHeight,viewport,useSubjects=true,coordinateSpace='auto'}={}){
 key=identity(key);let entry=cache.get(key);
 if(!entry){if(cache.size>=128)cache.delete(cache.keys().next().value);entry={samples:new Map()};cache.set(key,entry);}
 const space=['original','preview'].includes(coordinateSpace)?coordinateSpace:'auto',signature=`${space}:${image.naturalWidth}x${image.naturalHeight}`;
 let sample=entry.samples.get(signature);
 if(!sample){
  try{const canvas=document.createElement('canvas'),aspect=image.naturalWidth/Math.max(1,image.naturalHeight);canvas.width=aspect>=1?96:Math.max(8,Math.round(96*aspect));canvas.height=aspect>=1?Math.max(8,Math.round(96/aspect)):96;const context=canvas.getContext('2d',{willReadFrequently:true});context.drawImage(image,0,0,canvas.width,canvas.height);const data=context.getImageData(0,0,canvas.width,canvas.height);sample={pixels:data.data,width:data.width||canvas.width,height:data.height||canvas.height,imageAspect:aspect,choices:new Map()};sample.energy=energyMap(sample.pixels,sample.width,sample.height);sample.visualSubject=visualArtworkSubject(sample.pixels,sample.width,sample.height)||framedArtworkContent(sample.pixels,sample.width,sample.height);}
  catch{sample={imageAspect:image.naturalWidth/image.naturalHeight,choices:new Map()};}
  if(entry.samples.size>=3)entry.samples.delete(entry.samples.keys().next().value);entry.samples.set(signature,sample);
 }
 const target=compositionViewport(viewport,viewportAspect);if(!(Number.isFinite(target.aspect)&&target.aspect>0))target.aspect=1;
 const activeSubjects=useSubjects&&space!=='preview',bucket=`${activeSubjects?'subject':'visual'}:${viewportKey(target)}`;
 let focus=sample.choices.get(bucket);
 if(!focus){const options={imageAspect:sample.imageAspect,viewportAspect:target.aspect,viewport,regions:activeSubjects?(subjects.get(key)||[]):[]};focus=compositionCrop(options.regions,options.imageAspect,target.aspect,{viewport,energy:sample.energy,width:sample.width,height:sample.height,visualSubject:sample.visualSubject})||{x:.5,y:.5};if(sample.choices.size>=8)sample.choices.delete(sample.choices.keys().next().value);sample.choices.set(bucket,focus);}
 return setArtworkAnchor(image,focus);
}

export function setArtworkAnchor(image,focus){image.dataset.focalX=String(focus.x);image.dataset.focalY=String(focus.y);image.style.objectPosition=`${focus.x*100}% ${focus.y*100}%`;const scope=image.closest?.('[data-artwork-mode]');scope?.style.setProperty('--artwork-focal-x',`${focus.x*100}%`);scope?.style.setProperty('--artwork-focal-y',`${focus.y*100}%`);return focus;}

/** A blur layer must reuse the sharp layer's exact crop and counter-transform. */
export function copyArtworkPresentation(reference,layer){
 if(!reference||!layer)return;
 for(const key of ['left','top','width','height','transformOrigin','transform','objectPosition'])layer.style[key]=reference.style[key];
}

/** Visible artwork owns its crop until the image geometry or viewport changes. */
export function stableArtworkFocus(image,options,decisions){
 const viewport=options.viewport||{},key=JSON.stringify([options.key,options.refreshSubjects?(subjectRevisions.get(identity(options.key))||0):0,options.coordinateSpace,Math.round(image.naturalWidth/image.naturalHeight*10000),viewportKey(compositionViewport(viewport,options.viewportAspect))]);
 const prior=decisions.get(key);if(prior)return setArtworkAnchor(image,prior);
 const focus=applyArtworkFocus(image,options);if(decisions.size>=8)decisions.delete(decisions.keys().next().value);decisions.set(key,focus);return focus;
}
