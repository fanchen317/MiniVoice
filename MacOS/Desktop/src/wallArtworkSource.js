import {desktopArtworkCandidate} from '../../../Shared/UI/src/artworkIndexing.js';

// Only the host's strict original route guarantees a matching coordinate space.
export function wallOriginalArtwork(track,detailURL){
 return desktopArtworkCandidate(track,detailURL)?.source||'';
}
export function wallImageCoordinateSpace(src,baseURL){
 try{const url=new URL(src,baseURL);return url.protocol==='minivoice-art:'&&url.hostname==='detail'&&url.searchParams.get('analysis')==='1'?'original':'preview';}catch{return 'preview';}
}
// A missing original must not make expansion or a song handoff unusable. Any
// fallback remains explicitly in preview coordinates and is never persisted.
export async function loadWallWallpaper(originalURL,previewURL,makeImage=()=>new Image()){
 for(const source of [...new Set([originalURL,previewURL].filter(Boolean))]){
  const image=makeImage();image.src=source;
  try{await image.decode();if(image.naturalWidth&&image.naturalHeight)return image;}catch{}
 }
 return null;
}

// A stalled decode or background detector must not make the expand control
// unresponsive. Only return an image once it has decoded successfully.
export async function waitWallWallpaper(imagePromise,analysisPromise,{timeoutMs=280}={}){
 let image=null,timer;
 const loaded=Promise.resolve(imagePromise).then(value=>{image=value;},()=>{});
 const analyzed=Promise.resolve(analysisPromise).catch(()=>{});
 try{await Promise.race([Promise.all([loaded,analyzed]),new Promise(resolve=>{timer=setTimeout(resolve,timeoutMs);})]);return image;}
 finally{clearTimeout(timer);}
}
