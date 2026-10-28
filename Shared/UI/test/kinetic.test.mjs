import {test} from 'node:test';
import assert from 'node:assert/strict';
import {displayLine,kineticCharacters,kineticLayout,kineticInk} from '../src/components/kineticModel.js';
test('shared kinetic layout preserves graphemes and fits a small mobile lyric viewport',()=>{
 const chars=kineticCharacters(displayLine({time:1,text:'你好👨‍👩‍👧‍👦，这是移动端大字歌词'.repeat(3),words:[]},8,30));
 assert(chars.some(c=>c.text==='👨‍👩‍👧‍👦'));
 for(const size of [{width:260,height:100},{width:740,height:140}]){const layout=kineticLayout(chars,size,(_,font)=>font);assert(layout.glyphs.every(p=>p.x>=0&&p.x<=size.width&&p.y>=0&&p.y<=size.height));assert.deepEqual(kineticInk(chars[0],0,0,layout.fontSize),kineticInk(chars[0],0,0,layout.fontSize));assert.equal(kineticInk(chars[0],0,30,layout.fontSize).opacity,1);}
});
