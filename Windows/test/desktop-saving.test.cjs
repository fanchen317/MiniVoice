const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs/promises'),os=require('node:os'),path=require('node:path'),id3=require('node-id3');
const {desktopHost}=require('../electron/desktop.cjs');
const media=require('../electron/media-writer.cjs'),metadata=require('../electron/metadata.cjs'),{writeMP3}=require('../electron/tag-writer.cjs');
const {writeLyricsSidecar}=require('../electron/lyrics-sidecar.cjs');

test('sidecar writes reject concurrent changes and keep the other writer\'s data',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'mv-lrc-race-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const file=path.join(root,'song.mp3'),sidecar=path.join(root,'song.lrc');await fs.writeFile(sidecar,'before');
 await assert.rejects(writeLyricsSidecar(file,'new','',{beforeCommit:()=>fs.writeFile(sidecar,'changed externally')}),/保存期间发生变化/);
 assert.equal(await fs.readFile(sidecar,'utf8'),'changed externally');
 await fs.rm(sidecar);await assert.rejects(writeLyricsSidecar(file,'new','',{beforeCommit:()=>fs.writeFile(sidecar,'created externally')}),/保存期间发生变化/);
 assert.equal(await fs.readFile(sidecar,'utf8'),'created externally');
 assert.equal((await fs.readdir(root)).some(name=>name.endsWith('.tmp')),false);
});

test('saving tags and LRC writes both, backs up existing data and preserves audio',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'mv-both-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const file=path.join(root,'song.mp3'),sidecar=path.join(root,'song.lrc'),audio=Buffer.from('synthetic-audio');
 const original=id3.write({title:'Old',artist:'Artist',album:'Album'},audio);await fs.writeFile(file,original);await fs.writeFile(sidecar,'old lrc');
 const originalWrite=media.write,originalRead=metadata.readMetadata;
 media.write=(file,patch,options)=>writeMP3(file,patch,options);metadata.readMetadata=async file=>{const tags=id3.read(await fs.readFile(file));return {title:tags.title,artist:tags.artist,album:tags.album,rawLyrics:tags.unsynchronisedLyrics?.text,duration:10000};};
 t.after(()=>{media.write=originalWrite;metadata.readMetadata=originalRead;});
 const song={id:'a',path:file,title:'Old',artist:'Artist',album:'Album',duration:10000},state={songs:[song],folders:[await fs.realpath(root)],favorites:[],recent:[],playlists:[],current:'',position:0,mode:1,preferences:{wordTimingCache:'disabled'}};
 const window={webContents:{send(){}},isDestroyed:()=>false};
 const host=desktopHost({app:{getPath:()=>root,once(){}},BrowserWindow:{getAllWindows:()=>[window]},getState:()=>state,getWindow:()=>window,getPlaying:()=>false,save:async()=>{},lyrics:async()=>fs.readFile(sidecar,'utf8'),coreRequest:async()=>[],request:async()=>true});
 await host.command('saveMetadata',{id:'a',title:'New',artist:'Artist',album:'Album',lyrics:'[00:01]hello',translation:'世界',destination:'both'});
 const expected='[translation:'+Buffer.from('世界').toString('base64')+']\n[00:01]hello';
 assert.equal(await fs.readFile(sidecar,'utf8'),expected);const written=await fs.readFile(file);assert.equal(id3.read(written).unsynchronisedLyrics.text,expected);assert.equal(id3.read(written).title,'New');assert.deepEqual(id3.removeTagsFromBuffer(written),audio);
 const files=await fs.readdir(root);const backup=files.find(name=>name.startsWith('song.lrc.minivoice-backup-'));assert.ok(backup);assert.equal(await fs.readFile(path.join(root,backup),'utf8'),'old lrc');assert.equal(song.sidecarOverride,true);
});

test('reports a partial save when tag write succeeded but LRC cannot be replaced',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'mv-both-fail-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const file=path.join(root,'song.mp3');await fs.writeFile(file,id3.write({title:'Old'},Buffer.from('audio')));await fs.mkdir(path.join(root,'song.lrc'));
 const originalWrite=media.write,originalRead=metadata.readMetadata;
 media.write=(file,patch,options)=>writeMP3(file,patch,options);metadata.readMetadata=async file=>({title:id3.read(await fs.readFile(file)).title,duration:10000});
 t.after(()=>{media.write=originalWrite;metadata.readMetadata=originalRead;});
 const song={id:'a',path:file,title:'Old',artist:'Artist',album:'Album',duration:10000},state={songs:[song],folders:[await fs.realpath(root)],favorites:[],recent:[],playlists:[],current:'',position:0,mode:1,preferences:{wordTimingCache:'disabled'}};let saves=0;
 const window={webContents:{send(){}},isDestroyed:()=>false};
 const host=desktopHost({app:{getPath:()=>root,once(){}},BrowserWindow:{getAllWindows:()=>[window]},getState:()=>state,getWindow:()=>window,getPlaying:()=>false,save:async()=>{saves++;},lyrics:async()=>'',coreRequest:async()=>[],request:async()=>true});
 await assert.rejects(host.command('saveMetadata',{id:'a',title:'New',artist:'Artist',album:'Album',lyrics:'hello',destination:'both'}),/音频标签已保存，但 LRC 保存失败/);
 assert.equal(id3.read(await fs.readFile(file)).title,'New');assert.ok((await fs.stat(path.join(root,'song.lrc'))).isDirectory());assert.equal(song.title,'New');assert.ok(saves>0);
});
