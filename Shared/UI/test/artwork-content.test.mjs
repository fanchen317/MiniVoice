import {test} from 'node:test';
import assert from 'node:assert/strict';
import {compositionContent,compositionCrop} from '../src/components/artworkComposition.js';
const face=x=>({x,y:.25,width:.15,height:.2,face:true,confidence:.9});
test('content distinguishes portraits, pairs, groups, typography and unknown scenery',()=>{
 for(const [regions,kind] of [[[face(.2)],'portrait'],[[face(.1),face(.7)],'pair'],[[face(.1),face(.4),face(.7)],'group'],[[{x:.1,y:.2,width:.8,height:.1,text:true}],'typography'],[[],'scenery-or-abstract']])assert.equal(compositionContent(regions).kind,kind);
 assert.equal(compositionContent([face(.2),{x:.1,y:.1,width:.4,height:.8,person:true}]).count,1);
});
test('narrow pair crop shares unavoidable loss instead of removing a member',()=>{
 const regions=[{...face(.1),width:.3},{...face(.6),width:.3}];
 const p=compositionCrop(regions,1,.6),left=p.x*.4;
 assert.ok(left<.4&&left+.6>.6);
});
test('body-only portrait preserves the body when it fits',()=>{
 const body={x:.65,y:.1,width:.18,height:.8,person:true};
 const p=compositionCrop([body],1,.4),left=p.x*.6;
 assert.ok(left<=body.x&&left+.4>=body.x+body.width);
});
test('mixed face and body detections retain people without a detected face',()=>{
 const regions=[face(.1),{x:.65,y:.1,width:.2,height:.8,person:true}];
 const content=compositionContent(regions);
 assert.equal(content.kind,'pair');assert.equal(content.primary.length,2);
});
test('large title is primary while small credits remain secondary',()=>{
 const title={x:.2,y:.7,width:.6,height:.12,text:true};
 const credits=Array.from({length:8},(_,i)=>({x:.1,y:.02+i*.025,width:.25,height:.015,text:true}));
 const content=compositionContent([title,...credits]);assert.equal(content.primary.length,1);
 const p=compositionCrop([title,...credits],1,2),top=p.y*.5;
 assert.ok(top<=title.y&&top+.5>=title.y+title.height);
});
test('null detector entries are ignored',()=>{
 assert.equal(compositionContent([null,undefined,face(.2)]).kind,'portrait');
});
test('wallpaper portrait centres a feasible face rather than the source canvas',()=>{
 for(const x of [.18,.65]){
  const subject={x,y:.25,width:.12,height:.15,face:true};
  const p=compositionCrop([subject],1,.4),left=p.x*.6;
  assert.ok(Math.abs((subject.x+.06-left)/.4-.5)<1e-6);
 }
});
test('wide wallpaper centres the face vertically when headroom fits',()=>{
 const subject={x:.4,y:.48,width:.12,height:.12,face:true};
 const p=compositionCrop([subject],1,2),top=p.y*.5;
 assert.ok(Math.abs((subject.y+.06-top)/.5-.5)<1e-6);
});
test('pair wallpaper centres the group without favouring a more confident member',()=>{
 const subjects=[{...face(.15),width:.12,confidence:.75},{...face(.65),width:.12,confidence:1}];
 const p=compositionCrop(subjects,1,.8),left=p.x*.2;
 assert.ok(Math.abs(((.15+.77)/2-left)/.8-.5)<1e-6);
});
test('source edge clamps centring without exposing blank wallpaper',()=>{
 const p=compositionCrop([{...face(.02),width:.1}],1,.4);
 assert.equal(p.x,0);
});

test('face and the enclosing figure are both retained when they fit the crop',()=>{
 const face={x:.41,y:.17,width:.09,height:.12,face:true,confidence:.9};
 const body={x:.36,y:.13,width:.43,height:.72,person:true,confidence:.9};
 const p=compositionCrop([face,body],1,.55),left=p.x*.45;
 assert.ok(left<=body.x+1e-8,'body left edge remains visible');
 assert.ok(left+.55>=body.x+body.width-1e-8,'body right edge remains visible');
 assert.ok(left<=face.x-face.width*.18+1e-8,'face retains left padding');
});

test('when the detected figure cannot fit, framing still protects the face',()=>{
 const face={x:.24,y:.15,width:.1,height:.12,face:true,confidence:.9};
 const body={x:.18,y:.1,width:.65,height:.8,person:true,confidence:.9};
 const p=compositionCrop([face,body],1,.4),left=p.x*.6;
 assert.ok(left<=face.x-face.width*.18+1e-8);
 assert.ok(left+.4>=face.x+face.width*1.18-1e-8);
});

test('a fully fitting group of faces and bodies is retained together',()=>{
 const people=[{x:.1,y:.1,width:.3,height:.8,person:true,confidence:.9},{x:.6,y:.1,width:.3,height:.8,person:true,confidence:.9}];
 const faces=[{x:.16,y:.2,width:.08,height:.1,face:true,confidence:.9},{x:.67,y:.2,width:.08,height:.1,face:true,confidence:.9}];
 const p=compositionCrop([...people,...faces],1,.9),left=p.x*.1;
 for(const body of people){assert.ok(left<=body.x+1e-8);assert.ok(left+.9>=body.x+body.width-1e-8);}
});

test('a body that exactly fits is retained even when extra body padding cannot fit',()=>{
 const face={x:.22,y:.14,width:.08,height:.1,face:true,confidence:.9};
 const body={x:.18,y:.1,width:.4,height:.75,person:true,confidence:.9};
 const p=compositionCrop([face,body],1,.4),left=p.x*.6;
 assert.ok(Math.abs(left-body.x)<1e-7,'do not sacrifice visible body for extra margin');
 assert.ok(left+.4>=body.x+body.width-1e-7);
});

test('a wide title remains visible when thin vertical credits are tallest',()=>{
 const title={x:.05,y:.1,width:.25,height:.06,text:true,confidence:.5};
 const credit={x:.92,y:.5,width:.005,height:.4,text:true,confidence:1};
 const energy=new Float32Array(96*96).fill(1);
 for(let y=0;y<96;y++)for(let x=70;x<96;x++)energy[y*96+x]=1000;
 const content=compositionContent([title,credit]);assert.equal(content.primary.length,1);assert.equal(content.primary[0].core.x,title.x);
 const focus=compositionCrop([title,credit],1,.3,{energy,width:96,height:96}),left=focus.x*.7;
 assert.ok(left<=title.x+1e-8,'title left edge stays visible');
 assert.ok(left+.3>=title.x+title.width-1e-8,'title right edge stays visible');
});
