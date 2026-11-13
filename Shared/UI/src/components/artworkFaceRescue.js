// A bounded second look for small faces. All boxes stay in source coordinates.
const clamp=(value,low,high)=>Math.max(low,Math.min(high,value));
function overlap(a,b){
 const x=Math.max(0,Math.min(a.x+a.width,b.x+b.width)-Math.max(a.x,b.x));
 const y=Math.max(0,Math.min(a.y+a.height,b.y+b.height)-Math.max(a.y,b.y));
 return x*y;
}
function duplicate(a,b){const common=overlap(a,b),aa=a.width*a.height,bb=b.width*b.height;return common/Math.min(aa,bb)>.8||common/(aa+bb-common)>.45;}

// Find a single coherent object against a genuinely uniform frame. This is a
// weak visual cue, not a person detector; ambiguous/background-heavy art is
// intentionally rejected. It can trigger only one additional face pass.
export function isolatedArtworkSubject(pixels,width,height){
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<64||height<64||pixels?.length<width*height*4)return null;
 const n=64,colors=new Uint8Array(n*n*3);let border=0,mean=[0,0,0];
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){
  const px=Math.min(width-1,Math.floor((x+.5)*width/n)),py=Math.min(height-1,Math.floor((y+.5)*height/n)),source=(py*width+px)*4,target=(y*n+x)*3;
  for(let c=0;c<3;c++){colors[target+c]=pixels[source+c];if(x<3||y<3||x>=n-3||y>=n-3)mean[c]+=pixels[source+c];}
  if(x<3||y<3||x>=n-3||y>=n-3)border++;
 }
 mean=mean.map(v=>v/border);let variance=0;
 for(let y=0;y<n;y++)for(let x=0;x<n;x++)if(x<3||y<3||x>=n-3||y>=n-3){const i=(y*n+x)*3;for(let c=0;c<3;c++)variance+=(colors[i+c]-mean[c])**2;}
 const sigma=Math.sqrt(variance/(border*3));if(sigma>12)return null;
 const threshold=Math.max(35,sigma*5),mask=new Uint8Array(n*n),seen=new Uint8Array(n*n),queue=new Uint16Array(n*n);let total=0;
 for(let i=0;i<n*n;i++){let sum=0;for(let c=0;c<3;c++)sum+=(colors[i*3+c]-mean[c])**2;if(Math.sqrt(sum/3)>threshold){mask[i]=1;total++;}}
 if(total<n*n*.008||total>n*n*.45)return null;
 let largest=null;
 for(let start=0;start<mask.length;start++){
  if(!mask[start]||seen[start])continue;let head=0,tail=0,minX=n,minY=n,maxX=0,maxY=0;queue[tail++]=start;seen[start]=1;
  while(head<tail){const i=queue[head++],x=i%n,y=Math.floor(i/n);minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);
   for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const xx=x+dx,yy=y+dy,j=yy*n+xx;if((dx||dy)&&xx>=0&&xx<n&&yy>=0&&yy<n&&mask[j]&&!seen[j]){seen[j]=1;queue[tail++]=j;}}
  }
  if(!largest||tail>largest.count)largest={count:tail,minX,minY,maxX,maxY};
 }
 if(!largest||largest.count<total*.7)return null;
 const box={x:largest.minX/n,y:largest.minY/n,width:(largest.maxX+1-largest.minX)/n,height:(largest.maxY+1-largest.minY)/n};
 if(box.width<.06||box.height<.06||box.width*box.height>.5)return null;return box;
}

export function artworkFaceRescueCrops(people,width,height,isolated){
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<2||height<2)return [];
 const candidates=(Array.isArray(people)?people:[]).filter(box=>box&&[box.x,box.y,box.width,box.height,box.confidence].every(Number.isFinite)&&box.width>0&&box.height>0&&box.confidence>=.3).sort((a,b)=>b.confidence-a.confidence);
 const selected=[];for(const box of candidates){if(!selected.some(other=>duplicate(box,other)))selected.push(box);if(selected.length>=2)break;}
 if(!selected.length&&isolated)selected.push(isolated);
 return selected.map(box=>{
  const left=clamp(Math.floor((box.x-box.width*.12)*width),0,width),top=clamp(Math.floor((box.y-box.height*.12)*height),0,height);
  const right=clamp(Math.ceil((box.x+box.width*1.12)*width),0,width),bottom=clamp(Math.ceil((box.y+box.height*1.12)*height),0,height);
  return {left,top,width:right-left,height:bottom-top};
 }).filter(box=>box.width>=2&&box.height>=2&&(box.width<width||box.height<height));
}
export function cropArtworkPixels(pixels,width,height,crop){
 if(pixels?.length<width*height*4||crop.left<0||crop.top<0||crop.left+crop.width>width||crop.top+crop.height>height)throw Error('Invalid face crop');
 const output=new Uint8ClampedArray(crop.width*crop.height*4);for(let y=0;y<crop.height;y++){const start=((crop.top+y)*width+crop.left)*4;output.set(pixels.subarray(start,start+crop.width*4),y*crop.width*4);}return output;
}
export function mapArtworkCropFace(face,crop,width,height){
 const x=clamp((crop.left+face.x*crop.width)/width,0,1),y=clamp((crop.top+face.y*crop.height)/height,0,1);
 const right=clamp((crop.left+(face.x+face.width)*crop.width)/width,0,1),bottom=clamp((crop.top+(face.y+face.height)*crop.height)/height,0,1);
 return {...face,x,y,width:right-x,height:bottom-y};
}
export function dedupeArtworkFaces(faces){
 const result=[];for(const face of [...faces].sort((a,b)=>b.confidence-a.confidence))if(face.width>0&&face.height>0&&!result.some(other=>duplicate(face,other)))result.push(face);return result.slice(0,16);
}
export async function rescueArtworkFaces({faces,people,pixels,width,height,detect}){
 // A person already containing a detected face needs no second pass. Expanding
 // the person box upward tolerates detectors that omit the top of the head.
 const unmatched=people.filter(person=>{
  const padded={x:person.x-person.width*.15,y:person.y-person.height*.3,width:person.width*1.3,height:person.height*1.4};
  return !faces.some(face=>face.width>0&&face.height>0&&overlap(face,padded)/(face.width*face.height)>.5);
 });
 if(faces.length&&!unmatched.length)return faces;
 const isolated=!faces.length&&!people.length?isolatedArtworkSubject(pixels,width,height):null;
 const crops=artworkFaceRescueCrops(unmatched,width,height,isolated),result=[...faces];
 for(const crop of crops){const found=await detect(cropArtworkPixels(pixels,width,height,crop),crop.width,crop.height);for(const face of found)result.push(mapArtworkCropFace(face,crop,width,height));}
 return dedupeArtworkFaces(result);
}
