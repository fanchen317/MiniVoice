import {test} from 'node:test';
import assert from 'node:assert/strict';
import {groupName,sortCategory,normalizeOrdering,emptyListMessage} from '../src/libraryState.js';

test('classification and detail use the same trimmed unknown names',()=>{
  for(const value of ['', ' ', '\n\t']){
    assert.equal(groupName(value,true),'未知歌手');assert.equal(groupName(value,false),'未知专辑');
  }
  assert.equal(groupName(' 歌手 ',true),'歌手');
});
test('track and category preferences cannot leak unsupported fields across pages',()=>{
  assert.equal(sortCategory('artists',null),'artists');assert.equal(sortCategory('albums','专辑'),'tracks');assert.equal(sortCategory('recent',null),'tracks');
  const result=normalizeOrdering({tracks:{field:'count',ascending:false},artists:{field:'count',ascending:false},albums:{field:'album',ascending:true}});
  assert.deepEqual(result,{tracks:{field:'added',ascending:false},artists:{field:'count',ascending:false},albums:{field:'name',ascending:true}});
});
test('empty collections keep their own guidance instead of offering to import more files',()=>{
  assert.equal(emptyListMessage({destination:'recent',query:'',hasFolders:true}),'播放歌曲后，记录会保存在这里');
  assert.equal(emptyListMessage({destination:'p1',query:'',hasFolders:true}),'右键点击歌曲，选择“加入歌单”');
  assert.equal(emptyListMessage({destination:'favorites',query:'',hasFolders:false}),'暂无收藏音乐');
});
