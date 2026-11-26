import test from 'node:test';
import assert from 'node:assert/strict';
import {estimateLyricTiming as estimate} from '../src/components/lyricTimingEstimate.js';
import {displayLine} from '../src/components/lyricPresentation.js';
test('preserves text and produces finite monotonic bounded timing',()=>{
 for(const text of ['你好，世界！','Hello beautiful world','👨‍👩‍👧‍👦 爱你','……','a','爱'.repeat(1000)])for(const span of [.01,2,40]){
 const words=estimate(text,3,3+span);assert.equal(words.map(w=>w.text).join(''),text);
 let previous=3;for(const w of words){assert.ok(Number.isFinite(w.end));assert.ok(w.start>=previous-1e-9);assert.ok(w.end>=w.start);assert.ok(w.end<=3+span);previous=w.end;}
 }
});
test('punctuation reserves a pause and final syllable receives sustain',()=>{
 const w=estimate('你好，世界',0,5);assert.ok(w[3].start>w[1].end);assert.ok(w[4].end-w[4].start>w[0].end-w[0].start);
 assert.ok(estimate('你好',0,40).at(-1).end<3);
});
test('authentic timestamps stay untouched; output is deterministic',()=>{
 const line={time:0,text:'你好',words:[{text:'你好',start:0,end:2}]};assert.equal(displayLine(line,3,5),line);
 assert.deepEqual(estimate('Hello，你好',0,4),estimate('Hello，你好',0,4));
});
test('line-end breath adapts to duration and sentence-ending punctuation',()=>{
 const end=(text,span)=>estimate(text,0,span).at(-1).end;
 assert.ok(Math.abs(3-end('一起走过这里',3)-.36)<1e-9);
 assert.ok(Math.abs(3-end('一起走过这里。 ” ',3)-.44)<1e-9);
 assert.ok(Math.abs(.1-end('好',.1)-.018)<1e-9);
 assert.ok(8-end('再见',8)>6); // Existing long-gap vocal cap remains in force.
 assert.deepEqual(estimate('再见',1,1),[]);
});
test('last line uses track duration or its explicit end while real words stay intact',()=>{
 const last=displayLine({time:7,text:'一起走过这里'},undefined,10);
 assert.ok(Math.abs(last.words.at(-1).end-10)<1e-9);
 const bounded=displayLine({time:7,end:9,text:'一起走过这里'},undefined,10);
 assert.ok(Math.abs(bounded.words.at(-1).end-9)<1e-9);
 const existingGap=displayLine({time:7,end:9,text:'一起走过这里'},10,12);
 assert.ok(Math.abs(existingGap.words.at(-1).end-9)<1e-9);
 const smallGap=displayLine({time:7,end:9.9,text:'一起走过这里'},10,12);
 assert.ok(Math.abs(smallGap.words.at(-1).end-9.64)<1e-9);
 const unknownDuration=displayLine({time:0,text:'一起走过这里'},3,0);
 assert.ok(Math.abs(unknownDuration.words.at(-1).end-2.64)<1e-9);
 const authentic={time:7,text:'一起走过这里',words:[{text:'一起',start:7,end:9.9}]};
 assert.equal(displayLine(authentic,10,10),authentic);
});
test('apostrophes inside English contractions do not create an extra syllable',()=>{
 const contracted=estimate("don't stop",0,8),plain=estimate('dont stop',0,8);
 const firstEnd=words=>words.find(w=>w.text==='t').end;
 assert.ok(Math.abs(firstEnd(contracted)-firstEnd(plain))<1e-9);
 assert.equal(contracted.map(w=>w.text).join(''),"don't stop");
});
test('Japanese small kana share their preceding syllable while small tsu retains a beat',()=>{
 const combined=estimate('きゃく',0,5),separate=estimate('きかく',0,5),sokuon=estimate('きっく',0,5);
 const duration=w=>w.end-w.start;
 assert.ok(duration(combined[1])<duration(combined[0])*.5);
 assert.ok(duration(sokuon[1])>duration(combined[1])*2);
 assert.ok(combined.at(-1).end<separate.at(-1).end);
});
