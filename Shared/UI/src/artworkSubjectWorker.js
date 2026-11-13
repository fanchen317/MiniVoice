// Decode and orientation stay with the image element. This worker owns all
// model initialization, preprocessing and inference on those decoded pixels.
import * as ort from 'onnxruntime-web/wasm';
import {detectArtworkFaces} from './components/artworkFaceDetector.js';
import {detectArtworkText} from './components/artworkTextDetector.js';
import {detectArtworkPeople} from './components/artworkPersonDetector.js';
import {dedupeArtworkFaces,rescueArtworkFaces} from './components/artworkFaceRescue.js';
import {artworkRetinaCandidates,detectArtworkRetinaFaces,filterArtworkRetinaFaces} from './components/artworkRetinaFace.js';

const wasmURL=new URL('../node_modules/onnxruntime-web/dist/ort-wasm-simd-threaded.wasm',import.meta.url).href;
const wasmModuleURL=new URL('../node_modules/onnxruntime-web/dist/ort-wasm-simd-threaded.mjs',import.meta.url).href;
const faceURL=new URL('./assets/artwork-models/face_detection_yunet_2023mar.onnx',import.meta.url).href;
const textURL=new URL('./assets/artwork-models/ppocr-v4-text-det.onnx',import.meta.url).href;
const personURL=new URL('./assets/artwork-models/yolox-nano-coco.onnx',import.meta.url).href;
const retinaURL=new URL('./assets/artwork-models/retinaface-mobilenet025.onnx',import.meta.url).href;
let runtimePromise,retinaPromise;
function retina(){
 if(!retinaPromise)retinaPromise=ort.InferenceSession.create(retinaURL,{executionProviders:['wasm']}).catch(error=>{retinaPromise=null;throw error;});
 return retinaPromise;
}
async function runtime(){
 if(!runtimePromise)runtimePromise=(async()=>{
  ort.env.wasm.numThreads=1;
  ort.env.wasm.wasmPaths={mjs:wasmModuleURL,wasm:wasmURL};
  const response=await fetch(wasmURL);if(!response.ok)throw Error('Artwork runtime unavailable');
  ort.env.wasm.wasmBinary=await response.arrayBuffer();
  const options={executionProviders:['wasm']};
  const [face,text,person]=await Promise.all([ort.InferenceSession.create(faceURL,options),ort.InferenceSession.create(textURL,options),ort.InferenceSession.create(personURL,options)]);
  return {face,text,person};
 })().catch(error=>{runtimePromise=null;throw error;});
 return runtimePromise;
}
self.onmessage=async event=>{
 const {id,pixels:buffer,width,height}=event.data||{};
 try{
  const pixels=new Uint8ClampedArray(buffer),{face,text,person}=await runtime();
  let faces=await detectArtworkFaces({ort,session:face,pixels,width,height});
  const people=await detectArtworkPeople({ort,session:person,pixels,width,height});
  faces=await rescueArtworkFaces({faces,people,pixels,width,height,detect:(data,w,h)=>detectArtworkFaces({ort,session:face,pixels:data,width:w,height:h})});
  let cacheable=true;
  const candidates=artworkRetinaCandidates(faces,people);
  if(candidates.length){
   try{
    const found=filterArtworkRetinaFaces(await detectArtworkRetinaFaces({ort,session:await retina(),pixels,width,height}),candidates);
    for(const candidate of found){if(faces.length>=16)break;faces=dedupeArtworkFaces([...faces,candidate]);}
   }
   catch{cacheable=false;}
  }
  const texts=await detectArtworkText({ort,session:text,rgba:pixels,width,height});
  self.postMessage({id,regions:[...faces,...people,...texts],cacheable});
 }catch(error){self.postMessage({id,error:String(error?.message||error)});}
};
