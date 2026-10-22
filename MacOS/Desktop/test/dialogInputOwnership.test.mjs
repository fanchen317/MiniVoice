import {test} from 'node:test';
import assert from 'node:assert/strict';
import {textInputTabNavigation} from '../src/textInputNavigation.js';
test('desktop form shortcut yields Tab to shared dialogs instead of overriding action-button focus',()=>{
 const previous=globalThis.document;let prevented=false,queried=false;
 globalThis.document={querySelector:()=>({role:'dialog'}),querySelectorAll:()=>{queried=true;return [];}};
 try{textInputTabNavigation({preventDefault:()=>{prevented=true;}});assert.equal(prevented,false);assert.equal(queried,false);}finally{if(previous===undefined)delete globalThis.document;else globalThis.document=previous;}
});
