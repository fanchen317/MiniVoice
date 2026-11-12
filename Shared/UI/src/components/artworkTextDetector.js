// PP-OCRv4's detector expects a normalized BGR NCHW tensor. This module is
// runtime-agnostic: the caller owns and reuses the ONNX session and runtime.
const clamp=(v,lo,hi)=>Math.max(lo,Math.min(hi,v));
const mean=[.485,.456,.406],std=[.229,.224,.225];
export function textDetectorInput(rgba,width,height,{maxSide=640}={}){
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1||rgba?.length<width*height*4)throw Error('Invalid artwork pixels');
 const scale=Math.min(1,maxSide/Math.max(width,height));
 const w=Math.max(32,Math.round(width*scale/32)*32),h=Math.max(32,Math.round(height*scale/32)*32),plane=w*h,out=new Float32Array(3*plane);
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){
  const sx=clamp((x+.5)*width/w-.5,0,width-1),sy=clamp((y+.5)*height/h-.5,0,height-1),x0=Math.floor(sx),y0=Math.floor(sy),x1=Math.min(x0+1,width-1),y1=Math.min(y0+1,height-1),fx=sx-x0,fy=sy-y0;
  for(let c=0;c<3;c++){const k=2-c,p=(xx,yy)=>rgba[(yy*width+xx)*4+k],top=p(x0,y0)*(1-fx)+p(x1,y0)*fx,bottom=p(x0,y1)*(1-fx)+p(x1,y1)*fx;out[c*plane+y*w+x]=((top*(1-fy)+bottom*fy)/255-mean[c])/std[c];}
 }
 return {data:out,width:w,height:h};
}
// Bounded connected-component approximation to DB contour post-processing.
// The returned axis-aligned boxes are sufficient for the wallpaper scorer.
export function textProbabilityRegions(data,width,height,{threshold=.3,boxThreshold=.5,limit=10}={}){
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1||data?.length<width*height||width*height>1048576)throw Error('Invalid text probability map');
 const seen=new Uint8Array(width*height),queue=new Int32Array(width*height),regions=[];
 for(let start=0;start<width*height;start++){
  if(seen[start]||!(data[start]>threshold))continue;
  let head=0,tail=0,minX=width,minY=height,maxX=0,maxY=0,sum=0;seen[start]=1;queue[tail++]=start;
  while(head<tail){const index=queue[head++],x=index%width,y=Math.floor(index/width);minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);sum+=data[index];
   for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){if(!dx&&!dy)continue;const nx=x+dx,ny=y+dy;if(nx<0||ny<0||nx>=width||ny>=height)continue;const n=ny*width+nx;if(!seen[n]&&data[n]>threshold){seen[n]=1;queue[tail++]=n;}}
  }
  const bw=maxX-minX+1,bh=maxY-minY+1,confidence=sum/tail;if(tail<4||Math.min(bw,bh)<2||confidence<boxThreshold)continue;
  // DB shrinks text during training. Expand in both axes, clipped to source.
  const pad=Math.max(1,Math.min(bw,bh)*.3),left=clamp((minX-pad)/width,0,1),top=clamp((minY-pad)/height,0,1),right=clamp((maxX+1+pad)/width,0,1),bottom=clamp((maxY+1+pad)/height,0,1);
  regions.push({x:left,y:top,width:right-left,height:bottom-top,text:1,confidence:clamp(confidence,0,1)});
 }
 return regions.sort((a,b)=>b.confidence*Math.sqrt(b.width*b.height)-a.confidence*Math.sqrt(a.width*a.height)).slice(0,limit);
}
export async function detectArtworkText({rgba,width,height,session,ort,maxSide=640}){
 const input=textDetectorInput(rgba,width,height,{maxSide});
 const tensor=new ort.Tensor('float32',input.data,[1,3,input.height,input.width]);
 const result=await session.run({[session.inputNames[0]]:tensor}),output=result[session.outputNames[0]];
 if(!output||output.dims.length!==4||output.dims[0]!==1||output.dims[1]!==1)throw Error('Unexpected text detector output');
 return textProbabilityRegions(output.data,output.dims[3],output.dims[2]);
}
