import test from 'node:test';
import assert from 'node:assert/strict';
import {samplePlaybackClock,playbackTime} from '../src/components/playbackClock.js';
import {wallLyricsMetrics,regularLyricMetrics} from '../src/components/lyricPresentation.js';
import {artworkFocus} from '../src/components/artworkFocus.js';
test('ordinary late samples never rewind the lyric sweep; explicit seeks reset',()=>{
 const first=samplePlaybackClock(null,10,true,0),before=playbackTime(first,450),second=samplePlaybackClock(first,10.35,true,450);
 assert.equal(playbackTime(second,450),before);assert.ok(playbackTime(second,550)>before);
 assert.equal(playbackTime(samplePlaybackClock(second,3,true,550),550),3);
 assert.equal(playbackTime(samplePlaybackClock(second,11,false,600),2000),11);
});
test('crossing the small wall lyric threshold does not enlarge the font',()=>{
 let previous=wallLyricsMetrics(180,39).fontSize;for(let height=40;height<=90;height++){const value=wallLyricsMetrics(180,height).fontSize;assert.ok(value>=previous);assert.ok(value-previous<1);previous=value;}
 assert.equal(regularLyricMetrics(390,220,false).font,regularLyricMetrics(390,650,true).font);
});
test('artwork focal analysis is bounded, biased toward detail and safe for uniform covers',()=>{
 const data=new Uint8ClampedArray(32*32*4);for(let y=5;y<20;y++)for(let x=18;x<29;x++){const i=(y*32+x)*4;data[i]=(x+y)%2?255:0;}
 const focus=artworkFocus(data,32,32);assert.ok(focus.x>.5);assert.ok(focus.x<=.7);assert.ok(focus.y>=.3&&focus.y<=.65);
 const flat=artworkFocus(new Uint8ClampedArray(32*32*4),32,32);assert.ok(Math.abs(flat.x-.5)<.02);
});
