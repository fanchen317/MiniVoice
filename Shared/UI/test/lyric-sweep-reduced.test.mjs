import {test} from 'node:test';
import assert from 'node:assert/strict';
import {paintLyricSweep,lyricSweepDelay} from '../src/components/lyricSweep.js';

test('reduced motion follows individual word starts and rewinds on a seek',()=>{
 const beforeDocument=globalThis.document,beforeStyle=globalThis.getComputedStyle;
 const words=[{textContent:'你',dataset:{wordStart:'1',wordEnd:'2'},left:0},{textContent:'好',dataset:{wordStart:'2',wordEnd:'3'},left:10}];
 const surface={offsetWidth:20,offsetHeight:20,clientWidth:20,clientHeight:20,style:{},classList:{add(){},remove(){}},querySelectorAll:()=>words,getBoundingClientRect:()=>({left:0,top:0,width:20,height:20})};
 globalThis.document={createRange(){let word;return {selectNodeContents(value){word=value;},getClientRects(){return [{left:word.left,top:0,width:10,height:16}];}};}};
 globalThis.getComputedStyle=()=>({fontSize:'16px'});
 try{
  assert.equal(paintLyricSweep(surface,.5,{reduced:true}),.5);assert.equal(surface.style.backgroundSize,'0px 20px,0px 20px,100% 100%');
  assert.equal(paintLyricSweep(surface,1,{reduced:true}),1);assert.equal(surface.style.backgroundSize,'10px 20px,0px 20px,100% 100%');
  paintLyricSweep(surface,2.5,{reduced:true});assert.equal(surface.style.backgroundSize,'10px 20px,10px 20px,100% 100%');
  paintLyricSweep(surface,1.5,{reduced:true});assert.equal(surface.style.backgroundSize,'10px 20px,0px 20px,100% 100%');
  paintLyricSweep(surface,1.5);assert.equal(surface.style.backgroundSize,'5px 20px,0px 20px,100% 100%');
 }finally{globalThis.document=beforeDocument;globalThis.getComputedStyle=beforeStyle;}
});
test('reduced motion schedules the next boundary with bounded clock rechecks',()=>{
 assert.equal(lyricSweepDelay(.05),50);assert.equal(lyricSweepDelay(.001),16);assert.equal(lyricSweepDelay(10),250);assert.equal(lyricSweepDelay(undefined),250);
});
