import test from 'node:test';
import assert from 'node:assert/strict';
import {paintKineticPhrase} from '../src/components/kineticModel.js';
test('light traces share glyph transforms and are absent before highlight',()=>{
 const draw=(time,showSeam)=>{const calls=[];const ctx=new Proxy({measureText:()=>({width:24}),createLinearGradient:()=>({addColorStop(){}})},{get:(target,key)=>key in target?target[key]:(...args)=>calls.push([key,...args])});
 paintKineticPhrase(ctx,[{text:'字',start:1,end:2}],{fontSize:30,glyphs:[{x:50,y:50}]},time,200,120,{showSeam});return calls;};
 assert.equal(draw(0,true).filter(c=>c[0]==='fillRect').length,0);
 assert.equal(draw(1.5,false).filter(c=>c[0]==='fillRect').length,0);
 const calls=draw(1.5,true),at=calls.findIndex(c=>c[0]==='fillRect');assert.ok(at>0);
 assert.equal(calls[at-1][0],'fillText');assert.equal(calls[at+1][0],'restore');
});
