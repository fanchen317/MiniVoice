// Analyze one bounded thumbnail per artwork identity, shared by preview/detail.
const cache=new Map(),subjects=new Map(),pendingSubjects=new Map();
function energyMap(pixels,width,height){
 const values=new Float32Array(width*height);
 for(let y=1;y<height-1;y++)for(let x=1;x<width-1;x++){
  const i=(y*width+x)*4,j=i+4,k=i+width*4,r=pixels[i],g=pixels[i+1],b=pixels[i+2];
  const detail=Math.abs(r-pixels[j])+Math.abs(g-pixels[j+1])+Math.abs(b-pixels[j+2])+Math.abs(r-pixels[k])+Math.abs(g-pixels[k+1])+Math.abs(b-pixels[k+2]);
  const nx=x/(width-1),ny=y/(height-1),center=Math.exp(-((nx-.5)**2+(ny-.43)**2)*4);
  // Warm mid-tone regions are a modest extra cue, never a face-recognition claim.
  const warm=r>65&&g>35&&b>20&&r>g&&r>b&&r-g<95&&r-b>12?35:0;
  values[y*width+x]=(detail+warm+4)*center;
 }
 return values;
}
export function subjectCrop(regions,imageAspect,viewportAspect){
 const crop={x:Math.min(1,viewportAspect/imageAspect),y:Math.min(1,imageAspect/viewportAspect)};
 const boxes=(regions||[]).filter(r=>[r.x,r.y,r.width,r.height].every(Number.isFinite)&&r.width>0&&r.height>0).map(r=>{const face=r.face!==0;return {x:Math.max(0,r.x-r.width*(face?.18:0)),y:Math.max(0,r.y-r.height*(face?.65:0)),right:Math.min(1,r.x+r.width*(face?1.18:1)),bottom:Math.min(1,r.y+r.height*(face?1.2:1)),face,area:r.width*r.height};});
 if(!boxes.length)return null;boxes.sort((a,b)=>Number(b.face)-Number(a.face)||b.area-a.area);
 let protectedBox=boxes[0];const group={x:Math.min(...boxes.map(r=>r.x)),y:Math.min(...boxes.map(r=>r.y)),right:Math.max(...boxes.map(r=>r.right)),bottom:Math.max(...boxes.map(r=>r.bottom))};
 if(group.right-group.x<=crop.x&&group.bottom-group.y<=crop.y)protectedBox=group;
 const axis=(start,end,extent,vertical)=>{const travel=1-extent;if(travel<.001)return .5;const lower=Math.max(0,end-extent),upper=Math.min(travel,start);const ideal=(start+end-extent)/2;
  // If an extreme aspect makes the full head impossible, preserve its top
  // instead of centering on the face and silently shaving off the hair.
  const at=lower<=upper?Math.max(lower,Math.min(upper,ideal)):Math.max(0,Math.min(travel,vertical?start:ideal));return at/travel;};
 return {x:axis(protectedBox.x,protectedBox.right,crop.x,false),y:axis(protectedBox.y,protectedBox.bottom,crop.y,true)};
}
export function warmArtworkSubjects(key,read){
 key=identity(key);if(subjects.has(key))return Promise.resolve(subjects.get(key));if(pendingSubjects.has(key))return pendingSubjects.get(key);
 const task=Promise.resolve().then(read).then(value=>{const boxes=Array.isArray(value)?value:[];if(subjects.size>=64)subjects.delete(subjects.keys().next().value);subjects.set(key,boxes);cache.get(key)?.choices.clear();return boxes;}).catch(()=>[]).finally(()=>pendingSubjects.delete(key));pendingSubjects.set(key,task);return task;
}
export function artworkFocus(pixels,width,height,{imageAspect=1,viewportAspect=1,regions=[]}={}){
 const subject=subjectCrop(regions,imageAspect,viewportAspect);if(subject)return subject;
 const energy=energyMap(pixels,width,height),cropWidth=Math.min(1,viewportAspect/imageAspect),cropHeight=Math.min(1,imageAspect/viewportAspect);
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
 if(!sample){try{const canvas=document.createElement('canvas');canvas.width=canvas.height=32;const context=canvas.getContext('2d',{willReadFrequently:true});context.drawImage(image,0,0,32,32);sample={pixels:context.getImageData(0,0,32,32).data,imageAspect:image.naturalWidth/image.naturalHeight,choices:new Map()};}catch{sample={choices:new Map()};}if(cache.size>=128)cache.delete(cache.keys().next().value);cache.set(key,sample);}
 const aspect=Number.isFinite(viewportAspect)&&viewportAspect>0?viewportAspect:1,bucket=`${useSubjects?'subject':'visual'}:${Math.round(aspect*20)/20}`;
 let focus=sample.choices.get(bucket);if(!focus){focus=sample.pixels?artworkFocus(sample.pixels,32,32,{imageAspect:sample.imageAspect,viewportAspect:aspect,regions:useSubjects?(subjects.get(key)||[]):[]}):{x:.5,y:.5};if(sample.choices.size>=8)sample.choices.delete(sample.choices.keys().next().value);sample.choices.set(bucket,focus);}
 return setArtworkAnchor(image,focus);
}

export function setArtworkAnchor(image,focus){image.dataset.focalX=String(focus.x);image.dataset.focalY=String(focus.y);image.style.objectPosition=`${focus.x*100}% ${focus.y*100}%`;return focus;}
