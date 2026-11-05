const clamp=(value,low=0,high=1)=>Math.max(low,Math.min(high,value));
/** Cover geometry is one-dimensional: one image axis always fits exactly. */
export function compositionCrop(regions,imageAspect,viewportAspect,{energy,width,height}={}){
 if(!(imageAspect>0&&viewportAspect>0&&Number.isFinite(imageAspect)&&Number.isFinite(viewportAspect)))return null;
 const horizontal=viewportAspect<imageAspect,extent=Math.min(1,horizontal?viewportAspect/imageAspect:imageAspect/viewportAspect),travel=1-extent;
 const boxes=(regions||[]).filter(r=>[r.x,r.y,r.width,r.height].every(Number.isFinite)&&r.width>0&&r.height>0&&r.x<1&&r.y<1&&r.x+r.width>0&&r.y+r.height>0).slice(0,32).map(r=>{
  const face=r.face===1,text=r.text===1,low=clamp(horizontal?r.x:r.y),high=clamp(horizontal?r.x+r.width:r.y+r.height),padding=face?(horizontal?r.width*.18:r.height*.65):text?.012:0;
  return {low,high,start:clamp(low-padding),end:clamp(high+(face?(horizontal?r.width*.18:r.height*.2):text?.012:0)),face,text,weight:(face?5:text?1.4:1.8)*clamp(Number.isFinite(r.confidence)?r.confidence:.8,.25,1)*Math.max(.35,Math.sqrt(Math.min(1,r.width*r.height)))};
 }).filter(box=>box.high>box.low);
 if(!boxes.length)return null;
 if(travel<.001)return {x:.5,y:.5};
 // Deduplicate overlapping detector boxes: a body/saliency rectangle behind a
 // face must not be counted as several independent subjects.
 const filtered=boxes.filter((box,index)=>!boxes.some((other,j)=>j<index&&other.face===box.face&&other.text===box.text&&Math.abs(other.low-box.low)<.015&&Math.abs(other.high-box.high)<.015));
 const totalWeight=filtered.reduce((sum,box)=>sum+box.weight,0);
 const protectedBoxes=filtered.some(box=>box.face)?filtered.filter(box=>box.face):filtered.filter(box=>box.text);
 const groupStart=Math.min(...protectedBoxes.map(box=>box.start)),groupEnd=Math.max(...protectedBoxes.map(box=>box.end));
 const protectGroup=protectedBoxes.length&&groupEnd-groupStart<=extent;
 const candidates=new Set([travel/2]);for(let i=0;i<=192;i++)candidates.add(travel*i/192);
 for(const box of filtered)for(const value of [box.start,box.end-extent,(box.start+box.end-extent)/2,box.low,box.high-extent])candidates.add(clamp(value,0,travel));
 let profile,prefix,totalEnergy=0;if(energy&&width>0&&height>0){profile=new Float64Array(horizontal?width:height);energy.forEach((value,index)=>{if(Number.isFinite(value)&&value>0)profile[horizontal?index%width:Math.floor(index/width)]+=value;});prefix=new Float64Array(profile.length+1);for(let i=0;i<profile.length;i++)prefix[i+1]=prefix[i]+profile[i];totalEnergy=prefix.at(-1);}
 let best=-Infinity,start=travel/2;
 const coverage=(low,high,at)=>clamp((Math.min(high,at+extent)-Math.max(low,at))/(high-low));
 for(const at of candidates){if(protectGroup&&(at>groupStart+1e-8||at+extent<groupEnd-1e-8))continue;let score=0;
  for(const box of filtered){const core=coverage(box.low,box.high,at),padded=coverage(box.start,box.end,at);let value=core*core*2+padded*.45;
   if(core>.999)value+=.65;
   // Cutting a face/text through its interior is worse than a small loss in
   // background detail. Text gets a complete-line preference, not OCR content.
   if(core>0&&core<.999)value-=(box.face?1.2:box.text?.55:.15)*(1-core);
   if(box.face&&!horizontal&&at>box.low&&at<box.high)value-=.8;
   score+=box.weight*value;
  }
  score/=totalWeight;
  if(totalEnergy){const n=profile.length,lo=Math.floor(at*n),hi=Math.min(n,Math.ceil((at+extent)*n));score+=.18*(prefix[hi]-prefix[lo])/totalEnergy;}
  score-=.06*Math.abs(at-travel/2)/travel;
  if(score>best+1e-9){best=score;start=at;}
 }
 return horizontal?{x:clamp(start/travel),y:.5}:{x:.5,y:clamp(start/travel)};
}
