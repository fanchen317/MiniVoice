import {test} from 'node:test';
import assert from 'node:assert/strict';
import {listColumns} from '../src/listColumns.js';
test('metadata columns reserve their own anchors and never overlap favorite controls',()=>{
  for(const multiple of [false,true])for(let width=280;width<=1600;width++){
    const c=listColumns(width,multiple);assert.ok(c.artwork.x+c.artwork.width+8<=c.title.x);
    assert.ok(c.title.width>=0);assert.ok(c.title.x+c.title.width<=c.favorite.x-8);
    if(!c.compact)assert.ok(c.title.x+c.title.width+8<=c.artist.x);
    if(c.album)assert.ok(c.artist.x+c.artist.width+8<=c.albumRect.x);
    if(c.duration)assert.ok(c.albumRect.x+c.albumRect.width<=c.durationRect.x&&c.durationRect.x+40<c.favorite.x);
    assert.equal(c.compact,width<480);assert.equal(c.album,width>=660);assert.equal(c.duration,width>=740);assert.equal(c.edit,width>=820);
  }
});
