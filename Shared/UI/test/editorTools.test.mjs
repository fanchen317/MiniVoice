import test from 'node:test';import assert from 'node:assert/strict';
import {splitLyricsDraft,joinLyricsDraft,shiftLyricsTimestamps,libraryAudit} from '../src/editorTools.js';
test('bilingual editor roundtrips unicode without duplicating translation metadata',()=>{const source=joinLyricsDraft('[00:01]原文 🎵','[00:01]译文');assert.deepEqual(splitLyricsDraft(source),{lyrics:'[00:01]原文 🎵',translation:'[00:01]译文'});assert.equal(joinLyricsDraft(source,'新译文').match(/translation:/g).length,1);assert.equal(joinLyricsDraft(source,''),'[00:01]原文 🎵');});
test('timing edit clamps negatives, carries minutes and shifts enhanced word times',()=>{assert.equal(shiftLyricsTimestamps('[ar:歌手]\n[00:59.500]<00:59.600>你好',1),'[ar:歌手]\n[01:00.500]<01:00.600>你好');assert.equal(shiftLyricsTimestamps('[00:00.250]你好',-1),'[00:00.000]你好');assert.throws(()=>shiftLyricsTimestamps('a',Infinity));});
test('audit marks only matching title, artist and duration as candidate duplicates',()=>{const songs=[{id:'1',title:'Ａ',artist:'Singer',duration:3000},{id:'2',title:'a',artist:'singer',duration:3000},{id:'3',title:'a',artist:'other',duration:3000}];assert.deepEqual(libraryAudit(songs,{milliseconds:true}).duplicates.map(x=>x.map(s=>s.id)),[['1','2']]);});

test('manual stamping preserves metadata and shifts enhanced word times with its line',async()=>{
 const {lyricTimingRows,stampLyricLine}=await import('../src/editorTools.js');
 const raw='[ar:歌手]\n\n[00:02.000]<00:02.000>你好<00:03.000>世界\n下一行';
 assert.deepEqual(lyricTimingRows(raw).map(row=>row.index),[2,3]);
 assert.equal(stampLyricLine(raw,2,12.5),'[ar:歌手]\n\n[00:12.500]<00:12.500>你好<00:13.500>世界\n下一行');
 assert.equal(stampLyricLine('第一行',0,60.125),'[01:00.125]第一行');assert.throws(()=>stampLyricLine(raw,0,0));assert.throws(()=>stampLyricLine(raw,2,NaN));
});
