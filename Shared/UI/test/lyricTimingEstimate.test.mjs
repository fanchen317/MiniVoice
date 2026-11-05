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
