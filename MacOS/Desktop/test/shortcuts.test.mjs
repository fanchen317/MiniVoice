import {test} from 'node:test';
import assert from 'node:assert/strict';
import {playbackAction} from '../src/shortcuts.js';
test('native shortcut defaults and modifier matching agree with original controls',()=>{
  assert.deepEqual(playbackAction({code:'Space'}),{action:'toggle'});
  assert.deepEqual(playbackAction({code:'ArrowLeft',metaKey:true}),{action:'skip',payload:{delta:-1}});
  assert.equal(playbackAction({code:'ArrowLeft',altKey:true}),null);
  assert.equal(playbackAction({code:'Space',metaKey:true}),null);
  assert.equal(playbackAction({code:'Space',repeat:true}),null);
  assert.equal(playbackAction({code:'Space',isComposing:true}),null);
});
test('settings recorder custom keys replace the old bindings',()=>{
  const custom=[{action:'togglePlayback',keyCode:35,modifiers:(1<<20)|(1<<17)}];
  assert.equal(playbackAction({code:'Space'},custom),null);
  assert.deepEqual(playbackAction({code:'KeyP',metaKey:true,shiftKey:true},custom),{action:'toggle'});
  assert.equal(playbackAction({code:'KeyP',metaKey:true},custom),null);
});
