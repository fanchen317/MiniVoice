import test from 'node:test';
import assert from 'node:assert/strict';
import {createLyricTimeline,lyricTimelineIndex} from '../src/components/lyricTimeline.js';
test('lyric lookup preserves last eligible row, duplicate timestamps, untimed lines and seek boundaries',()=>{
 const lines=[{time:null},{time:4},{time:2},{time:4},{time:-1},{time:8},{time:NaN}],timeline=createLyricTimeline(lines);
 for(const [time,index] of [[-1,-1],[0,-1],[1.999,-1],[2,2],[3,2],[4,3],[7.999,3],[8,5],[900,5],[NaN,-1]])assert.equal(lyricTimelineIndex(timeline,time),index);
 assert.equal(lyricTimelineIndex([],10),-1);
 assert.equal(lyricTimelineIndex(createLyricTimeline([{ms:500},{ms:1000}],row=>row.ms/1000),.9),0);
});
test('large lyric documents use a bounded number of timestamp reads per animation frame',()=>{
 const timeline=createLyricTimeline(Array.from({length:100000},(_,time)=>({time})));let reads=0;
 const counted=new Proxy(timeline,{get:(target,key)=>{if(/^\d+$/.test(String(key)))reads++;return target[key];}});
 assert.equal(lyricTimelineIndex(counted,52123.5),52123);assert.ok(reads<=19,`lookup read ${reads} rows`);
});
