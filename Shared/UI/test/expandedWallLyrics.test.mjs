import test from 'node:test';
import assert from 'node:assert/strict';
import {expandedWallLyricsMetrics,wallLyricsMetrics} from '../src/components/lyricPresentation.js';
test('expanded wall limits surrounding passages independently of poster zoom',()=>{
 for(const width of [320,430,800])for(const height of [140,400,900]){
  const expanded=expandedWallLyricsMetrics(width,height);
  assert.ok(expanded.visibleRadius<=2);
  assert.ok(expanded.fontSize>=26&&expanded.fontSize<=42);
  assert.ok(expanded.gap>=expanded.fontSize*.7);
 }
 assert.equal(expandedWallLyricsMetrics(430,140).visibleRadius,1);
 assert.ok(wallLyricsMetrics(430,900).visibleRadius>expandedWallLyricsMetrics(430,900).visibleRadius);
});
