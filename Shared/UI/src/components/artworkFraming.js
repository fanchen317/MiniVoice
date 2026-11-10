const modes=new Set(['center','smart','manual']);
export function normalizeArtworkAnchor(value){return {x:clamp(value?.x),y:clamp(value?.y)};}
function clamp(value){return Number.isFinite(value)?Math.max(0,Math.min(1,value)):.5;}
export function artworkFramingKey(song){return JSON.stringify([String(song?.id??''),String(song?.artworkRevision??'legacy')]);}
export function normalizeArtworkFraming(value){
 const anchors=Object.fromEntries(Object.entries(value?.anchors||{}).filter(([,anchor])=>Number.isFinite(anchor?.x)&&Number.isFinite(anchor?.y)).slice(-256).map(([key,anchor])=>[key,normalizeArtworkAnchor(anchor)]));
 return {mode:modes.has(value?.mode)?value.mode:'smart',anchors};
}
export function updateArtworkAnchor(value,key,anchor){const config=normalizeArtworkFraming(value),anchors={...config.anchors};delete anchors[key];anchors[key]=normalizeArtworkAnchor(anchor);return normalizeArtworkFraming({...config,anchors});}
export function coverGeometry(imageWidth,imageHeight,width,height){
 const scale=Math.max(width/Math.max(1,imageWidth),height/Math.max(1,imageHeight));
 return {overflowX:Math.max(0,imageWidth*scale-width),overflowY:Math.max(0,imageHeight*scale-height),portrait:height>=width};
}
export function dragArtworkAnchor(anchor,dx,dy,geometry){
 const start=normalizeArtworkAnchor(anchor),{portrait,overflowX,overflowY}=geometry;
 return normalizeArtworkAnchor({x:portrait&&overflowX>.5?start.x-dx/overflowX:start.x,y:!portrait&&overflowY>.5?start.y-dy/overflowY:start.y});
}
