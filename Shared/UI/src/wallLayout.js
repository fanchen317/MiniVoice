export const clampZoom=value=>Math.max(.6,Math.min(1.2,Number.isFinite(value)?value:1));
export function mobileWallViewport(width,height,insets={}){
 const safe={top:insets.top||0,bottom:insets.bottom||0,left:insets.left||0,right:insets.right||0};
 const w=Math.max(1,width-safe.left-safe.right),h=Math.max(1,height-safe.top-safe.bottom),landscape=width>height;
 const dockWidth=Math.min(440,landscape?Math.min(height-28,w*.48):w-28);
 // Landscape reserves the left dock and the right toolbar column. Centre in
 // that free region, using the same safe-area and dock geometry as the skin.
 const left=landscape?safe.left+16+dockWidth+16:safe.left;
 const right=landscape?width-safe.right-14-56-16:width-safe.right;
 const available=Math.max(120,right-left);
 const top=safe.top+(landscape?12:80),bottom=height-safe.bottom-(landscape?12:114);
 const side=Math.max(120,Math.min(520,available-12,bottom-top-12));
 return {width,height,safe,landscape,dockWidth,side,x:(left+right)/2,y:(top+bottom)/2};
}
export function wallCardMetrics(width,height,expanded=false,compact=false){
 const padding=expanded?22:Math.max(10,Math.min(18,width*.045)),header=compact?50:82,footer=compact?44:84;
 const lyricHeight=Math.max(0,height-padding*2-header-footer-12),font=expanded?Math.min(26,Math.max(18,width*.045)):compact?12:Math.max(13,Math.min(19,width*.05));
 const count=lyricHeight>=font*6.25+20?5:3;
 return {padding,header,footer,lyricHeight,font,count,compact};
}
export function lyricWindow(lines,index,count=5){
 if(!lines.length)return {first:0,active:-1,lines:[]};index=Math.max(0,Math.min(lines.length-1,index));const first=Math.max(0,Math.min(index-Math.floor(count/2),lines.length-count));return {first,active:index,lines:lines.slice(first,first+count)};
}
export function mixRect(a,b,t){return {x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t,width:a.width+(b.width-a.width)*t,height:a.height+(b.height-a.height)*t};}
