// Build once per lyric document; frame callbacks must not scan the whole song.
// Prefix ownership preserves the existing last-eligible-row rule even for
// duplicate or out-of-order source timestamps.
export function createLyricTimeline(lines,timeOf=line=>line.time){
 const timed=lines.flatMap((line,index)=>{const time=timeOf(line);return Number.isFinite(time)&&time>=0?[{time,index}]:[];}).sort((a,b)=>a.time-b.time||a.index-b.index);
 let owner=-1;return timed.map(row=>({time:row.time,index:owner=Math.max(owner,row.index)}));
}
export function lyricTimelineIndex(timeline,time){
 if(!Number.isFinite(time))return -1;
 let low=0,high=timeline.length;
 while(low<high){const middle=(low+high)>>>1;if(timeline[middle].time<=time)low=middle+1;else high=middle;}
 return low?timeline[low-1].index:-1;
}
