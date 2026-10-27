function lyricsWindowState(value={}){
 const vertical=value.vertical===true;
 // Migrate only the previous stock profiles; retain custom window sizes.
 if(!vertical&&value.width===720&&value.height===200)value={...value,width:600,height:112};
 if(vertical&&[200,240].includes(value.width)&&value.height===720)value={...value,width:110,height:600};
 const number=(key,fallback,min,max)=>Number.isFinite(value[key])?Math.max(min,Math.min(max,value[key])):fallback;
 return {vertical,enabled:value.enabled===true,locked:value.locked===true,font:number('font',32,18,44),width:number('width',vertical?110:600,vertical?100:360,vertical?500:2000),height:number('height',vertical?600:112,vertical?360:88,vertical?1600:500),x:Number.isFinite(value.x)?value.x:null,y:Number.isFinite(value.y)?value.y:null};
}
module.exports={lyricsWindowState};
function lyricsUnlockBounds(bounds,workArea,vertical=false){let x=Math.round(bounds.x+bounds.width-(vertical?41:71)),y=Math.round(bounds.y+(vertical?35:5));if(workArea){x=Math.max(workArea.x,Math.min(workArea.x+workArea.width-32,x));y=Math.max(workArea.y,Math.min(workArea.y+workArea.height-32,y));}return {x,y,width:32,height:32};}
module.exports.lyricsUnlockBounds=lyricsUnlockBounds;
function lyricsUnlockWindowOptions(bounds){return {...bounds,minWidth:32,minHeight:32,maxWidth:32,maxHeight:32,frame:false,transparent:true,backgroundColor:'#00000000',hasShadow:false,roundedCorners:false,alwaysOnTop:true,resizable:false,movable:false,show:false,skipTaskbar:true,acceptFirstMouse:true};}
module.exports.lyricsUnlockWindowOptions=lyricsUnlockWindowOptions;
