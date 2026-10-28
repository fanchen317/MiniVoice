import test from 'node:test';
import assert from 'node:assert/strict';
import {dockOverlapsSettings} from '../src/components/dockCollision.js';
const rect=(left,top,width,height)=>({left,top,width,height});
test('centered tablet dock leaves bottom-right settings at rest',()=>{
 assert.equal(dockOverlapsSettings(rect(152,1035,440,84),rect(674,1063,56,56)),false);
});
test('phone bar lifts settings but collapsed circle leaves it alone',()=>{
 const tool=rect(332,804,56,56);
 assert.equal(dockOverlapsSettings(rect(14,776,374,84),tool),true);
 assert.equal(dockOverlapsSettings(rect(14,804,56,56),tool),false);
});
test('collision uses the resting tool position and reserves the exact gap',()=>{
 const dock=rect(20,200,300,84);
 assert.equal(dockOverlapsSettings(dock,rect(331,220,56,56)),true);
 assert.equal(dockOverlapsSettings(dock,rect(332,220,56,56)),false);
 assert.equal(dockOverlapsSettings(dock,rect(100,80,56,56)),false);
 assert.equal(dockOverlapsSettings(rect(0,0,0,0),rect(0,0,56,56)),false);
});
