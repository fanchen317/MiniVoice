import {test} from 'node:test';
import assert from 'node:assert/strict';
import {displayLine,kineticCharacters,kineticLayout,kineticInk,paintKineticPhrase} from '../src/components/kineticModel.js';
test('shared kinetic layout preserves graphemes and fits a small mobile lyric viewport',()=>{
 const chars=kineticCharacters(displayLine({time:1,text:'你好👨‍👩‍👧‍👦，这是移动端大字歌词'.repeat(3),words:[]},8,30));
 assert(chars.some(c=>c.text==='👨‍👩‍👧‍👦'));
 for(const size of [{width:260,height:100},{width:740,height:140}]){const layout=kineticLayout(chars,size,(_,font)=>font);assert(layout.glyphs.every(p=>p.x>=0&&p.x<=size.width&&p.y>=0&&p.y<=size.height));assert.deepEqual(kineticInk(chars[0],0,0,layout.fontSize),kineticInk(chars[0],0,0,layout.fontSize));assert.equal(kineticInk(chars[0],0,30,layout.fontSize).opacity,1);}
});

test('ribbon wave stays continuous across glyph boundaries and settles after the phrase',async()=>{
 const {kineticWave}=await import('../src/components/kineticModel.js');
 const chars=Array.from('连续律动歌词', (text,i)=>({text,start:i*.3,end:(i+1)*.3}));
 for(let t=0;t<2.5;t+=.013)for(let i=0;i<chars.length;i++){
  const a=kineticWave(chars,t,i,50),b=kineticWave(chars,t+.001,i,50);
  assert.ok(Math.abs(a.y-b.y)<.2);assert.ok(Math.abs(a.scale-b.scale)<.01);
 }
 assert.equal(kineticWave(chars,4,2,50).scale,1);
 assert.ok(kineticWave(chars,.8,2,50).scale>1.08);
 assert.ok(kineticWave(chars,.8,3,50).scale>1.03);
});

test('colored ribbon is deterministic, varies across the phrase and with playback time',async()=>{
 const {kineticPalette}=await import('../src/components/kineticModel.js');
 assert.deepEqual(kineticPalette(2,8,1),kineticPalette(2,8,1));
 assert.notDeepEqual(kineticPalette(2,8,1),kineticPalette(6,8,1));
 assert.notDeepEqual(kineticPalette(2,8,1),kineticPalette(2,8,2));
});

test('singing wave keeps moving across evenly timed glyph boundaries',async()=>{
 const {kineticWave}=await import('../src/components/kineticModel.js');
 const chars=Array.from({length:8},(_,i)=>({text:'字',start:i,end:i+1}));
 const sample=t=>kineticWave(chars,t,4,50).y;
 const before=sample(2.999)-sample(2.998),after=sample(3.002)-sample(3.001);
 assert.ok(Math.abs(before)>.001,'wave must not ease to a stop at each character');
 assert.ok(Math.abs(after/before-1)<.02,'velocity stays continuous across the boundary');
});

function drawingContext(measureText){
 return new Proxy({measureText,createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}})},{get:(target,key)=>key in target?target[key]:()=>{}});
}

test('layout measures repeated graphemes once and painting reuses exact text widths',()=>{
 const chars=Array.from('字字 字字', (text,i)=>({text,start:i,end:i+1}));let measured=0;
 const layout=kineticLayout(chars,{width:740,height:140},text=>{measured++;return text===' '?6:23;});
 assert.equal(measured,2);
 assert.deepEqual(layout.textWidths,[23,23,6,23,23]);
 const ctx=drawingContext(()=>{throw new Error('playback frame must reuse layout widths');});
 for(const showSeam of [false,true])for(const time of [-1,0,.4,2.9,20])paintKineticPhrase(ctx,chars,layout,time,740,140,{showSeam});
});

test('each painting frame reads phrase timing a linear number of times',()=>{
 const count=512;let timingReads=0;
 const chars=Array.from({length:count},(_,i)=>({text:'字',get start(){timingReads++;return i*.1;},end:(i+1)*.1}));
 const layout=kineticLayout(chars,{width:740,height:420},()=>20);
 const ctx=drawingContext(()=>{throw new Error('unexpected measureText');});
 paintKineticPhrase(ctx,chars,layout,50.8,740,420,{showSeam:true});
 assert.ok(timingReads<count*8,`one frame read ${timingReads} timestamps for ${count} glyphs`);
});

test('hand-authored layouts retain their width measurement fallback',()=>{
 let measured=0;const ctx=drawingContext(()=>{measured++;return {width:24};});
 paintKineticPhrase(ctx,[{text:'字',start:0,end:1}],{fontSize:30,glyphs:[{x:50,y:50}]},.5,100,100,{showSeam:true});
 assert.equal(measured,1);
});
