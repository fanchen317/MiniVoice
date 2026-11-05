import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import service from '../../DesktopServices/automatic-enrichment.cjs';
test('download writes sidecars, defers audio until switch and resumes journal after restart',async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'minivoice-enrich-'));
 try{
 const file=path.join(root,'song.mp3');await fs.writeFile(file,'synthetic audio');
 const song={id:'test',path:file,title:'Song',artist:'Artist',album:'Album',duration:120,lyrics:'',canWriteTags:true};
 const saves=[],errors=[];
 const command=async(action,payload)=>{if(action==='detail')return {...song};if(action==='saveMetadata'){saves.push(payload);if(payload.destination==='sidecar')song.lyrics=payload.lyrics;return true;}throw Error(action);};
 const options={directory:path.join(root,'profile'),command,onError:e=>errors.push(e),search:async()=>[{...song,lyrics:'[00:01.00]Hello'}],artwork:{search:async()=>[{token:'cover',album:'Album',artist:'Artist'}],download:async()=>'data:image/png;base64,aW1hZ2U='},validateImage:()=>true};
 const state={folders:[root],playing:{...song},isPlaying:true};
 await service.automaticEnrichment(options).observe(state);
 assert.equal(await fs.readFile(path.join(root,'song.lrc'),'utf8'),'[00:01.00]Hello');
 assert.equal(await fs.readFile(path.join(root,'song.png'),'utf8'),'image');
 assert.equal(saves.filter(p=>p.destination==='both').length,0);
 assert.equal(await fs.readFile(file,'utf8'),'synthetic audio');
 await service.automaticEnrichment(options).observe({...state,playing:null,isPlaying:false});
 assert.equal(saves.filter(p=>p.destination==='both').length,1);
 assert.equal(saves.at(-1).automatic,true);assert.deepEqual(errors,[]);
 assert.deepEqual(JSON.parse(await fs.readFile(path.join(root,'profile','automatic-enrichment.json'),'utf8')),[]);
 }finally{await fs.rm(root,{recursive:true,force:true});}
});
test('unauthorized source is never searched or written',async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'minivoice-denied-'));try{const file=path.join(root,'song.mp3');await fs.writeFile(file,'audio');let searched=false;const errors=[];
 await service.automaticEnrichment({directory:path.join(root,'profile'),command:async()=>{},search:async()=>{searched=true;return [];},validateImage:()=>true,onError:e=>errors.push(e)}).observe({folders:[],isPlaying:true,playing:{id:'x',path:file}});
 assert.equal(searched,false);assert.equal(errors.length,1);
 }finally{await fs.rm(root,{recursive:true,force:true});}
});
test('pending writes reject changed audio and preserve existing lyrics',async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'minivoice-changed-'));try{
 const file=path.join(root,'song.mp3'),directory=path.join(root,'profile');await fs.writeFile(file,'audio');await fs.mkdir(directory);const stat=await fs.stat(file);
 const job={id:'x',path:file,size:stat.size,modified:stat.mtimeMs,lyrics:'[00:01]downloaded'};
 let saves=0;const errors=[];const song={id:'x',path:file,title:'Song',artist:'Artist',lyrics:'[00:01]manual',canWriteTags:true};
 const options={directory,command:async action=>{if(action==='detail')return song;saves++;},validateImage:()=>true,onError:e=>errors.push(e)};
 await fs.writeFile(path.join(directory,'automatic-enrichment.json'),JSON.stringify([job]));
 await service.automaticEnrichment(options).observe({folders:[root],playing:null,isPlaying:false});assert.equal(saves,0);assert.match(errors[0],/歌词已被修改/);
 await fs.writeFile(file,'changed audio');await fs.writeFile(path.join(directory,'automatic-enrichment.json'),JSON.stringify([job]));errors.length=0;
 await service.automaticEnrichment(options).observe({folders:[root],playing:null,isPlaying:false});assert.equal(saves,0);assert.match(errors[0],/音频文件已变化/);
 }finally{await fs.rm(root,{recursive:true,force:true});}
});
