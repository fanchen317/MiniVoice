import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { existsSync } from 'node:fs';
import path from 'node:path';
const executable=process.env.MINIVOICE_ENGINE;

test('Swift engine starts without a SwiftUI window and keeps JSON request/event channels separate',{skip:!executable,timeout:20000},async()=>{
  assert.ok(existsSync(executable));
  const child=spawn(executable,['--desktop-engine'],{env:{...process.env,MINIVOICE_ENGINE_TEST_DOMAIN:`MiniVoice.Test.Engine.${Date.now()}`},stdio:['pipe','pipe','pipe']});
  const messages=[],waiters=new Set();let errors='';child.stderr.on('data',data=>errors+=data);
  createInterface({input:child.stdout}).on('line',line=>{const message=JSON.parse(line);messages.push(message);for(const listener of waiters)listener();});
  function wait(predicate){return new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{waiters.delete(check);reject(new Error(`Engine timeout: ${errors}`));},10000);
    function check(){const found=messages.find(predicate);if(found){clearTimeout(timer);waiters.delete(check);resolve(found);}}
    waiters.add(check);check();
  });}
  const send=(id,action,payload={})=>child.stdin.write(JSON.stringify({id,action,payload})+'\n');
  try{
    const ready=await wait(message=>message.event==='ready');assert.equal(ready.data.protocol,1);
    const state=await wait(message=>message.event==='state');assert.ok(Array.isArray(state.data.folders));
    assert.ok(state.data.doubleClickIntervalMs>0&&state.data.doubleClickIntervalMs<5000);
    assert.equal(state.data.closeBehavior,'background');
    assert.equal(state.data.playbackShortcuts.length,3);
    send('missing-editor','openEditor',{id:'missing'});assert.match((await wait(m=>m.id==='missing-editor')).error,/歌曲已移除/);
    send('style','interfaceStyle',{value:'library'});assert.equal((await wait(m=>m.id==='style')).result,true);
    assert.deepEqual(state.data.sorting.tracks,{field:'added',ascending:false});
    send('sort-artists','sorting',{category:'artists',field:'count',ascending:false});assert.equal((await wait(m=>m.id==='sort-artists')).result,true);
    const sortedState=await wait(m=>m.event==='state'&&m.data.sorting.artists.field==='count');assert.equal(sortedState.data.sorting.albums.field,'name');
    send('tasks-read','tasks',{operation:'read'});assert.equal((await wait(m=>m.id==='tasks-read')).result,true);
    send('sort-invalid','sorting',{category:'tracks',field:'count'});assert.equal((await wait(m=>m.id==='sort-invalid')).result,false);
    send('invalid','notAllowed');assert.match((await wait(m=>m.id==='invalid')).error,/不支持/);
    send('playlist','createPlaylist',{name:'测试歌单'});assert.match((await wait(m=>m.id==='playlist')).result,/^[A-F0-9-]+$/);
    send('appearance','appearance',{value:'dark'});assert.equal((await wait(m=>m.id==='appearance')).result,true);await wait(m=>m.event==='state'&&m.data.appearance==='dark');
    send('lyrics','lyricsPresentation',{style:'kinetic',translation:false});assert.equal((await wait(m=>m.id==='lyrics')).result,true);await wait(m=>m.event==='state'&&m.data.wallLyricsStyle==='kinetic'&&m.data.showLyricsTranslation===false);
    send('invalid-style','lyricsPresentation',{style:'invalid'});await wait(m=>m.id==='invalid-style');
    send('snapshot','snapshot');assert.equal((await wait(m=>m.id==='snapshot')).result,true);
    await wait(m=>m.event==='clock');
    assert.ok(messages.filter(m=>m.event==='catalog').every(m=>m.data.length===0),'Test defaults must not read the real library');
  }finally{child.stdin.end();await new Promise(resolve=>{child.once('exit',resolve);setTimeout(()=>{child.kill();resolve();},1000).unref();});}
});

test('packaged audio backend plays, advances, seeks and pauses a silent fixture with timed lyrics',{skip:!executable,timeout:30000},async()=>{
  const fs=await import('node:fs/promises'),os=await import('node:os');
  const root=await fs.mkdtemp(path.join(os.tmpdir(),'MiniVoice-AudioBridge-'));
  const rate=44100,samples=rate*4,wav=Buffer.alloc(44+samples*2);
  wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(rate,24);wav.writeUInt32LE(rate*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(samples*2,40);
  await fs.writeFile(path.join(root,'Silence.wav'),wav);await fs.mkdir(path.join(root,'lrc'));await fs.writeFile(path.join(root,'lrc','Silence.lrc'),'[00:00.00]<00:00.00>第一<00:00.50>句\n[00:01.00]第二句');
  const child=spawn(executable,['--desktop-engine'],{env:{...process.env,MINIVOICE_ENGINE_TEST_DOMAIN:`MiniVoice.Test.Audio.${Date.now()}`},stdio:['pipe','pipe','pipe']});
  const messages=[],waiters=new Set();let errors='';child.stderr.on('data',data=>errors+=data);
  createInterface({input:child.stdout}).on('line',line=>{messages.push(JSON.parse(line));for(const listener of waiters)listener();});
  function wait(predicate){return new Promise((resolve,reject)=>{const timer=setTimeout(()=>{waiters.delete(check);reject(new Error(`Audio bridge timeout: ${errors}\n${JSON.stringify(messages.slice(-5))}`));},12000);function check(){const found=messages.find(predicate);if(found){clearTimeout(timer);waiters.delete(check);resolve(found);}}waiters.add(check);check();});}
  const send=(id,action,payload={})=>child.stdin.write(JSON.stringify({id,action,payload})+'\n');
  try{
    await wait(m=>m.event==='ready');send('folder','addFolders',{paths:[root]});
    const catalog=await wait(m=>m.event==='catalog'&&m.data.length===1),id=catalog.data[0].id;
    send('favorites','favoriteMany',{ids:[id],value:true});assert.equal((await wait(m=>m.id==='favorites')).result,true);await wait(m=>m.event==='state'&&m.data.favorites.includes(path.join(root,'Silence.wav')));
    send('ordering','orderedTracks',{field:'sourceAdded',ascending:false});assert.deepEqual((await wait(m=>m.id==='ordering')).result,[id]);
    send('batch-playlist','createPlaylist',{name:'批量验证'});const playlist=(await wait(m=>m.id==='batch-playlist')).result;
    send('batch-add','addManyToPlaylist',{ids:[id],playlist});assert.equal((await wait(m=>m.id==='batch-add')).result,1);
    await wait(m=>m.event==='state'&&m.data.playlists.some(p=>p.id===playlist&&p.paths.includes(path.join(root,'Silence.wav'))));
    const removeAt=messages.length;
    send('batch-remove','removeManyFromPlaylist',{ids:[id],playlist});assert.equal((await wait(m=>m.id==='batch-remove')).result,true);
    await wait(m=>messages.indexOf(m)>=removeAt&&m.event==='state'&&m.data.playlists.some(p=>p.id===playlist&&p.paths.length===0));
    send('volume','volume',{value:0});await wait(m=>m.id==='volume');
    send('play','play',{id});await wait(m=>m.id==='play');
    const progress=await wait(m=>m.event==='clock'&&m.data.playing&&m.data.time>.1);assert.ok(progress.data.time<4);
    send('detail','detail',{id});const detail=await wait(m=>m.id==='detail');assert.ok(detail.result.lines.some(line=>line.text==='第一句'));assert.ok(detail.result.lines.some(line=>line.words.length>0));
    send('seek','seek',{time:2});await wait(m=>m.id==='seek');await wait(m=>m.event==='clock'&&m.data.time>=2);
    send('pause','pause');await wait(m=>m.id==='pause');await wait(m=>m.event==='clock'&&!m.data.playing&&m.data.time>=2);
    const resumeAt=messages.length;
    send('wall-resume','play',{id,preservePosition:true});await wait(m=>m.id==='wall-resume');
    const resumed=await wait(m=>messages.indexOf(m)>=resumeAt&&m.event==='clock'&&m.data.playing);
    assert.ok(resumed.data.time>=2,'Double-clicking a paused wall card must resume its position');
    const repeatAt=messages.length;
    send('wall-repeat','play',{id,preservePosition:true});await wait(m=>m.id==='wall-repeat');
    const repeated=await wait(m=>messages.indexOf(m)>=repeatAt&&m.event==='clock'&&m.data.playing);
    assert.ok(repeated.data.time>=resumed.data.time,'Double-clicking the playing card must not restart it');
    send('panel-editor','openEditor',{id});assert.equal((await wait(m=>m.id==='panel-editor')).result,true);
    send('panel-settings','openSettings');assert.equal((await wait(m=>m.id==='panel-settings')).result,true);
    const panelAt=messages.length;
    send('panel-snapshot','snapshot');assert.equal((await wait(m=>m.id==='panel-snapshot')).result,true);
    await wait(m=>messages.indexOf(m)>=panelAt&&m.event==='clock');
    assert.equal(child.exitCode,null,'Opening native editor/settings must keep the audio service alive');
    send('delete-fixture','deleteTracks',{ids:[id],trash:false});assert.equal((await wait(m=>m.id==='delete-fixture')).result,true);
    assert.ok(existsSync(path.join(root,'Silence.wav')),'Removing from the library must preserve the source fixture');
    send('removeFolder','removeFolder',{path:root});await wait(m=>m.id==='removeFolder');
  }finally{child.stdin.end();await new Promise(resolve=>{child.once('exit',resolve);setTimeout(()=>{child.kill();resolve();},1000).unref();});await fs.rm(root,{recursive:true,force:true});}
});

test('bundled engine starts when its preferences domain equals its own bundle ID',{skip:!executable,timeout:20000},async()=>{
  const fs=await import('node:fs/promises'),os=await import('node:os'),{spawnSync}=await import('node:child_process');
  const root=await fs.mkdtemp(path.join(os.tmpdir(),'MiniVoice-BundleBridge-')),bundle=path.join(root,'Backend.app'),domain=`MiniVoice.Test.Bundle.${Date.now()}`;
  const binary=path.join(bundle,'Contents/MacOS/MiniVoice');
  await fs.mkdir(path.dirname(binary),{recursive:true});await fs.copyFile(executable,binary);await fs.chmod(binary,0o755);
  await fs.writeFile(path.join(bundle,'Contents/Info.plist'),`<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>${domain}</string><key>CFBundleExecutable</key><string>MiniVoice</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>`);
  const resources=path.resolve(path.dirname(executable),'../Resources/MiniVoice_MiniVoice.bundle');
  if(existsSync(resources))await fs.cp(resources,path.join(bundle,'Contents/Resources/MiniVoice_MiniVoice.bundle'),{recursive:true});
  assert.equal(spawnSync('codesign',['--force','--sign','-',bundle]).status,0);
  const child=spawn(binary,['--desktop-engine'],{env:{...process.env,MINIVOICE_ENGINE_TEST_DOMAIN:domain},stdio:['pipe','pipe','pipe']});let errors='';child.stderr.on('data',data=>errors+=data);
  try{await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error(`Bundled startup timed out: ${errors}`)),10000);createInterface({input:child.stdout}).on('line',line=>{const message=JSON.parse(line);if(message.event==='ready'){clearTimeout(timer);resolve();}});child.once('exit',code=>{clearTimeout(timer);reject(new Error(`Bundled engine exited ${code}: ${errors}`));});});}
  finally{child.stdin.end();await new Promise(resolve=>{child.once('exit',resolve);setTimeout(()=>{child.kill();resolve();},1000).unref();});await fs.rm(root,{recursive:true,force:true});}
});
