import {test} from 'node:test';
import assert from 'node:assert/strict';
import {displayLine,kineticCharacters,kineticLayout,kineticInk,wallLyricsMetrics} from '../src/kinetic.js';

test('presentation timings preserve real words and leave instrumental gaps unfilled',()=>{
  const real={time:1,text:'你好',words:[{text:'你好',start:1,end:1.8}]};assert.equal(displayLine(real,2,10),real);
  const generated=displayLine({time:1,text:'你好',words:[]},30,100);assert.equal(generated.words.at(-1).end,3);
  const near=displayLine({time:1,text:'你好',words:[]},2,100);assert.equal(near.words.at(-1).end,1.88);
  assert.equal(displayLine({time:null,text:'无时间',words:[]},2,10).words.length,0);
  const glyphs=kineticCharacters({words:[{text:'你👨‍👩‍👧‍👦好',start:1,end:4}]});assert.equal(glyphs.length,3);assert.deepEqual(glyphs.map(g=>g.start),[1,2,3]);assert.equal(glyphs[1].text,'👨‍👩‍👧‍👦');
});
test('long kinetic phrases fit small viewports and seeks are immediately deterministic',()=>{
  const glyphs=kineticCharacters(displayLine({time:1,text:'这是一句非常非常长的歌词'.repeat(4),words:[]},11,20));
  for(const size of [{width:180,height:80},{width:900,height:400}]){
    const layout=kineticLayout(glyphs,size,(_,font)=>font);assert.equal(layout.glyphs.length,glyphs.length);
    assert.ok(layout.glyphs.every(point=>Number.isFinite(point.x)&&Number.isFinite(point.y)&&point.x<=size.width));
    assert.ok(Math.max(...layout.glyphs.map(p=>p.y))<=size.height);
    const before=kineticInk(glyphs[0],0,0,layout.fontSize),after=kineticInk(glyphs[0],0,20,layout.fontSize);assert.equal(before.opacity,.26);assert.equal(after.opacity,1);assert.equal(after.scale,1);
    assert.deepEqual(kineticInk(glyphs[0],0,0,layout.fontSize),before);
  }
  assert.equal(wallLyricsMetrics(200,40).visibleRadius,0);assert.ok(wallLyricsMetrics(500,300).rowHeight<=100);
});
