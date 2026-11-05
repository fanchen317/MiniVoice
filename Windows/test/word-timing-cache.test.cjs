const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const {wordTimingCache} = require('../../Shared/DesktopServices/word-timing-cache.cjs');

const clone = value => JSON.parse(JSON.stringify(value));
const deferred = () => { let resolve; const promise = new Promise(done => {resolve = done;}); return {promise, resolve}; };
async function fixture(t) {
 const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'mv-word-cache-'));
 t.after(() => fs.rm(directory, {recursive: true, force: true}));
 const audio = path.join(directory, 'synthetic.mp3'); await fs.writeFile(audio, 'synthetic-audio-no-decoder');
 const song = {id:'a', path:audio, title:'测试', duration:6, lyrics:'[00:00]你好\n[00:03]世界', lines:[
  {time:0,text:'你好',translation:'Hello',words:[]},{time:3,text:'世界',translation:'World',words:[]},
 ]};
 const parsed = [{ms:0,text:'你好',words:[{ms:0,endMs:600,text:'你'},{ms:900,endMs:1800,text:'好'}]},
  {ms:3000,text:'世界',words:[{ms:3100,endMs:3700,text:'世'},{ms:4000,endMs:4900,text:'界'}]}];
 const calls = [], statuses = [], songs = new Map([['a',song]]);
 let modelInstalled = true, analysis, onDetail;
 const command = async (action,payload) => {
  calls.push({action,payload:clone(payload)});
  if(action==='desktopSettings')return {lyricsModel:'small',models:[{id:'small',installed:modelInstalled}]};
  if(action==='detail'){await onDetail?.(payload.id);if(!songs.has(payload.id))throw Error('歌曲已移除');return clone(songs.get(payload.id));}
  if(action==='analyzeWordTiming'){if(analysis)return analysis(payload);return {lyrics:JSON.stringify(parsed),timingSource:'audioAligned'};}
  if(action==='sharedCore')return JSON.parse(payload.raw);
  throw Error('Unexpected write/command: '+action);
 };
 const services = [];
 const create = options => {const service=wordTimingCache({directory,command,idleDelayMs:0,onStatus:status=>statuses.push(status),...options});services.push(service);return service;};
 t.after(()=>{for(const service of services)service.stop();});
 const state = extra => ({importing:false,jobs:[],tasks:{},playing:clone(song),selected:null,...extra});
 const prime = async (service,extra) => {service.catalog([...songs.values()]);service.observe(state(extra));await service.whenIdle();};
 const count = action => calls.filter(call=>call.action===action).length;
 return {directory,audio,song,parsed,songs,calls,statuses,create,state,prime,count,
  install: value=>{modelInstalled=value;}, analyze: fn=>{analysis=fn;}, detail: fn=>{onDetail=fn;}};
}

test('scan gate delays background analysis; playback decorates from cache without touching audio or LRC',async t=>{
 const f=await fixture(t),service=f.create();
 await f.prime(service,{importing:true});assert.equal(f.count('analyzeWordTiming'),0);
 service.observe(f.state());await service.whenIdle();assert.equal(f.count('analyzeWordTiming'),1);
 const before=f.state(),output=service.decorate(before);assert.notEqual(output,before);assert.equal(before.playing.lines[0].words.length,0);
 assert.equal(output.playing.lines[0].words[1].start,.9);assert.equal(output.playing.lines[0].translation,'Hello');
 assert.deepEqual(output.playing.wordTiming.quality,{wordCoverage:1,coveredCharacters:4,totalCharacters:4});
 for(let i=0;i<5;i++)service.observe(f.state());await service.whenIdle();assert.equal(f.count('analyzeWordTiming'),1);
 assert.equal(await fs.readFile(f.audio,'utf8'),'synthetic-audio-no-decoder');
 assert.ok(!(await fs.readdir(f.directory)).some(name=>name.endsWith('.lrc')));
 assert.ok(!f.calls.some(call=>['saveMetadata','writeState'].includes(call.action)));
});

test('restart reuses a validated disk cache rather than rerunning inference',async t=>{
 const f=await fixture(t),first=f.create();await f.prime(first);first.stop();
 const second=f.create();await f.prime(second);assert.equal(f.count('analyzeWordTiming'),1);
 assert.equal(second.decorate(f.state()).playing.wordTiming.source,'audioAligned');
 assert.ok(f.statuses.some(status=>status.hits===1));
});

test('native real words are preserved and a complete native timeline skips model work',async t=>{
 const f=await fixture(t);f.song.lines[0].words=[{text:'你好',start:.1,end:1.2}];
 const service=f.create();await f.prime(service);const result=service.decorate(f.state());
 assert.deepEqual(result.playing.lines[0].words,f.song.lines[0].words);
 assert.equal(result.playing.lines[1].words.length,2);
 service.stop();f.song.lines[1].words=[{text:'世界',start:3.1,end:4.8}];
 const native=f.create();await f.prime(native);assert.equal(f.count('analyzeWordTiming'),1);assert.equal(native.decorate(f.state()).playing.wordTiming,undefined);
});

test('audio changes invalidate an in-memory timeline and trigger a fresh scan analysis',async t=>{
 const f=await fixture(t),service=f.create();await f.prime(service);
 await fs.writeFile(f.audio,'replacement-audio-with-different-size');
 const stale=service.decorate(f.state());assert.equal(stale.playing.wordTiming,undefined);
 await service.whenIdle();assert.equal(f.count('analyzeWordTiming'),2);
 assert.equal(service.decorate(f.state()).playing.wordTiming.source,'audioAligned');
});

test('editor invalidation during inference drops stale result and requeues saved lyrics',async t=>{
 const f=await fixture(t),service=f.create(),started=deferred(),release=deferred();let number=0;
 f.analyze(async()=>{number++;if(number===1){started.resolve();await release.promise;}return {lyrics:JSON.stringify(f.parsed),timingSource:'audioAligned'};});
 service.catalog([f.song]);service.observe(f.state());await started.promise;
 f.song.lyrics='[ar:Updated]\n'+f.song.lyrics;service.invalidate('a');release.resolve();await service.whenIdle();
 assert.equal(f.count('analyzeWordTiming'),2);assert.equal(f.statuses.filter(status=>status.phase==='ready').length,1);
 assert.equal(service.decorate(f.state()).playing.wordTiming.source,'audioAligned');
});

test('saved lyric change without explicit invalidate is caught before publication',async t=>{
 const f=await fixture(t),service=f.create();let first=true;
 f.analyze(async()=>{if(first){first=false;f.song.lyrics='[ar:Changed]\n'+f.song.lyrics;}return {lyrics:JSON.stringify(f.parsed),timingSource:'audioAligned'};});
 await f.prime(service);assert.equal(f.count('analyzeWordTiming'),2);assert.equal(f.statuses.filter(status=>status.phase==='ready').length,1);
});

test('library removal while inference runs prevents disk or playback publication',async t=>{
 const f=await fixture(t),service=f.create(),started=deferred(),release=deferred();
 f.analyze(async()=>{started.resolve();await release.promise;return {lyrics:JSON.stringify(f.parsed),timingSource:'audioAligned'};});
 service.catalog([f.song]);service.observe(f.state());await started.promise;service.catalog([]);release.resolve();await service.whenIdle();
 assert.equal(service.decorate(f.state()).playing.wordTiming,undefined);assert.ok(!f.statuses.some(status=>status.phase==='ready'));
});

test('missing model is cooled down; installing model resumes the pending scan',async t=>{
 const f=await fixture(t),service=f.create();f.install(false);await f.prime(service);
 for(let i=0;i<6;i++)service.observe(f.state());await service.whenIdle();assert.equal(f.count('desktopSettings'),1);assert.equal(f.count('analyzeWordTiming'),0);
 f.install(true);service.observe(f.state({tasks:{modelStatus:'下载完成'}}));await service.whenIdle();assert.equal(f.count('analyzeWordTiming'),1);
});

test('manual AI tasks gate background queue and inference failure keeps original line sync',async t=>{
 const f=await fixture(t),service=f.create();await f.prime(service,{jobs:[{id:'manual',finished:false}]});assert.equal(f.count('analyzeWordTiming'),0);
 f.analyze(async()=>{throw Error('model unavailable');});service.observe(f.state());await service.whenIdle();assert.equal(f.count('analyzeWordTiming'),1);
 const source=f.state();assert.equal(service.decorate(source),source);service.catalog([f.song]);service.observe(f.state());await service.whenIdle();assert.equal(f.count('analyzeWordTiming'),1);
});

test('text coverage below threshold is not published as ready and is never called accuracy',async t=>{
 const f=await fixture(t),service=f.create();f.parsed[1].words=[];await f.prime(service);
 const source=f.state();assert.equal(service.decorate(source),source);assert.ok(f.statuses.some(status=>status.phase==='needsReview'&&status.quality.wordCoverage===.5));
 assert.ok(!JSON.stringify(f.statuses).includes('accuracy'));
});

test('missing/zero word endpoints cannot pass the measured timing cache gate',async t=>{
 const f=await fixture(t),service=f.create();f.parsed[0].words[0].endMs=0;delete f.parsed[1].words[1].endMs;
 await f.prime(service);assert.ok(!f.statuses.some(status=>status.phase==='ready'));assert.equal(service.decorate(f.state()).playing.wordTiming,undefined);
});

test('previously measured disk cache plays after restart even when model files were removed',async t=>{
 const f=await fixture(t),first=f.create();await f.prime(first);first.stop();f.install(false);
 const second=f.create();await f.prime(second);assert.equal(f.count('analyzeWordTiming'),1);
 assert.equal(second.decorate(f.state()).playing.wordTiming.source,'audioAligned');
});
