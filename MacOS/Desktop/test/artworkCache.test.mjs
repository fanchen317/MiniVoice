import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createRequire} from 'node:module';
import {artwork} from '../src/artworkUrl.js';
const {cachedArtworkFile}=createRequire(import.meta.url)('../electron/artwork-files.cjs');
const key='a'.repeat(64);

test('ordinary covers use a surviving detail image after small caches are evicted',t=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'minivoice-artwork-'));
  t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
  const detail=path.join(root,'Artwork','Detail',key);
  fs.mkdirSync(path.dirname(detail),{recursive:true});fs.writeFileSync(detail,'detail image');
  assert.equal(cachedArtworkFile(root,artwork({artworkKey:key})),detail);
  const browse=path.join(root,'Artwork','Browse',key);
  fs.mkdirSync(path.dirname(browse),{recursive:true});fs.writeFileSync(browse,'browse image');
  assert.equal(cachedArtworkFile(root,artwork({artworkKey:key})),browse);
  assert.equal(cachedArtworkFile(root,artwork({artworkKey:key},true)),detail);
});
test('repaired cover gets a fresh request without changing the source content key',()=>{
  const before=artwork({artworkKey:key,artworkRevision:1}),after=artwork({artworkKey:key,artworkRevision:2});
  assert.notEqual(before,after);
  assert.equal(new URL(before).pathname,new URL(after).pathname);
  assert.equal(artwork({}), '');
});
test('missing caches and invalid protocol paths never escape the artwork root',()=>{
  assert.equal(cachedArtworkFile(null,artwork({artworkKey:key})),null);
  for(const url of [`minivoice-art://cover/${key}/extra`,`minivoice-art://cover/invalid`,`minivoice-art://other/${key}`,`file:///${key}`])assert.equal(cachedArtworkFile('/no-cache',url),null);
});
test('detail prefers original source pixels while lists keep their small cached image',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'minivoice-source-art-'));t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
 for(const kind of ['Original','Detail','Browse']){const file=path.join(root,'Artwork',kind,key);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,kind);}
 assert.equal(cachedArtworkFile(root,artwork({artworkKey:key},true)),path.join(root,'Artwork','Original',key));
 assert.equal(cachedArtworkFile(root,artwork({artworkKey:key})),path.join(root,'Artwork','Browse',key));
 assert.match(artwork({artworkKey:key},true),/source=original-v1/);
});
