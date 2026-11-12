import {test} from 'node:test';
import assert from 'node:assert/strict';
import {wallOriginalArtwork,wallImageCoordinateSpace,loadWallWallpaper} from '../src/wallArtworkSource.js';
import {artwork} from '../src/artworkUrl.js';

test('wall treats only the strict analysis route as original coordinates',()=>{
 const track={artworkKey:'a'.repeat(64),artworkRevision:4},detail=artwork(track,true),strict=wallOriginalArtwork(track,detail),preview=artwork(track,false);
 assert.equal(new URL(strict).searchParams.get('analysis'),'1');
 assert.equal(wallImageCoordinateSpace(strict),'original');
 assert.equal(wallImageCoordinateSpace(detail),'preview');
 assert.equal(wallImageCoordinateSpace(preview),'preview');
 assert.equal(wallImageCoordinateSpace('data:image/png;base64,AA=='),'preview');
});

test('wallpaper prefers the verified original and falls back to a decoded preview',async()=>{
 const seen=[],makeImage=()=>({naturalWidth:640,naturalHeight:480,set src(value){this._src=value;seen.push(value);},get src(){return this._src;},async decode(){if(this._src==='strict-unavailable')throw Error('missing');}});
 const original=await loadWallWallpaper('strict','preview',makeImage);assert.equal(original.src,'strict');assert.deepEqual(seen,['strict']);
 seen.length=0;const fallback=await loadWallWallpaper('strict-unavailable','preview',makeImage);assert.equal(fallback.src,'preview');assert.deepEqual(seen,['strict-unavailable','preview']);
 seen.length=0;assert.equal(await loadWallWallpaper('strict-unavailable','',makeImage),null);assert.equal(await loadWallWallpaper('','',makeImage),null);
});
