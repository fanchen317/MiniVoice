// Reconcile host samples without rewinding the interpolated lyric playhead.
// Large discontinuities are seeks; ordinary polling jitter is paid back at 10% speed.
export function samplePlaybackClock(previous,time,playing,now){
 if(!previous||previous.playing!==playing||!playing)return {time,playing,sampledAt:now,source:time};
 if(previous.source===time)return previous;
 const predicted=playbackTime(previous,now),error=time-predicted;
 if(Math.abs(error)>.8)return {time,playing,sampledAt:now,source:time};
 return {time:predicted,playing,sampledAt:now,source:time,correction:error};
}
export function playbackTime(clock,now){
 const elapsed=clock.playing?Math.min(1.2,Math.max(0,(now-clock.sampledAt)/1000)):0;
 const error=clock.correction||0,correction=Math.sign(error)*Math.min(Math.abs(error),elapsed*.1);
 return clock.time+elapsed+correction;
}
