import test from 'node:test';
import assert from 'node:assert/strict';
import {wallSettingsPlacement} from '../src/components/wallSettingsPlacement.js';
test('wall settings keeps portrait width and spans search to settings',()=>{
 const portrait=wallSettingsPlacement({width:440,height:956,padding:{top:71,right:12,bottom:46,left:12},anchor:{right:426,bottom:908},search:{top:69}});
 const landscape=wallSettingsPlacement({width:956,height:440,padding:{top:12,right:12,bottom:33,left:71},anchor:{right:942,bottom:405},search:{top:10}});
 assert.equal(portrait.width,416);assert.equal(landscape.width,portrait.width);
 assert.equal(landscape.height,395);assert.equal(landscape.maxHeight,395);assert.equal(portrait.height,839);assert.equal(landscape.right,14);assert.equal(landscape.bottom,35);
});
test('opposite cutout, tablet gap, missing anchor and keyboard stay bounded',()=>{
 const opposite=wallSettingsPlacement({width:956,height:440,padding:{top:12,right:71,bottom:33,left:12},anchor:{right:883,bottom:405}});
 assert.equal(opposite.width,416);assert.equal(opposite.right,73);
 assert.equal(wallSettingsPlacement({width:1194,height:834,gap:24}).width,560);
 const keyboard=wallSettingsPlacement({width:390,height:244,padding:{top:59,bottom:12,left:12,right:12},anchor:{right:376,bottom:780}});
 assert.ok(keyboard.height>0&&keyboard.bottom>=12&&keyboard.height+keyboard.bottom<=244-59);
 const offscreen=wallSettingsPlacement({width:390,height:120,padding:{top:59,bottom:12,left:12,right:12},anchor:{right:376,bottom:-20},search:{top:80}});assert.equal(offscreen.height,1);assert.ok(offscreen.height+offscreen.bottom<=120-59);
});
