import test from 'node:test';
import assert from 'node:assert/strict';
import {sheetDragDismiss} from '../src/components/sheetDragModel.js';
test('sheet drag distinguishes short/held pulls from deliberate distance and downward flicks',()=>{
 assert.equal(sheetDragDismiss(20,0,600),false);
 assert.equal(sheetDragDismiss(40,0,600),false);
 assert.equal(sheetDragDismiss(40,.8,600),true);
 assert.equal(sheetDragDismiss(120,0,600),true);
 assert.equal(sheetDragDismiss(10,2,600),false);
 assert.equal(sheetDragDismiss(60,-1,600),false);
});
