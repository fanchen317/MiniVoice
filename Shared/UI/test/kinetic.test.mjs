import {test} from 'node:test';
import assert from 'node:assert/strict';
import {displayLine,kineticCharacters,kineticLayout,kineticInk} from '../src/components/kineticModel.js';
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
