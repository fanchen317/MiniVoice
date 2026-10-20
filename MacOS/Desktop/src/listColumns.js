// MusicListColumns: retain the native anchors instead of browser flex redistribution.
export function listColumns(panelWidth,multiple=false){
  const progress=(a,b)=>{const p=Math.max(0,Math.min(1,(panelWidth-a)/(b-a)));return p*p*(3-2*p);};
  const compact=panelWidth<480,album=panelWidth>=660,duration=panelWidth>=740,edit=progress(740,820),width=Math.max(0,panelWidth-54),selection=multiple?30:0;
  const favorite={x:width-28-38*edit,y:8,width:28,height:28},artwork={x:selection,y:0,width:44,height:44},start=artwork.x+52,end=favorite.x-8-58*Number(duration),full=Math.max(0,end-start),budget=Math.max(0,full-8*Number(!compact)-8*Number(album)),albumWidth=budget*.27*Number(album),artistWidth=budget*(.4-.1*Number(album))*Number(!compact),titleWidth=Math.max(0,budget-artistWidth-albumWidth);
  const title={x:start,y:compact?3:12,width:titleWidth,height:20},artist=compact?{x:start,y:25,width:full,height:16}:{x:title.x+title.width+8,y:12,width:artistWidth,height:20};
  return {compact,album,duration,edit:panelWidth>=820,selection:{x:0,y:11,width:22,height:22},artwork,title,artist,albumRect:{x:artist.x+artist.width+8*Number(album),y:12,width:albumWidth,height:20},durationRect:{x:favorite.x-58,y:12,width:40,height:20},favorite};
}
export function listColumnStyles(columns){
  const style={};
  for(const [name,rect] of Object.entries(columns))if(rect&&typeof rect==='object')for(const [axis,value] of Object.entries(rect))style[`--cell-${name}-${axis}`]=`${value}px`;
  return style;
}
