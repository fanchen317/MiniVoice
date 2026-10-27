import test from 'node:test';
import assert from 'node:assert/strict';
test('locally presented search errors still reject without opening a second global dialog',async()=>{
 globalThis.window={miniVoice:{subscribe(){},command:async()=>{throw Error('search unavailable');}}};
 const {command,signals}=await import('../src/store.js');let reports=0;signals.addEventListener('error',()=>reports++);
 await assert.rejects(command('artworkSearch'),/search unavailable/);assert.equal(reports,1);
 await assert.rejects(command('artworkSearch',{}, {reportError:false}),/search unavailable/);assert.equal(reports,1);
 delete globalThis.window;
});
