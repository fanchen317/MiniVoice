const clamp=(value,low=0,high=1)=>Math.max(low,Math.min(high,value));
const finitePositive=value=>Number.isFinite(value)&&value>0;
const area=box=>Math.max(0,box.right-box.x)*Math.max(0,box.bottom-box.y);
const overlap=(a,b)=>({x:Math.max(a.x,b.x),y:Math.max(a.y,b.y),right:Math.min(a.right,b.right),bottom:Math.min(a.bottom,b.bottom)});

/** Dimensions and exclusions belong to the final background, never an animation frame. */
export function compositionViewport(viewport,viewportAspect){
 const measured=finitePositive(viewport?.width)&&finitePositive(viewport?.height);
 const aspect=measured?viewport.width/viewport.height:viewportAspect;
 const occlusions=(Array.isArray(viewport?.occlusions)?viewport.occlusions:[]).filter(box=>box&&[box.x,box.y,box.width,box.height].every(Number.isFinite)&&box.width>0&&box.height>0).slice(0,16).map(box=>({x:clamp(box.x),y:clamp(box.y),right:clamp(box.x+box.width),bottom:clamp(box.y+box.height),weight:clamp(Number.isFinite(box.weight)?box.weight:.85)})).filter(box=>area(box)>0&&box.weight>0);
 return {aspect,width:measured?viewport.width:0,height:measured?viewport.height:0,occlusions};
}

function subjectBoxes(regions){
 const boxes=(Array.isArray(regions)?regions:[]).filter(box=>box&&[box.x,box.y,box.width,box.height].every(Number.isFinite)&&box.width>0&&box.height>0).slice(0,48).map(region=>{
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

/** Content evidence, rather than image aspect, selects the framing policy.
 * No detections means unknown scenery/abstract content, not a claimed landscape.
 */
export function compositionContent(regions){
 const boxes=subjectBoxes(regions),faces=boxes.filter(b=>b.face&&b.confidence>=.35),people=boxes.filter(b=>b.person&&b.confidence>=.35);
 // A face and its enclosing body describe one person, not two.
 const bodies=people.filter(body=>!faces.some(face=>area(overlap(body.core,face.core))/area(face.core)>.6));
 const count=faces.length+bodies.length;
 const text=boxes.filter(b=>b.text&&b.confidence>=.35);
 // Album titles should not lose to many tiny credit lines. Use relative
 // character height and area, without pretending to understand OCR wording.
 const largestText=Math.max(0,...text.map(b=>area(b.core))),tallestText=Math.max(0,...text.map(b=>b.core.bottom-b.core.y));
 const titles=text.filter(b=>area(b.core)>=largestText*.25&&(b.core.bottom-b.core.y)>=tallestText*.45);
 // The largest and tallest text can be different boxes (e.g. a wide album
 // title next to a thin vertical credit). Avoid ending up with no title at all.
 if(!titles.length&&text.length)titles.push(text.reduce((largest,box)=>area(box.core)>area(largest.core)?box:largest));
 const primaryPeople=[...faces,...bodies];
 return {kind:count>2?'group':count===2?'pair':count===1?'portrait':text.length?'typography':'scenery-or-abstract',count,primary:primaryPeople.length?primaryPeople:titles,boxes};
}

/** Cover geometry has one travelling axis; all scoring uses full 2D subject boxes. */
export function compositionCrop(regions,imageAspect,viewportAspect,{energy,width,height,viewport,visualSubject}={}){
 const target=compositionViewport(viewport,viewportAspect);viewportAspect=target.aspect;
 if(!finitePositive(imageAspect)||!finitePositive(viewportAspect))return null;
 const horizontal=viewportAspect<imageAspect,cw=Math.min(1,viewportAspect/imageAspect),ch=Math.min(1,imageAspect/viewportAspect),extent=horizontal?cw:ch,travel=1-extent;
 const content=compositionContent(regions),boxes=content.boxes,visual=energyProfile(energy,width,height,horizontal),mask=exclusionMask(target.occlusions);
 // Visual evidence is secondary to real detections. A lone isolated shape
 // can be protected on its own, or together with a detected title when both
 // fit; never alter face/person decisions or sacrifice the existing title.
 let visualCue=null;
 const hasOnlyText=boxes.length>0&&boxes.every(box=>box.text);
 if(travel>=.001&&(!boxes.length||hasOnlyText)&&visualSubject&&[visualSubject.x,visualSubject.y,visualSubject.width,visualSubject.height].every(Number.isFinite)){
  const core={x:clamp(visualSubject.x),y:clamp(visualSubject.y),right:clamp(visualSubject.x+visualSubject.width),bottom:clamp(visualSubject.y+visualSubject.height)};
  const axisLow=rect=>horizontal?rect.x:rect.y,axisHigh=rect=>horizontal?rect.right:rect.bottom;
  const titleRects=hasOnlyText?content.primary.map(box=>box.padded):[];
  const groupStart=Math.min(axisLow(core),...titleRects.map(axisLow)),groupEnd=Math.max(axisHigh(core),...titleRects.map(axisHigh));
  if(area(core)>0&&groupEnd-groupStart<=extent+1e-9){
   visualCue={core,padded:core,face:false,text:false,person:false,confidence:1,weight:1};boxes.push(visualCue);
   if(!hasOnlyText){content.primary=[visualCue];content.kind='visual-subject';}
  }
 }
 if(!boxes.length&&!visual)return null;
 if(travel<.001)return boxes.length?{x:.5,y:.5}:{x:clamp(visual.cx,.3,.7),y:clamp(visual.cy,.3,.65)};
 const low=box=>horizontal?box.x:box.y,high=box=>horizontal?box.right:box.bottom;
 const primary=content.primary;
 // A face and its enclosing person count as one subject, but excluding the
 // body from the protection constraint can cut off an otherwise fitting
 // figure just to put the face exactly in the centre. Keep the complete
 // detected figure when the body and padded face fit together; if they do not,
 // retain the existing face-first constraint rather than sacrificing the face.
 const enclosingBodies=boxes.filter(body=>body.person&&body.confidence>=.35&&primary.some(face=>face.face&&area(overlap(body.core,face.core))/area(face.core)>.6));
 const completePeople=[...primary,...enclosingBodies,...(visualCue&&content.kind==='typography'?[visualCue]:[])];
 const completeStart=Math.min(...completePeople.map(box=>low(enclosingBodies.includes(box)?box.core:box.padded))),completeEnd=Math.max(...completePeople.map(box=>high(enclosingBodies.includes(box)?box.core:box.padded)));
 const completeFits=completePeople.length>0&&completeEnd-completeStart<=extent+1e-9;
 const groupStart=completeFits?completeStart:Math.min(...primary.map(box=>low(box.padded))),groupEnd=completeFits?completeEnd:Math.max(...primary.map(box=>high(box.padded)));
 const protectGroup=primary.length>0&&groupEnd-groupStart<=extent+1e-9;
 // Wallpaper framing centres the subject, not the original canvas. Face
 // centres outrank body centres; padded boxes only enforce headroom.
 const coreStart=Math.min(...primary.map(box=>low(box.core))),coreEnd=Math.max(...primary.map(box=>high(box.core)));
 const subjectCentre=(coreStart+coreEnd)/2;
 const centredStart=primary.length?clamp(subjectCentre-extent/2,0,travel):travel/2;
 const candidates=new Set([travel/2,centredStart]);
 if(primary.length)candidates.add(clamp((groupStart+groupEnd-extent)/2,0,travel));for(let i=0;i<=192;i++)candidates.add(travel*i/192);
 for(const box of boxes){
  for(const rect of [box.core,box.padded]){
   for(const value of [low(rect),high(rect)-extent,(low(rect)+high(rect)-extent)/2])candidates.add(clamp(value,0,travel));
   // Candidate boundaries can place a subject beside the lyrics rather than
   // accepting a coarse grid position that still hides part of the face.
   for(const exclusion of target.occlusions)for(const value of [high(rect)-low(exclusion)*extent,low(rect)-high(exclusion)*extent])candidates.add(clamp(value,0,travel));
  }
 }
 // Small credits remain a secondary cue; their count must not outweigh a title.
 const weights=new Map(boxes.map(box=>[box,box.weight*(content.kind==='typography'&&!primary.includes(box)?.15:1)]));
 const totalWeight=boxes.reduce((sum,box)=>sum+weights.get(box),0);
 let best=-Infinity,start=travel/2;
 for(const at of candidates){
  if(protectGroup&&(at>groupStart+1e-8||at+extent<groupEnd-1e-8))continue;
  const crop={x:horizontal?at:0,y:horizontal?0:at,right:horizontal?at+cw:1,bottom:horizontal?1:at+ch};let score=0,leastVisible=1,primaryVisible=0;
  for(const box of boxes){
   const core=clamp(area(overlap(box.core,crop))/area(box.core)),padded=clamp(area(overlap(box.padded,crop))/area(box.padded));let value=core*core*2+padded*.45;
   if(primary.includes(box)){leastVisible=Math.min(leastVisible,core);primaryVisible+=core;}
   if(core>.999)value+=.65;
   if(core>0&&core<.999)value-=(box.face?1.2:box.text?.55:.15)*(1-core);
   if(box.face&&!horizontal&&at>box.core.y&&at<box.core.bottom)value-=.8;
   if(mask){const projected={x:(box.core.x-crop.x)/cw,y:(box.core.y-crop.y)/ch,right:(box.core.right-crop.x)/cw,bottom:(box.core.bottom-crop.y)/ch};const hidden=mask.covered(projected)/area(projected);value-=hidden*(box.face?2.6:box.text?1.7:1.2);}
   score+=weights.get(box)*value;
  }
  if(totalWeight)score/=totalWeight;
  // When a group cannot fit, do not gain a whole-face bonus by deleting
  // another member. Prefer shared coverage before fine visual texture.
  if(primary.length>1&&!protectGroup)score+=leastVisible*3+primaryVisible/primary.length;
  if(primary.length){
   // Normalise by crop size: a displacement occupying a large fraction of a
   // phone wallpaper must not look cheap merely because source travel is small.
   const displacement=Math.abs(at-centredStart)/extent;
   score-=displacement*(content.kind==='portrait'?2.4:content.kind==='pair'||content.kind==='group'?1.2:.45);
  }
  if(content.kind==='typography')score-=primary.filter(box=>{const visible=area(overlap(box.core,crop))/area(box.core);return visible>0&&visible<.999;}).length*.35;
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
