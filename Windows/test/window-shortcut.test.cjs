const {test}=require('node:test'),assert=require('node:assert/strict'),{windowShortcut,accelerator,shortcutLabel}=require('../electron/window-shortcut.cjs');
test('failed replacement keeps previously registered shortcut',()=>{const calls=[],hotkey=windowShortcut({globalShortcut:{register:key=>{calls.push(['register',key]);return key!=='Control+B';},unregister:key=>calls.push(['unregister',key])},toggle:()=>{}});assert.equal(hotkey.register({keyCode:0,modifiers:1<<18}),'Control+A');assert.throws(()=>hotkey.register({keyCode:11,modifiers:1<<18}),/占用/);assert.ok(!calls.some(row=>row[0]==='unregister'));hotkey.dispose();assert.deepEqual(calls.at(-1),['unregister','Control+A']);assert.throws(()=>accelerator({keyCode:0,modifiers:0}),/Ctrl/);});
test('global shortcuts accept recorder digits, punctuation, function keys and keypad keys',()=>{
 for(const [keyCode,key] of [[18,'1'],[27,'-'],[122,'F1'],[69,'numadd'],[91,'num8'],[117,'Delete']])assert.equal(accelerator({keyCode,modifiers:1<<18}),`Control+${key}`);
 assert.throws(()=>accelerator({keyCode:76,modifiers:1<<18}),/不支持/);
});
test('shortcut labels describe saved playback and window bindings',()=>{
 assert.equal(shortcutLabel({keyCode:49,modifiers:0}),'Space');
 assert.equal(shortcutLabel({keyCode:123,modifiers:1<<18}),'Ctrl + ←');
 assert.equal(shortcutLabel({keyCode:122,modifiers:(1<<20)|(1<<17)}),'Windows + Shift + F1');
 assert.equal(shortcutLabel({keyCode:69,modifiers:1<<19}),'Alt + 小键盘 +');
 assert.equal(shortcutLabel({keyCode:999,modifiers:0}),'');
});
