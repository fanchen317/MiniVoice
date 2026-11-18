const {test}=require('node:test'),assert=require('node:assert/strict'),{visibleBounds,mainWindowBounds}=require('../electron/window-placement.cjs');
test('disconnected monitor falls back inside available screen',()=>{assert.deepEqual(visibleBounds({x:3000,y:1200,width:720,height:160},[{x:0,y:0,width:1280,height:720}],{x:0,y:0,width:720,height:160}),{x:560,y:560,width:720,height:160});});
test('negative-coordinate monitor restores unchanged and oversized windows are clamped',()=>{const bounds={x:-1000,y:100,width:600,height:180},screens=[{x:0,y:0,width:1920,height:1080},{x:-1280,y:0,width:1280,height:720}];assert.deepEqual(visibleBounds(bounds,screens,bounds),bounds);assert.deepEqual(visibleBounds({x:0,y:0,width:3000,height:2000},[screens[0]],bounds),{x:0,y:0,width:1920,height:1080});});
test('main window stays accessible after a monitor disconnect or resolution change',()=>{
 const screens=[{x:0,y:0,width:1280,height:720}];
 assert.deepEqual(mainWindowBounds({x:1279,y:600,width:1200,height:800},screens),{x:80,y:0,width:1200,height:720});
 assert.deepEqual(mainWindowBounds({x:3200,y:200,width:900,height:600},screens),{x:380,y:120,width:900,height:600});
 assert.deepEqual(mainWindowBounds({x:NaN,y:0,width:900,height:600},screens),{x:40,y:0,width:1200,height:720});
});
