function lyricsWindowState(value={}){
 const number=(key,fallback,min,max)=>Number.isFinite(value[key])?Math.max(min,Math.min(max,value[key])):fallback;
 return {enabled:value.enabled===true,locked:value.locked===true,font:number('font',32,18,64),width:number('width',720,360,2000),height:number('height',200,110,500),x:Number.isFinite(value.x)?value.x:null,y:Number.isFinite(value.y)?value.y:null};
}
module.exports={lyricsWindowState};
function lyricsUnlockBounds(bounds,workArea){let x=Math.round(bounds.x+bounds.width-38),y=Math.round(bounds.y+6);if(workArea){x=Math.max(workArea.x,Math.min(workArea.x+workArea.width-32,x));y=Math.max(workArea.y,Math.min(workArea.y+workArea.height-32,y));}return {x,y,width:32,height:32};}
module.exports.lyricsUnlockBounds=lyricsUnlockBounds;
