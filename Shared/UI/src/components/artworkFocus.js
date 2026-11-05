import {compositionCrop} from './artworkComposition.js';
// Analyze one bounded thumbnail per artwork identity, shared by preview/detail.
const cache=new Map(),subjects=new Map(),pendingSubjects=new Map(),subjectListeners=new Map();
function energyMap(pixels,width,height){
 const values=new Float32Array(width*height);
 let meanR=0,meanG=0,meanB=0;for(let i=0;i<pixels.length;i+=4){meanR+=pixels[i];meanG+=pixels[i+1];meanB+=pixels[i+2];}const count=width*height;meanR/=count;meanG/=count;meanB/=count;
 for(let y=1;y<height-1;y++)for(let x=1;x<width-1;x++){
  const i=(y*width+x)*4,j=i+4,k=i+width*4,r=pixels[i],g=pixels[i+1],b=pixels[i+2];
  const detail=Math.abs(r-pixels[j])+Math.abs(g-pixels[j+1])+Math.abs(b-pixels[j+2])+Math.abs(r-pixels[k])+Math.abs(g-pixels[k+1])+Math.abs(b-pixels[k+2]);
  const nx=x/(width-1),ny=y/(height-1),center=Math.exp(-((nx-.5)**2+(ny-.43)**2)*4);
  // Colour contrast is independent of skin colour; compress high-frequency
  // edges so grain and tiny lettering cannot dominate a broad visual subject.
  const contrast=(Math.abs(r-meanR)+Math.abs(g-meanG)+Math.abs(b-meanB))/3;
  values[y*width+x]=(Math.sqrt(detail)*10+Math.min(80,contrast)*.4+4)*center;
 }
 return values;
}
export function subjectCrop(regions,imageAspect,viewportAspect){return compositionCrop(regions,imageAspect,viewportAspect);}
export function subscribeArtworkSubjects(key,notify){key=identity(key);if(!subjectListeners.has(key))subjectListeners.set(key,new Set());const listeners=subjectListeners.get(key);listeners.add(notify);return ()=>{listeners.delete(notify);if(!listeners.size)subjectListeners.delete(key);};}
export function warmArtworkSubjects(key,read){
 key=identity(key);if(subjects.has(key))return Promise.resolve(subjects.get(key));if(pendingSubjects.has(key))return pendingSubjects.get(key);
 const task=Promise.resolve().then(read).then(value=>{const boxes=Array.isArray(value)?value:[];if(subjects.size>=64)subjects.delete(subjects.keys().next().value);subjects.set(key,boxes);cache.get(key)?.choices.clear();for(const notify of subjectListeners.get(key)||[])notify();return boxes;}).catch(()=>[]).finally(()=>pendingSubjects.delete(key));pendingSubjects.set(key,task);return task;
}
export function artworkFocus(pixels,width,height,{imageAspect=1,viewportAspect=1,regions=[]}={}){
 const energy=energyMap(pixels,width,height);
 const subject=compositionCrop(regions,imageAspect,viewportAspect,{energy,width,height});if(subject)return subject;
 const cropWidth=Math.min(1,viewportAspect/imageAspect),cropHeight=Math.min(1,imageAspect/viewportAspect);
 let total=0,cx=0,cy=0;energy.forEach((weight,i)=>{total+=weight;cx+=(i%width)/(width-1)*weight;cy+=Math.floor(i/width)/(height-1)*weight;});
 if(!total)return {x:.5,y:.5};
 const centroid={x:Math.max(.3,Math.min(.7,cx/total)),y:Math.max(.3,Math.min(.65,cy/total))};
 if(cropWidth>.995&&cropHeight>.995)return centroid;
 // Score the complete visible crop window, rather than putting its center on a
 // weighted point that may cut the important region in half.
 const horizontal=cropWidth<1,extent=horizontal?cropWidth:cropHeight,travel=1-extent;let best=-Infinity,start=travel*.5;
 for(let n=0;n<=32;n++){
  const at=travel*n/32;let score=0;
  energy.forEach((weight,i)=>{const coordinate=horizontal?(i%width+.5)/width:(Math.floor(i/width)+.5)/height;if(coordinate>=at&&coordinate<=at+extent)score+=weight;});
  const middle=at+extent/2,preferred=horizontal?.5:.43;score-=total*.16*Math.abs(middle-preferred);
  if(score>best){best=score;start=at;}
 }
 const position=travel>0?start/travel:.5;
 return horizontal?{x:position,y:centroid.y}:{x:centroid.x,y:position};
}
function identity(src){try{const url=new URL(src,globalThis.location?.href);for(const key of ['quality','source'])url.searchParams.delete(key);if(url.protocol==='minivoice-art:')url.hostname='artwork';return url.href;}catch{return src;}}
export function applyArtworkFocus(image,{key=image.currentSrc||image.src,viewportAspect=globalThis.innerWidth/globalThis.innerHeight,useSubjects=true}={}){
 key=identity(key);let sample=cache.get(key);
 if(!sample){try{const canvas=document.createElement('canvas');canvas.width=canvas.height=96;const context=canvas.getContext('2d',{willReadFrequently:true});context.drawImage(image,0,0,96,96);const data=context.getImageData(0,0,96,96);sample={pixels:data.data,width:data.width||Math.sqrt(data.data.length/4),height:data.height||Math.sqrt(data.data.length/4),imageAspect:image.naturalWidth/image.naturalHeight,choices:new Map()};}catch{sample={choices:new Map()};}if(cache.size>=128)cache.delete(cache.keys().next().value);cache.set(key,sample);}
 const aspect=Number.isFinite(viewportAspect)&&viewportAspect>0?viewportAspect:1,bucket=`${useSubjects?'subject':'visual'}:${Math.round(aspect*1000)/1000}`;
 let focus=sample.choices.get(bucket);if(!focus){focus=(sample.pixels?artworkFocus(sample.pixels,sample.width,sample.height,{imageAspect:sample.imageAspect,viewportAspect:aspect,regions:useSubjects?(subjects.get(key)||[]):[]}):(useSubjects?compositionCrop(subjects.get(key)||[],image.naturalWidth/image.naturalHeight,aspect):null)||{x:.5,y:.5});if(sample.choices.size>=8)sample.choices.delete(sample.choices.keys().next().value);sample.choices.set(bucket,focus);}
 return setArtworkAnchor(image,focus);
}

export function setArtworkAnchor(image,focus){image.dataset.focalX=String(focus.x);image.dataset.focalY=String(focus.y);image.style.objectPosition=`${focus.x*100}% ${focus.y*100}%`;const scope=image.closest?.('[data-artwork-mode]');scope?.style.setProperty('--artwork-focal-x',`${focus.x*100}%`);scope?.style.setProperty('--artwork-focal-y',`${focus.y*100}%`);return focus;}

/** A blur layer must reuse the sharp layer's exact crop and counter-transform. */
export function copyArtworkPresentation(reference,layer){
 if(!reference||!layer)return;
 for(const key of ['left','top','width','height','transformOrigin','transform','objectPosition'])layer.style[key]=reference.style[key];
}
