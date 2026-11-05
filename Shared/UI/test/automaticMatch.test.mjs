import test from 'node:test';
import assert from 'node:assert/strict';
import match from '../../DesktopServices/automatic-match.cjs';
const song={title:'Song',artist:'Artist',album:'Album',duration:200};
test('automatic lyrics prioritize real word timing only after identity checks',()=>{
 const line={...song,lyrics:'[00:01.00]hello'};
 const word={...song,lyrics:'[00:01.00]<00:01.00>hello<00:02.00>world'};
 assert.equal(match.chooseLyrics(song,[line,{...word,title:'Song live'},word]).timingKind,'word');
 assert.equal(match.chooseLyrics(song,[{...word,artist:'Other'},{...word,duration:300}]),null);
});
test('automatic artwork rejects unknown albums and other releases',()=>{
 assert.equal(match.chooseArtwork({...song,album:''},[{...song,album:''}]),null);
 assert.equal(match.chooseArtwork(song,[{...song,album:'Another'}]),null);
 assert.equal(match.chooseArtwork(song,[{...song,width:300,height:300},{...song,width:1200,height:1200}]).width,1200);
});
