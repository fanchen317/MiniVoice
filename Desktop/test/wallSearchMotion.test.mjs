import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createWallSearchMotion} from '../src/wallSearchMotion.js';
function fixture(reduced=false){
  let now=0,id=0;const timers=new Map(),phases=[];
  const motion=createWallSearchMotion(phase=>phases.push(phase),{
    reduced:()=>reduced,schedule:(fn,delay)=>{timers.set(++id,{fn,at:now+delay});return id;},cancel:key=>timers.delete(key),
  });
  function advance(ms){const target=now+ms;for(;;){const next=[...timers].sort((a,b)=>a[1].at-b[1].at)[0];if(!next||next[1].at>target)break;now=next[1].at;timers.delete(next[0]);next[1].fn();}now=target;}
  return {motion,phases,advance};
}
test('search grows before expansion, collapses before shrinking',()=>{
  const {motion,phases,advance}=fixture();motion.open();assert.deepEqual(phases,['growing']);
  advance(239);assert.equal(phases.at(-1),'growing');advance(1);assert.equal(phases.at(-1),'expanded');
  motion.close();advance(359);assert.equal(phases.at(-1),'collapsing');
  advance(1);assert.equal(phases.at(-1),'shrinking');advance(320);assert.equal(phases.at(-1),'closed');
});
test('re-entering and early exit cancel stale search phases',()=>{
  const {motion,phases,advance}=fixture();motion.open();advance(80);motion.close();advance(500);
  assert.ok(!phases.includes('expanded'));
  motion.open();advance(240);motion.close();advance(100);motion.open();advance(1000);
  assert.equal(phases.at(-1),'expanded');
  motion.dispose();
});
test('reduced motion and hidden reset finish immediately',()=>{
  const {motion,phases,advance}=fixture(true);motion.open();assert.equal(phases.at(-1),'expanded');
  motion.close();assert.equal(phases.at(-1),'closed');
  const active=fixture();active.motion.open();active.motion.reset();active.advance(1000);assert.deepEqual(active.phases,['growing','closed']);
});
