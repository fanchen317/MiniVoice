const {test}=require('node:test'),assert=require('node:assert/strict'),{searchLyrics}=require('../../Shared/DesktopServices/online-lyrics.cjs');
test('shared search survives failed providers, normalizes results and retains native candidates',async()=>{const rows=await searchLyrics({title:'歌曲',artist:'歌手',duration:100},{fetch:async url=>{if(String(url).includes('lrclib.net'))return new Response(JSON.stringify([{trackName:'歌曲',artistName:'歌手',duration:100,syncedLyrics:'[00:01]原文'}]));throw Error('offline');},additional:[async()=>[{id:'native',source:'Native',title:'其他',artist:'歌手',lyrics:'文字',simplifiedLyrics:'文字'}]]});assert.equal(rows.length,2);assert.equal(rows[0].source,'LRCLIB');assert.equal(rows[1].id,'native');});
test('all provider failures are distinct from empty results',async()=>{await assert.rejects(searchLyrics({title:'歌曲',artist:'歌手'},{fetch:async()=>{throw Error('offline');}}),/均请求失败/);const rows=await searchLyrics({title:'歌曲'},{fetch:async()=>new Response('[]')});assert.deepEqual(rows,[]);});
test('search favours matching word timing and rejects live or long-duration mismatches in ranking',async()=>{
 const rows=await searchLyrics({title:'歌手 - 歌曲',artist:'歌手',duration:200},{fetch:async()=>new Response('[]'),additional:[async()=>[
  {id:'plain',title:'歌曲',artist:'歌手',duration:200,lyrics:'纯文本'},
  {id:'live',title:'歌曲 (Live)',artist:'歌手',duration:200,lyrics:'[00:01]<00:01>字'},
  {id:'long',title:'歌曲',artist:'歌手',duration:350,lyrics:'[00:01]<00:01>字'},
  {id:'word',title:'歌曲',artist:'歌手',duration:201,lyrics:'[00:01]<00:01>字'},
 ]]});
 assert.equal(rows[0].id,'word');assert.ok(rows.findIndex(row=>row.id==='live')>0);assert.equal(rows.some(row=>row.id==='long'),false,'deduplication retains the duration-matched result');
});
test('unknown artist is not sent to lyric providers',async()=>{
 const urls=[];await searchLyrics({title:'歌曲',artist:'未知歌手'},{fetch:async url=>{urls.push(String(url));return new Response('[]');}});
 assert.ok(urls.every(url=>!decodeURIComponent(url).includes('未知歌手')));assert.equal(urls.length,2);
});
