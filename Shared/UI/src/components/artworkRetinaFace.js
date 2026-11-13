// RetinaFace MobileNetV1-0.25, 640px BGR input. Priors and box decoding follow
// https://github.com/yakhyo/retinaface-pytorch (MIT); coordinates are mapped
// back from aspect-preserving padding to the original artwork.
import {artworkFaceInput} from './artworkFaceDetector.js';

const SIZE=640,STEPS=[8,16,32],MIN_SIZES=[[16,32],[64,128],[256,512]];
const clamp=(value,low,high)=>Math.max(low,Math.min(high,value));
const intersection=(a,b)=>Math.max(0,Math.min(a.x+a.width,b.x+b.width)-Math.max(a.x,b.x))*Math.max(0,Math.min(a.y+a.height,b.y+b.height)-Math.max(a.y,b.y));
const iou=(a,b)=>{const common=intersection(a,b);return common/(a.width*a.height+b.width*b.height-common||1);};

export function artworkRetinaInput(pixels,width,height){
 const input=artworkFaceInput(pixels,width,height),plane=SIZE*SIZE;
 for(let channel=0;channel<3;channel++)for(let i=0;i<plane;i++)input.data[channel*plane+i]-=[104,117,123][channel];
 return input;
}

export function decodeArtworkRetinaFaces(outputs,scaledWidth,scaledHeight,{threshold=.9,nms=.35,limit=8}={}){
 const loc=outputs.loc?.data,confidence=outputs.conf?.data,expected=STEPS.reduce((sum,step)=>sum+(SIZE/step)**2*2,0);
 if(!loc||!confidence||loc.length<expected*4||confidence.length<expected*2||scaledWidth<=0||scaledHeight<=0)throw Error('Invalid RetinaFace output');
 const boxes=[];let i=0;
 for(let level=0;level<STEPS.length;level++){
  const step=STEPS[level],columns=SIZE/step;
  for(let y=0;y<columns;y++)for(let x=0;x<columns;x++)for(const anchor of MIN_SIZES[level]){
   const score=confidence[i*2+1];if(score>=threshold&&score<=1){
    const cx=(x+.5)*step+loc[i*4]*.1*anchor,cy=(y+.5)*step+loc[i*4+1]*.1*anchor;
    const width=anchor*Math.exp(loc[i*4+2]*.2),height=anchor*Math.exp(loc[i*4+3]*.2);
    if([cx,cy,width,height].every(Number.isFinite)){
     const left=clamp((cx-width/2)/scaledWidth,0,1),top=clamp((cy-height/2)/scaledHeight,0,1),right=clamp((cx+width/2)/scaledWidth,0,1),bottom=clamp((cy+height/2)/scaledHeight,0,1);
     if(right>left&&bottom>top)boxes.push({x:left,y:top,width:right-left,height:bottom-top,face:1,confidence:score});
    }
   }i++;
  }
 }
 boxes.sort((a,b)=>b.confidence-a.confidence);const result=[];
 for(const box of boxes){if(!result.some(other=>iou(box,other)>nms))result.push(box);if(result.length>=limit)break;}
 return result;
}

export function artworkRetinaCandidates(faces,people){
 // A new face must be supported by a person that has no matched face yet.
 // When other faces exist, demand a stronger person detection to limit work
 // and false positives in group covers.
 if(faces.length>=16)return [];
 return people.filter(person=>{
  if(!person.person||person.confidence<(faces.length?.55:.35))return false;
  const padded={x:person.x-person.width*.15,y:person.y-person.height*.3,width:person.width*1.3,height:person.height*1.4};
  return !faces.some(face=>face.width>0&&face.height>0&&intersection(face,padded)/(face.width*face.height)>.5);
 });
}
export function filterArtworkRetinaFaces(faces,people){
 return faces.filter(face=>people.some(person=>{
  const padded={x:person.x-person.width*.15,y:person.y-person.height*.3,width:person.width*1.3,height:person.height*1.4};
  return intersection(face,padded)/(face.width*face.height)>.5;
 }));
}
export async function detectArtworkRetinaFaces({ort,session,pixels,width,height}){
 const {data,scaledWidth,scaledHeight}=artworkRetinaInput(pixels,width,height);
 const output=await session.run({[session.inputNames[0]]:new ort.Tensor('float32',data,[1,3,SIZE,SIZE])});
 return decodeArtworkRetinaFaces(output,scaledWidth,scaledHeight);
}
