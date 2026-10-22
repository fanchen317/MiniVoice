import {test} from 'node:test';
import assert from 'node:assert/strict';
import {sliderValue,sliderAt,sliderKey} from '../src/components/sliderModel.js';
test('slider hit testing clamps outside the track and honors fractional steps',()=>{
 assert.equal(sliderAt(-200,100,400,0,1000,100),0);assert.equal(sliderAt(900,100,400,0,1000,100),1000);assert.equal(sliderAt(300,100,400,0,1000,100),500);
 assert.equal(sliderValue(.3,0,1,.1),.3);assert.equal(sliderValue(1000,0,999,100),999);assert.equal(sliderValue(NaN,60,120,.1),60);
});
test('slider keys share bounded values with touch and pointer dragging',()=>{
 assert.equal(sliderKey('ArrowUp',.99,0,1,.01),1);assert.equal(sliderKey('ArrowLeft',0,0,1,.01),0);assert.equal(sliderKey('PageUp',60,60,120,.1),66);assert.equal(sliderKey('End',60,60,120,.1),120);assert.equal(sliderKey('Home',120,60,120,.1),60);assert.equal(sliderKey('Escape',0,0,1,.1),null);
});
