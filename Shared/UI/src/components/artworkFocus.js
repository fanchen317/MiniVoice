import {compositionCrop,compositionViewport} from './artworkComposition.js';
// Bounded samples are keyed by both artwork identity and pixel coordinate space.
// A trimmed list thumbnail is not the same image as an uncropped original.
const cache=new Map(),subjects=new Map(),pendingSubjects=new Map(),subjectQualities=new Map(),subjectListeners=new Map();
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
export function subjectCrop(regions,imageAspect,viewportAspect,options){return compositionCrop(regions,imageAspect,viewportAspect,options);}
export function subscribeArtworkSubjects(key,notify){key=identity(key);if(!subjectListeners.has(key))subjectListeners.set(key,new Set());const listeners=subjectListeners.get(key);listeners.add(notify);return ()=>{listeners.delete(notify);if(!listeners.size)subjectListeners.delete(key);};}
function subjectQuality(context){
 if(!context)return 0;
 const viewport=context.viewport||context,width=viewport.width,height=viewport.height;
 if(!(Number.isFinite(width)&&width>0&&Number.isFinite(height)&&height>0))return 1;
 const ratio=Math.max(width/height,height/width),pixels=Math.max(width,height)*(Number.isFinite(viewport.pixelRatio)?Math.max(1,viewport.pixelRatio):1);
 return Math.max(ratio>=2.25?3:ratio>=1.4?2:1,pixels>2560?3:pixels>1440?2:1);
}
export function warmArtworkSubjects(key,read,context){
 key=identity(key);const quality=subjectQuality(context);
 if(subjects.has(key)&&(subjectQualities.get(key)||0)>=quality)return Promise.resolve(subjects.get(key));
 const pending=pendingSubjects.get(key);
 if(pending){if(pending.quality>=quality)return pending.promise;return pending.promise.then(()=>warmArtworkSubjects(key,read,context));}
 const task=Promise.resolve().then(()=>read(context)).then(value=>{
  const boxes=Array.isArray(value)?value:[];
  if(subjects.size>=64&&!subjects.has(key)){const oldest=subjects.keys().next().value;subjects.delete(oldest);subjectQualities.delete(oldest);}
  subjects.set(key,boxes);subjectQualities.set(key,quality);
  for(const sample of cache.get(key)?.samples.values()||[])sample.choices.clear();
  for(const notify of subjectListeners.get(key)||[])notify();return boxes;
 }).catch(()=>[]).finally(()=>{if(pendingSubjects.get(key)?.promise===task)pendingSubjects.delete(key);});
 pendingSubjects.set(key,{promise:task,quality});return task;
}
export function artworkFocus(pixels,width,height,{imageAspect=1,viewportAspect=1,viewport,regions=[]}={}){
 const valid=Number.isInteger(width)&&Number.isInteger(height)&&width>=2&&height>=2&&width*height<=262144&&pixels?.length>=width*height*4;
 const energy=valid?energyMap(pixels,width,height):null;
 return compositionCrop(regions,imageAspect,viewportAspect,{energy,width,height,viewport})||{x:.5,y:.5};
}
function identity(src){try{const url=new URL(src,globalThis.location?.href);for(const key of ['quality','source'])url.searchParams.delete(key);if(url.protocol==='minivoice-art:')url.hostname='artwork';return url.href;}catch{return src;}}
function viewportKey(target){const rounded=value=>Math.round(value*10000)/10000;return `${Math.round(target.width)}x${Math.round(target.height)}:${rounded(target.aspect)}:${target.occlusions.map(box=>[box.x,box.y,box.right,box.bottom,box.weight].map(rounded).join(',')).join(';')}`;}
export function applyArtworkFocus(image,{key=image.currentSrc||image.src,viewportAspect=globalThis.innerWidth/globalThis.innerHeight,viewport,useSubjects=true,coordinateSpace='auto'}={}){
 key=identity(key);let entry=cache.get(key);
 if(!entry){if(cache.size>=128)cache.delete(cache.keys().next().value);entry={samples:new Map()};cache.set(key,entry);}
 const space=['original','preview'].includes(coordinateSpace)?coordinateSpace:'auto',signature=`${space}:${image.naturalWidth}x${image.naturalHeight}`;
 let sample=entry.samples.get(signature);
 if(!sample){
  try{const canvas=document.createElement('canvas');canvas.width=canvas.height=96;const context=canvas.getContext('2d',{willReadFrequently:true});context.drawImage(image,0,0,96,96);const data=context.getImageData(0,0,96,96);sample={pixels:data.data,width:data.width||Math.sqrt(data.data.length/4),height:data.height||Math.sqrt(data.data.length/4),imageAspect:image.naturalWidth/image.naturalHeight,choices:new Map()};sample.energy=energyMap(sample.pixels,sample.width,sample.height);}
  catch{sample={imageAspect:image.naturalWidth/image.naturalHeight,choices:new Map()};}
  if(entry.samples.size>=3)entry.samples.delete(entry.samples.keys().next().value);entry.samples.set(signature,sample);
 }
 const target=compositionViewport(viewport,viewportAspect);if(!(Number.isFinite(target.aspect)&&target.aspect>0))target.aspect=1;
 const activeSubjects=useSubjects&&space!=='preview',bucket=`${activeSubjects?'subject':'visual'}:${viewportKey(target)}`;
 let focus=sample.choices.get(bucket);
 if(!focus){const options={imageAspect:sample.imageAspect,viewportAspect:target.aspect,viewport,regions:activeSubjects?(subjects.get(key)||[]):[]};focus=compositionCrop(options.regions,options.imageAspect,target.aspect,{viewport,energy:sample.energy,width:sample.width,height:sample.height})||{x:.5,y:.5};if(sample.choices.size>=8)sample.choices.delete(sample.choices.keys().next().value);sample.choices.set(bucket,focus);}
 return setArtworkAnchor(image,focus);
}

export function setArtworkAnchor(image,focus){image.dataset.focalX=String(focus.x);image.dataset.focalY=String(focus.y);image.style.objectPosition=`${focus.x*100}% ${focus.y*100}%`;const scope=image.closest?.('[data-artwork-mode]');scope?.style.setProperty('--artwork-focal-x',`${focus.x*100}%`);scope?.style.setProperty('--artwork-focal-y',`${focus.y*100}%`);return focus;}

/** A blur layer must reuse the sharp layer's exact crop and counter-transform. */
export function copyArtworkPresentation(reference,layer){
 if(!reference||!layer)return;
 for(const key of ['left','top','width','height','transformOrigin','transform','objectPosition'])layer.style[key]=reference.style[key];
}

/** Session-owned decisions: late detection must not pan an already visible cover. */
export function stableArtworkFocus(image,options,decisions){
 const viewport=options.viewport||{},key=JSON.stringify([options.key,options.coordinateSpace,image.naturalWidth,image.naturalHeight,Math.round(viewport.width),Math.round(viewport.height)]);
 const prior=decisions.get(key);if(prior)return setArtworkAnchor(image,prior);
 const focus=applyArtworkFocus(image,options);if(decisions.size>=8)decisions.delete(decisions.keys().next().value);decisions.set(key,focus);return focus;
}
