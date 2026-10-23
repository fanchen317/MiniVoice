function lyricsWindowState(value={}){
 const number=(key,fallback,min,max)=>Number.isFinite(value[key])?Math.max(min,Math.min(max,value[key])):fallback;
 return {enabled:value.enabled===true,locked:value.locked===true,font:number('font',32,18,64),width:number('width',720,360,2000),height:number('height',200,110,500),x:Number.isFinite(value.x)?value.x:null,y:Number.isFinite(value.y)?value.y:null};
}
module.exports={lyricsWindowState};
