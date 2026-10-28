import test from 'node:test';
import assert from 'node:assert/strict';
import {prepareFragments,fragmentKeyframes} from '../src/fragmentMotion.js';
test('composited fragments cover the viewport and retain the original curled endpoints',()=>{
 for(const [width,height] of [[390,844],[844,390]]){
  const plan=prepareFragments(width,height,{x:40,y:80});
  assert.ok(plan.length<=224);
  assert.ok(Math.abs(plan.reduce((n,c)=>n+c.width*c.height,0)-width*height)<.01);
  for(const cell of plan){const frames=fragmentKeyframes(cell);assert.equal(frames[0].opacity,1);assert.match(frames[0].transform,/translate\(0px,0px\) rotate\(0deg\) scale\(1\)/);assert.equal(frames.at(-1).opacity,0);assert.ok(cell.delay+480<=680);for(const frame of frames){assert.deepEqual(Object.keys(frame),['offset','opacity','transform']);assert.ok(!frame.transform.includes('NaN'));}}
 }
});
test('mobile fragment budget keeps full coverage with at most 24 surfaces',()=>{
 for(const [width,height] of [[390,844],[844,390],[1200,800]]){
  const plan=prepareFragments(width,height,{x:40,y:80},{maxCells:24});
  assert(plan.length>0&&plan.length<=24);
  assert(Math.abs(plan.reduce((sum,c)=>sum+c.width*c.height,0)-width*height)<.01);
 }
});
