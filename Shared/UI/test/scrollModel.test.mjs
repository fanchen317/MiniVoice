import {test} from 'node:test';
import assert from 'node:assert/strict';
import {scrollMetrics,dragPosition,keyboardPosition} from '../src/components/scrollModel.js';
test('scroll thumb reaches both ends regardless of content length and clamps overscroll',()=>{
 for(const content of [1001,10000,1e7]){const first=scrollMetrics(400,content,-200),last=scrollMetrics(400,content,content+20);assert.equal(first.top,0);assert.equal(last.top,last.travel);assert(last.height>=36&&last.height<=72);assert.equal(dragPosition(0,last.travel,last),last.range);assert.equal(dragPosition(last.range,-last.travel,last),0);assert.equal(dragPosition(0,1e8,last),last.range);}
});
test('short viewports and empty content never produce an overflowing thumb',()=>{
 for(const viewport of [0,20,400]){const m=scrollMetrics(viewport,0,5);assert.equal(m.overflow,false);assert(m.height<=viewport);assert.equal(dragPosition(4,100,m),0);}
});
test('keyboard scroll uses the same bounded range as dragging',()=>{const m=scrollMetrics(400,4000,0);assert.equal(keyboardPosition('End',0,m),3600);assert.equal(keyboardPosition('Home',300,m),0);assert.equal(keyboardPosition('PageDown',0,m),360);assert.equal(keyboardPosition('ArrowUp',0,m),0);assert.equal(keyboardPosition('Escape',0,m),null);});
