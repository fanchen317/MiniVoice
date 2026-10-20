import {test} from 'node:test';
import assert from 'node:assert/strict';
import {filledFragments} from '../src/lyricSweep.js';
test('a wrapped word continues its sweep instead of restarting the same fraction on each line',()=>{
  assert.deepEqual(filledFragments([80,20],.5),[50,0]);
  assert.deepEqual(filledFragments([80,20],.9),[80,10]);
  assert.deepEqual(filledFragments([30,50,20],.6),[30,30,0]);
});
test('seek boundaries clamp the visible ink to the full measured word width',()=>{
  assert.deepEqual(filledFragments([80,20],-1),[0,0]);
  assert.deepEqual(filledFragments([80,20],2),[80,20]);
  assert.deepEqual(filledFragments([],1),[]);
});
