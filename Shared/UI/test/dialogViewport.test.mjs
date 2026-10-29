import test from 'node:test';
import assert from 'node:assert/strict';
import {dialogViewport} from '../src/components/dialogViewport.js';
test('dialog follows iOS visual keyboard and viewport panning without double subtraction on Android',()=>{
 assert.deepEqual(dialogViewport(874,{height:590,offsetTop:0}),{top:0,height:590,keyboard:true});
 assert.deepEqual(dialogViewport(874,{height:420,offsetTop:120}),{top:120,height:420,keyboard:true});
 assert.deepEqual(dialogViewport(590,{height:590,offsetTop:0}),{top:0,height:590,keyboard:false});
 assert.deepEqual(dialogViewport(914,{height:914,offsetTop:0},360),{top:0,height:554,keyboard:true});
 assert.deepEqual(dialogViewport(554,{height:554,offsetTop:0},0),{top:0,height:554,keyboard:false});
 assert.deepEqual(dialogViewport(914,{height:554,offsetTop:0},360),{top:0,height:554,keyboard:true});
 assert.deepEqual(dialogViewport(874,null),{top:0,height:874,keyboard:false});
 assert.deepEqual(dialogViewport(874,{height:874,offsetTop:-2}),{top:0,height:874,keyboard:false});
 assert.deepEqual(dialogViewport(402,{height:1000,offsetTop:0}),{top:0,height:402,keyboard:false});
});
