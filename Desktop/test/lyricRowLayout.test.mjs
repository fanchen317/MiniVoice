import {test} from 'node:test';
import assert from 'node:assert/strict';
import {lyricRowOffsets} from '../src/lyricRowLayout.js';
test('wrapped sentences keep their full height without overlapping neighbors',()=>{
 const heights=[40,96,144,48,80],offsets=lyricRowOffsets(heights,2);
 assert.equal(offsets[2]+heights[2]/2,0);
 for(let i=1;i<heights.length;i++)assert.equal(offsets[i]-(offsets[i-1]+heights[i-1]),4);
});
test('single sentence remains centered after resizing',()=>{
 assert.deepEqual(lyricRowOffsets([44],0),[-22]);
 assert.deepEqual(lyricRowOffsets([132],0),[-66]);
 assert.deepEqual(lyricRowOffsets([],0),[]);
});
