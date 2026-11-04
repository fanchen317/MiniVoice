import test from 'node:test';
import assert from 'node:assert/strict';
import {samplePlaybackClock,playbackTime} from '../src/components/playbackClock.js';
import {wallLyricsMetrics,regularLyricMetrics} from '../src/components/lyricPresentation.js';
import {artworkFocus,applyArtworkFocus} from '../src/components/artworkFocus.js';
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

test('viewport-aware crop preserves off-center detail without moving preview/detail anchors',()=>{
 const pixels=new Uint8ClampedArray(32*32*4);for(let y=4;y<25;y++)for(let x=3;x<12;x++){const i=(y*32+x)*4;pixels[i]=pixels[i+1]=pixels[i+2]=(x+y)%2?255:0;}
 const portrait=artworkFocus(pixels,32,32,{imageAspect:1.8,viewportAspect:.55});assert.ok(portrait.x<.4,'Narrow crop cuts the left subject');
 const above=new Uint8ClampedArray(32*32*4);for(let y=3;y<11;y++)for(let x=8;x<25;x++){const i=(y*32+x)*4;above[i]=above[i+1]=above[i+2]=(x+y)%2?255:0;}
 const landscape=artworkFocus(above,32,32,{imageAspect:.7,viewportAspect:1.8});assert.ok(landscape.y<.4,'Wide crop cuts the upper subject');
 assert.deepEqual(artworkFocus(above,32,32,{imageAspect:.7,viewportAspect:1.8}),landscape);
});

test('preview and detail share one analysis and stable anchor across quality routes',()=>{
 const previous=globalThis.document;let samples=0;const pixels=new Uint8ClampedArray(32*32*4);for(let y=3;y<20;y++)for(let x=4;x<12;x++){const i=(y*32+x)*4;pixels[i]=(x+y)%2?255:0;}
 globalThis.document={createElement:()=>({getContext:()=>({drawImage:()=>samples++,getImageData:()=>({data:pixels})})})};
 try{const image=src=>({src,naturalWidth:320,naturalHeight:320,style:{},dataset:{}}),preview=image('minivoice-art://cover/stable-test?v=1'),detail=image('minivoice-art://detail/stable-test?v=1&source=original-v1');const first=applyArtworkFocus(preview,{viewportAspect:.6}),second=applyArtworkFocus(detail,{viewportAspect:.6});assert.deepEqual(second,first);assert.equal(samples,1);assert.equal(preview.style.objectPosition,detail.style.objectPosition);}finally{globalThis.document=previous;}
});

test('face-aware crop keeps padded hair and face in both feasible viewport orientations',async()=>{
 const {subjectCrop}=await import('../src/components/artworkFocus.js');
 const region={x:.58,y:.27,width:.18,height:.2,face:1};
 for(const aspect of [.55,1.8]){const p=subjectCrop([region],1,aspect),cw=Math.min(1,aspect),ch=Math.min(1,1/aspect),left=p.x*(1-cw),top=p.y*(1-ch);assert.ok(left<=region.x-region.width*.18+1e-6);assert.ok(top<=region.y-region.height*.65+1e-6);assert.ok(left+cw>=region.x+region.width*1.18-1e-6);assert.ok(top+ch>=region.y+region.height*1.2-1e-6);}
});
