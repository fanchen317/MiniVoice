import test from 'node:test';
import assert from 'node:assert/strict';
import {mobileWallViewport} from '../src/wallLayout.js';
test('iOS focus centers in flat, lower table and left book regions above expanded dock',()=>{
 for(const [width,height,regionRight] of [[1100,800,0],[800,535,0],[1100,800,535]]){
  for(const safe of [{top:0,bottom:0,left:0,right:0},{top:24,bottom:21,left:48,right:0}]){
   const v=mobileWallViewport(width,height,safe,{centered:true,regionRight});
   assert.equal(v.x,(safe.left+(regionRight||width-safe.right))/2);
   assert.ok(v.x-v.side/2>=safe.left);assert.ok(v.x+v.side/2<=(regionRight||width-safe.right));
   assert.ok(v.y-v.side/2>=safe.top+80);assert.ok(v.y+v.side/2<=height-safe.bottom-114);
  }
 }
});

test('Duo localized focus excludes status column and preserves the book boundary',()=>{
 for(const regionRight of [511,320]){
  const v=mobileWallViewport(669,951,{}, {centered:true,regionLeft:14,regionRight});
  assert.equal(v.x,(14+regionRight)/2);
  assert.ok(v.x-v.side/2>=14);assert.ok(v.x+v.side/2<=regionRight);
 }
});
