import test from 'node:test';
import assert from 'node:assert/strict';
import {posterArtworkMotion} from '../src/motion.js';
test('counter-transform covers every clip edge with off-center subjects, including intermediate frames',()=>{
 for(const from of [{width:150,height:480},{width:640,height:130}])for(const to of [{width:400,height:400},{width:950,height:420}])for(const ratio of [.6,1,2])for(const focus of [{x:0,y:0},{x:1,y:1},{x:.3,y:.8}]){
  const result=posterArtworkMotion(from,to,ratio,p=>p,53,focus,{x:.5,y:.5});
  result.frames.forEach(frame=>{const [tx,ty,ax,ay]=frame.transform.match(/-?\d+(?:\.\d+)?(?:e[+-]?\d+)?/gi).map(Number),p=frame.offset,sx=(from.width+(to.width-from.width)*p)/to.width,sy=(from.height+(to.height-from.height)*p)/to.height;
   assert.ok(tx*sx<=1e-6&&ty*sy<=1e-6);assert.ok((tx+result.width*ax)*sx>=to.width*sx-1e-6);assert.ok((ty+result.height*ay)*sy>=to.height*sy-1e-6);
  });
 }
});
