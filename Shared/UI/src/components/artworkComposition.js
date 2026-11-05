const clamp=(value,low=0,high=1)=>Math.max(low,Math.min(high,value));
const finitePositive=value=>Number.isFinite(value)&&value>0;
const area=box=>Math.max(0,box.right-box.x)*Math.max(0,box.bottom-box.y);
const overlap=(a,b)=>({x:Math.max(a.x,b.x),y:Math.max(a.y,b.y),right:Math.min(a.right,b.right),bottom:Math.min(a.bottom,b.bottom)});

/** Dimensions and exclusions belong to the final background, never an animation frame. */
export function compositionViewport(viewport,viewportAspect){
 const measured=finitePositive(viewport?.width)&&finitePositive(viewport?.height);
 const aspect=measured?viewport.width/viewport.height:viewportAspect;
 const occlusions=(Array.isArray(viewport?.occlusions)?viewport.occlusions:[]).filter(box=>[box.x,box.y,box.width,box.height].every(Number.isFinite)&&box.width>0&&box.height>0).slice(0,16).map(box=>({x:clamp(box.x),y:clamp(box.y),right:clamp(box.x+box.width),bottom:clamp(box.y+box.height),weight:clamp(Number.isFinite(box.weight)?box.weight:.85)})).filter(box=>area(box)>0&&box.weight>0);
 return {aspect,width:measured?viewport.width:0,height:measured?viewport.height:0,occlusions};
}

function subjectBoxes(regions){
 const boxes=(Array.isArray(regions)?regions:[]).filter(box=>[box.x,box.y,box.width,box.height].every(Number.isFinite)&&box.width>0&&box.height>0).slice(0,48).map(region=>{
  const core={x:clamp(region.x),y:clamp(region.y),right:clamp(region.x+region.width),bottom:clamp(region.y+region.height)};
  const face=region.face===1||region.face===true,text=region.text===1||region.text===true,person=region.person===1||region.person===true;
  const confidence=clamp(Number.isFinite(region.confidence)?region.confidence:.8,.1,1);
  const padded={x:clamp(core.x-(face?region.width*.18:text?.012:region.width*.035)),y:clamp(core.y-(face?region.height*.65:text?.012:region.height*.035)),right:clamp(core.right+(face?region.width*.18:text?.012:region.width*.035)),bottom:clamp(core.bottom+(face?region.height*.2:text?.012:region.height*.035))};
  return {core,padded,face,text,person,confidence,weight:(face?5:person?2.2:text?1.4:1.8)*confidence*Math.max(.35,Math.sqrt(area(core)))};
 }).filter(box=>area(box.core)>0).sort((a,b)=>b.confidence-a.confidence||area(b.core)-area(a.core));
 // Deduplicate in two dimensions: two band members at different heights must
 // remain distinct even when they share the same x interval.
 return boxes.filter((box,index)=>!boxes.some((other,j)=>j<index&&other.face===box.face&&other.text===box.text&&other.person===box.person&&area(overlap(other.core,box.core))/(area(other.core)+area(box.core)-area(overlap(other.core,box.core)))>.82)).slice(0,32);
}

function energyProfile(energy,width,height,horizontal){
 if(!energy||!Number.isInteger(width)||!Number.isInteger(height)||width<2||height<2||width*height>262144||energy.length<width*height)return null;
 const values=new Float64Array(horizontal?width:height),coarse=new Float64Array(24*24);let total=0,cx=0,cy=0;
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  const value=energy[y*width+x];if(!Number.isFinite(value)||value<=0)continue;
  values[horizontal?x:y]+=value;coarse[Math.min(23,Math.floor(y*24/height))*24+Math.min(23,Math.floor(x*24/width))]+=value;total+=value;cx+=(x+.5)/width*value;cy+=(y+.5)/height*value;
 }
 if(!total)return null;
 const prefix=new Float64Array(values.length+1);let maximum=0;for(let i=0;i<values.length;i++){prefix[i+1]=prefix[i]+values[i];maximum=Math.max(maximum,values[i]);}
 const integral=position=>{const at=clamp(position)*values.length,index=Math.min(values.length-1,Math.floor(at));return prefix[index]+(at-index)*values[index];};
 return {values,coarse,total,cx:cx/total,cy:cy/total,integral,max:maximum};
}

/** A bounded max-opacity mask avoids double-counting overlapping lyrics and controls. */
function exclusionMask(occlusions){
 if(!occlusions.length)return null;
 const n=32,cells=new Float32Array(n*n),prefix=new Float64Array((n+1)*(n+1));
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){
  const cell={x:x/n,y:y/n,right:(x+1)/n,bottom:(y+1)/n};let value=0;
  for(const box of occlusions)value=Math.max(value,box.weight*area(overlap(cell,box))*n*n);
  cells[y*n+x]=value;prefix[(y+1)*(n+1)+x+1]=value+prefix[(y+1)*(n+1)+x]+prefix[y*(n+1)+x+1]-prefix[y*(n+1)+x];
 }
 const integral=(x,y)=>{const sx=clamp(x)*n,sy=clamp(y)*n,ix=Math.min(n-1,Math.floor(sx)),iy=Math.min(n-1,Math.floor(sy)),fx=sx-ix,fy=sy-iy,at=iy*(n+1)+ix;return (prefix[at]+fx*(prefix[at+1]-prefix[at])+fy*(prefix[at+n+1]-prefix[at])+fx*fy*cells[iy*n+ix])/(n*n);};
 return {at:(x,y)=>cells[Math.min(n-1,Math.max(0,Math.floor(y*n)))*n+Math.min(n-1,Math.max(0,Math.floor(x*n)))],covered:box=>Math.max(0,integral(box.right,box.bottom)-integral(box.x,box.bottom)-integral(box.right,box.y)+integral(box.x,box.y))};
}

/** Cover geometry has one travelling axis; all scoring uses full 2D subject boxes. */
export function compositionCrop(regions,imageAspect,viewportAspect,{energy,width,height,viewport}={}){
 const target=compositionViewport(viewport,viewportAspect);viewportAspect=target.aspect;
 if(!finitePositive(imageAspect)||!finitePositive(viewportAspect))return null;
 const horizontal=viewportAspect<imageAspect,cw=Math.min(1,viewportAspect/imageAspect),ch=Math.min(1,imageAspect/viewportAspect),extent=horizontal?cw:ch,travel=1-extent;
 const boxes=subjectBoxes(regions),visual=energyProfile(energy,width,height,horizontal),mask=exclusionMask(target.occlusions);
 if(!boxes.length&&!visual)return null;
 if(travel<.001)return boxes.length?{x:.5,y:.5}:{x:clamp(visual.cx,.3,.7),y:clamp(visual.cy,.3,.65)};
 const low=box=>horizontal?box.x:box.y,high=box=>horizontal?box.right:box.bottom;
 const primary=boxes.some(box=>box.face)?boxes.filter(box=>box.face):boxes.filter(box=>box.text);
 const groupStart=Math.min(...primary.map(box=>low(box.padded))),groupEnd=Math.max(...primary.map(box=>high(box.padded)));
 const protectGroup=primary.length>0&&groupEnd-groupStart<=extent;
 const candidates=new Set([travel/2]);for(let i=0;i<=192;i++)candidates.add(travel*i/192);
 for(const box of boxes){
  for(const rect of [box.core,box.padded]){
   for(const value of [low(rect),high(rect)-extent,(low(rect)+high(rect)-extent)/2])candidates.add(clamp(value,0,travel));
   // Candidate boundaries can place a subject beside the lyrics rather than
   // accepting a coarse grid position that still hides part of the face.
   for(const exclusion of target.occlusions)for(const value of [high(rect)-low(exclusion)*extent,low(rect)-high(exclusion)*extent])candidates.add(clamp(value,0,travel));
  }
 }
 const totalWeight=boxes.reduce((sum,box)=>sum+box.weight,0);
 let best=-Infinity,start=travel/2;
 for(const at of candidates){
  if(protectGroup&&(at>groupStart+1e-8||at+extent<groupEnd-1e-8))continue;
  const crop={x:horizontal?at:0,y:horizontal?0:at,right:horizontal?at+cw:1,bottom:horizontal?1:at+ch};let score=0;
  for(const box of boxes){
   const core=clamp(area(overlap(box.core,crop))/area(box.core)),padded=clamp(area(overlap(box.padded,crop))/area(box.padded));let value=core*core*2+padded*.45;
   if(core>.999)value+=.65;
   if(core>0&&core<.999)value-=(box.face?1.2:box.text?.55:.15)*(1-core);
   if(box.face&&!horizontal&&at>box.core.y&&at<box.core.bottom)value-=.8;
   if(mask){const projected={x:(box.core.x-crop.x)/cw,y:(box.core.y-crop.y)/ch,right:(box.core.right-crop.x)/cw,bottom:(box.core.bottom-crop.y)/ch};const hidden=mask.covered(projected)/area(projected);value-=hidden*(box.face?2.6:box.text?1.7:1.2);}
   score+=box.weight*value;
  }
  if(totalWeight)score/=totalWeight;
  if(visual){
   const retained=(visual.integral(at+extent)-visual.integral(at))/visual.total;
   score+=(boxes.length?.18:1)*retained;
   // Penalize slicing through a high-energy object; this is a secondary cue,
   // never a reason to violate an otherwise feasible face-group constraint.
   const n=visual.values.length,border=(visual.values[Math.min(n-1,Math.floor(at*n))]+visual.values[Math.min(n-1,Math.floor((at+extent)*n))])/(2*visual.max||1);
   score-=(boxes.length?.01:.05)*border;
   if(mask){let unobscured=0;for(let y=0;y<24;y++)for(let x=0;x<24;x++){const ix=(x+.5)/24,iy=(y+.5)/24;if(ix<crop.x||ix>crop.right||iy<crop.y||iy>crop.bottom)continue;unobscured+=visual.coarse[y*24+x]*(1-mask.at((ix-crop.x)/cw,(iy-crop.y)/ch));}score+=(boxes.length?.08:.35)*unobscured/visual.total;}
  }
  // Pixel contrast alone is weaker evidence than a detected subject. Keep
  // abstract art near its original composition rather than chasing busy edges.
  score-=(boxes.length?.06:.18)*Math.abs(at-travel/2)/travel;
  if(score>best+1e-9){best=score;start=at;}
 }
 return horizontal?{x:clamp(start/travel),y:.5}:{x:.5,y:clamp(start/travel)};
}
