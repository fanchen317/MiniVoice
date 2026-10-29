import {test} from 'node:test';
import assert from 'node:assert/strict';
import {catalogFor,wallCells} from '../src/catalog.js';
const songs=[{id:'9223372036854775806',title:'晴天',artist:'周杰伦',album:'叶惠美',duration:240000},{id:'2',title:'江南',artist:'林俊杰',album:'第二天堂',duration:200000},{id:'3',title:'七里香',artist:'周杰伦',album:'七里香',duration:270000}];
const snapshot={songs,favorites:[songs[0].id],recent:['3',songs[0].id],playlists:[{id:'p',name:'歌单',ids:['2']}]};
test('same catalog rules for favorites, recents, playlists and artist drill-in',()=>{assert.deepEqual(catalogFor(snapshot,'收藏').items.map(x=>x.id),[songs[0].id]);assert.deepEqual(catalogFor(snapshot,'最近播放').items.map(x=>x.id),['3',songs[0].id]);assert.deepEqual(catalogFor(snapshot,'歌单:p').items.map(x=>x.id),['2']);const artists=catalogFor(snapshot,'歌手');assert.equal(artists.grouped,true);assert.equal(artists.items.find(x=>x.id==='周杰伦').count,2);assert.equal(catalogFor(snapshot,'歌手','周杰伦').items.length,2);});
test('stable nonmutating sorting and normalized search retain long IDs',()=>{assert.equal(catalogFor(snapshot,'音乐库','','', 'duration',true).items[0].id,'3');assert.equal(catalogFor(snapshot,'音乐库','','林俊杰').items[0].id,'2');assert.equal(snapshot.songs[0].id,'9223372036854775806');});
test('cover wall renders bounded visible tiles at negative cameras and zoom levels',()=>{for(const scale of [.6,1,1.6]){const cells=wallCells({x:-12008,y:9831,scale},412,840,songs.length);assert(cells.length>0&&cells.length<=120);assert(cells.every(cell=>cell.index>=0&&cell.index<songs.length));assert.equal(new Set(cells.map(x=>x.key)).size,cells.length);}assert.deepEqual(wallCells({x:0,y:0,scale:1},400,800,0),[]);});
test('large recent lists index song IDs once rather than rescanning the library per entry',()=>{
 let reads=0;const tracks=Array.from({length:5000},(_,index)=>({get id(){reads++;return String(900000+index);},title:`Song ${index}`,artist:'Artist',album:'Album'}));const recent=Array.from({length:5000},(_,index)=>String(904999-index));
 const result=catalogFor({songs:tracks,recent},'最近播放');assert.equal(result.items.length,5000);assert.equal(result.items[0].title,'Song 4999');assert.equal(result.items.at(-1).title,'Song 0');assert(reads<=10000,'Recent lookup regressed to repeated full-library scans');
});
