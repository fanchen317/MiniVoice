export function displayLine(line,nextStart,duration){
  if(line.words?.length||!Number.isFinite(line.time)||line.time<0||!line.text?.trim())return line;
  const characters=typeof Intl.Segmenter==='function'?[...new Intl.Segmenter('zh',{granularity:'grapheme'}).segment(line.text)].map(part=>part.segment):Array.from(line.text),start=line.time;
  const bounds=[line.end,nextStart,duration].filter(value=>Number.isFinite(value)&&value>start),nearest=bounds.length?Math.min(...bounds):null;
  let end=nearest!==null&&nearest-start<=12?nearest:start+Math.min(10,Math.max(2,characters.length*.28));
  if(Number.isFinite(nextStart)&&nextStart>start)end=Math.min(end,nextStart-Math.min(.3,(nextStart-start)*.12));
  const step=(end-start)/characters.length;
  return {...line,words:characters.map((text,index)=>({text,start:start+index*step,end:start+(index+1)*step}))};
}
export function wallLyricsMetrics(width,height){
  const singleLine=height<60,fontSize=Math.min(58,Math.max(12,Math.min(width*.062,height/(singleLine?2.8:11))));
  const rowHeight=singleLine?height:Math.min(height/3,fontSize*2.15+8);
  return {singleLine,fontSize,rowHeight,visibleRadius:singleLine?0:Math.max(4,Math.ceil(height/Math.max(1,rowHeight)))};
}

export function normalizeLyrics(lines){return lines.map(line=>({...line,time:Number.isFinite(line.ms)?line.ms/1000:line.time,words:(line.words||[]).map(word=>Number.isFinite(word.ms)?{text:word.text,start:word.ms/1000,end:word.endMs>word.ms?word.endMs/1000:undefined}:word)}));}
export function lyricRowOffsets(heights,active,gap=4){const centers=[];let edge=0;for(const height of heights){centers.push(edge+height/2);edge+=height+gap;}const origin=centers[active]??0;return centers.map((center,index)=>center-origin-heights[index]/2);}
export function regularLyricMetrics(width,height,expanded=false,bilingual=false){const base=Math.min(expanded?72:92,Math.max(28,(height-36)/(expanded?6:5))),row=bilingual?Math.max(62,base*1.45):base,font=expanded?Math.min(38,Math.max(22,width*.058)):Math.min(34,Math.max(19,base*.56));return {row,font};}
