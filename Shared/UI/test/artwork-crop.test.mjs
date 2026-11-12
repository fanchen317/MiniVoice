import {test} from 'node:test';
import assert from 'node:assert/strict';
import {subjectCrop,warmArtworkSubjects,subscribeArtworkSubjects} from '../src/components/artworkFocus.js';
test('viewport matrix produces bounded crop positions for faces, groups and text',()=>{const scenes=[[{x:.65,y:.2,width:.15,height:.2,face:1}],[{x:.1,y:.2,width:.15,height:.2,face:1},{x:.7,y:.2,width:.15,height:.2,face:1}],[{x:.1,y:.7,width:.8,height:.12,face:0,text:1}]];for(const regions of scenes)for(const image of [.5,1,2])for(const viewport of [9/21,9/16,1,4/3,16/9,21/9,32/9]){const crop=subjectCrop(regions,image,viewport);assert.ok(Number.isFinite(crop.x)&&crop.x>=0&&crop.x<=1);assert.ok(Number.isFinite(crop.y)&&crop.y>=0&&crop.y<=1);}assert.equal(subjectCrop(scenes[0],0,1),null);});
test('subject completion invalidates current presentation and unsubscribe stops updates',async()=>{let count=0;const stop=subscribeArtworkSubjects('test://async-cover',()=>count++);await warmArtworkSubjects('test://async-cover',async()=>[{x:.1,y:.1,width:.2,height:.2,face:1}]);assert.equal(count,1);stop();await warmArtworkSubjects('test://async-cover',async()=>[]);assert.equal(count,1);});
test('composition keeps an entire feasible face group including hair margins',async()=>{const {compositionCrop}=await import('../src/components/artworkComposition.js');const faces=[{x:.15,y:.2,width:.12,height:.15,face:1,confidence:.9},{x:.65,y:.23,width:.1,height:.13,face:1,confidence:.85}];const p=compositionCrop(faces,1,21/9),height=9/21,top=p.y*(1-height);for(const f of faces){assert.ok(top<=f.y-f.height*.65+1e-8);assert.ok(top+height>=f.y+f.height*1.2-1e-8);}});
test('texture cannot pull a feasible face out of its protected crop',async()=>{const {artworkFocus}=await import('../src/components/artworkFocus.js');const data=new Uint8ClampedArray(32*32*4);for(let y=0;y<32;y++)for(let x=22;x<32;x++){const i=(y*32+x)*4;data[i]=(x+y)%2?255:0;}const face={x:.08,y:.2,width:.12,height:.18,face:1};const p=artworkFocus(data,32,32,{imageAspect:2,viewportAspect:.6,regions:[face]}),left=p.x*(1-.3);assert.ok(left<=face.x-face.width*.18+1e-8);assert.ok(left+.3>=face.x+face.width*1.18-1e-8);});
test('late subject results cannot move visible artwork in the current orientation',async()=>{
 const {stableArtworkFocus}=await import('../src/components/artworkFocus.js');
 const image={naturalWidth:1200,naturalHeight:800,dataset:{},style:{},closest:()=>null},decisions=new Map();
 const options={key:'test://session-lock',coordinateSpace:'original',viewport:{width:390,height:844}};
 const before=stableArtworkFocus(image,options,decisions);
 await warmArtworkSubjects(options.key,async()=>[{x:.02,y:.1,width:.1,height:.2,face:1,confidence:1}]);
 const after=stableArtworkFocus(image,options,decisions);
 assert.deepEqual(after,before);
 const rotated=stableArtworkFocus(image,{...options,viewport:{width:844,height:390}},decisions);
 assert.ok(Number.isFinite(rotated.y));
 assert.equal(decisions.size,2);
 stableArtworkFocus(image,options,decisions);
 assert.equal(image.style.objectPosition,`${after.x*100}% ${after.y*100}%`);
});
test('same-space higher resolution artwork keeps the displayed composition',async()=>{
 const {stableArtworkFocus}=await import('../src/components/artworkFocus.js');
 const decisions=new Map(),key='test://resolution-stability';
 const image={naturalWidth:600,naturalHeight:400,dataset:{},style:{},closest:()=>null};
 const options={key,coordinateSpace:'original',viewport:{width:390,height:844}};
 const first=stableArtworkFocus(image,options,decisions);
 await warmArtworkSubjects(key,async()=>[{x:.8,y:.2,width:.1,height:.2,face:true}]);
 image.naturalWidth=1800;image.naturalHeight=1200;
 assert.deepEqual(stableArtworkFocus(image,options,decisions),first);
 assert.equal(decisions.size,1);
 // A trimmed preview occupies a different coordinate system.
 stableArtworkFocus(image,{...options,coordinateSpace:'preview'},decisions);
 assert.equal(decisions.size,2);
});
test('first presentation can join in-flight detection before locking its crop',async()=>{
 const {waitArtworkSubjects,stableArtworkFocus}=await import('../src/components/artworkFocus.js');
 const key='test://first-frame-analysis';let complete;
 const detection=warmArtworkSubjects(key,()=>new Promise(resolve=>{complete=resolve;}));
 await Promise.resolve();let ready=false;
 const presentation=waitArtworkSubjects(key).then(()=>{ready=true;});await Promise.resolve();assert.equal(ready,false);
 complete([{x:.7,y:.2,width:.12,height:.2,face:true}]);await detection;await presentation;
 const image={naturalWidth:1000,naturalHeight:1000,dataset:{},style:{},closest:()=>null};
 const focus=stableArtworkFocus(image,{key,coordinateSpace:'original',viewport:{width:400,height:1000}},new Map());
 const left=focus.x*.6;assert.ok(Math.abs((.76-left)/.4-.5)<1e-6);
});
test('clearing subject results prevents an old pending analysis from repopulating memory',async()=>{
 const {clearArtworkSubjects}=await import('../src/components/artworkFocus.js');
 const key='test://subject-clear-race';let finish,calls=0;
 const old=warmArtworkSubjects(key,()=>{calls++;return new Promise(resolve=>{finish=resolve;});});
 await Promise.resolve();clearArtworkSubjects();finish([{x:.1,y:.2,width:.1,height:.2,face:1}]);await old;
 const current=await warmArtworkSubjects(key,async()=>{calls++;return [{x:.6,y:.2,width:.1,height:.2,face:1}];});
 assert.equal(calls,2);assert.equal(current[0].x,.6);
});
