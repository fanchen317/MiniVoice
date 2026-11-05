import {estimateLyricTiming} from './lyricTimingEstimate.js';
export function displayLine(line,nextStart,duration){
  if(line.words?.length||!Number.isFinite(line.time)||line.time<0||!line.text?.trim())return line;
  const start=line.time;
  const bounds=[line.end,nextStart,duration].filter(value=>Number.isFinite(value)&&value>start);
  const limit=bounds.length?Math.min(...bounds):start+10;
  return {...line,timingSource:'estimated',words:estimateLyricTiming(line.text,start,limit)};
}
export function wallLyricsMetrics(width,height){
  const singleLine=height<20,fontSize=Math.min(34,Math.max(10,width*.058));
  const rowHeight=fontSize*2.25;
  return {singleLine,fontSize,rowHeight,visibleRadius:singleLine?0:Math.max(4,Math.ceil(height/Math.max(1,rowHeight)))};
}

export function normalizeLyrics(lines){return lines.map(line=>({...line,time:Number.isFinite(line.ms)?line.ms/1000:line.time,words:(line.words||[]).map(word=>Number.isFinite(word.ms)?{text:word.text,start:word.ms/1000,end:word.endMs>word.ms?word.endMs/1000:undefined}:word)}));}
export function lyricRowOffsets(heights,active,gap=4){const centers=[];let edge=0;for(const height of heights){centers.push(edge+height/2);edge+=height+gap;}const origin=centers[active]??0;return centers.map((center,index)=>center-origin-heights[index]/2);}
export function regularLyricMetrics(width,height,expanded=false,bilingual=false){const font=Math.min(34,Math.max(19,width*.058)),base=font*1.8,row=bilingual?Math.max(62,base*1.45):base;return {row,font};}

// Expanded mobile wall is a reading surface, independent of zoomed posters.
export function expandedWallLyricsMetrics(width,height){
 const fontSize=Math.min(42,Math.max(26,width*.078));
 return {singleLine:false,fontSize,rowHeight:fontSize*2.8,visibleRadius:height<180?1:2,gap:fontSize*.72};
}
