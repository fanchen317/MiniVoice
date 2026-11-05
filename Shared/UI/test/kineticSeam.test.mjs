import test from 'node:test';
import assert from 'node:assert/strict';
import {paintKineticPhrase,kineticRasterScale} from '../src/components/kineticModel.js';
test('reference reflection is opt-in and fades after the singing wave',()=>{
 const draw=(time,showSeam)=>{
 const calls=[];const ctx=new Proxy({measureText:()=>({width:24}),createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}})},{get:(target,key)=>key in target?target[key]:(...args)=>calls.push([key,...args])});
 paintKineticPhrase(ctx,[{text:'字',start:1,end:2}],{fontSize:30,glyphs:[{x:50,y:50}]},time,200,120,{showSeam});
 return calls;};
 const calls=draw(1.5,true);
 assert.equal(calls.filter(c=>c[0]==='fillRect').length,2);
 assert.equal(draw(1.5,false).filter(c=>c[0]==='fillRect').length,0);
 assert.equal(draw(4,true).filter(c=>c[0]==='fillRect').length,0);
 assert.equal(calls.filter(c=>c[0]==='fillText').length,2);
 assert.equal(calls.filter(c=>c[0]==='strokeText').length,0);
 assert.equal(draw(1.5,false).filter(c=>c[0]==='strokeText').length,0);

});

test('high density non-iOS lyrics retain native pixel resolution',()=>{
 assert.equal(kineticRasterScale(3,true),3);
 assert.equal(kineticRasterScale(3,false),2);
 assert.equal(kineticRasterScale(NaN,true),1);
});

test('reference phrase fits phone width before wrapping',async()=>{
 const {kineticLayout}=await import('../src/components/kineticModel.js');
 const chars=[...'最后也 不是故作冷漠'].map(text=>({text}));
 const layout=kineticLayout(chars,{width:390,height:200},(text,font)=>text===' '?font*.3:font,{reference:true});
 assert.equal(new Set(layout.glyphs.map(point=>point.y)).size,1);
 assert.ok(layout.fontSize>=24);
 assert.ok(layout.glyphs.every(point=>point.x>0&&point.x<390));
});
