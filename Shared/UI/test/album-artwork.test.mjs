import {test} from 'node:test';
import assert from 'node:assert/strict';
import {albumArtworkTracks} from '../src/albumArtwork.js';
test('album picker matches saved album across artists and excludes blank/unknown grouping',()=>{const songs=[{id:'a',album:' Album ',artist:'A'},{id:'b',album:'album',artist:'B'},{id:'c',album:'Other'}];assert.deepEqual(albumArtworkTracks(songs,'ALBUM').map(song=>song.id),['a','b']);assert.deepEqual(albumArtworkTracks(songs,''),[]);assert.deepEqual(albumArtworkTracks([{album:'未知专辑'}],'未知专辑'),[]);});
