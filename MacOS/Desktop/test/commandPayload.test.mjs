import test from 'node:test';
import assert from 'node:assert/strict';
import limits from '../electron/command-payload.cjs';
test('image metadata can cross the ordinary command limit without widening other commands',()=>{
 const payload={artwork:'data:image/png;base64,'+'A'.repeat(5*1024*1024)};
 assert.equal(limits.validCommandPayload('saveMetadata',payload),true);
 assert.equal(limits.validCommandPayload('appearance',payload),false);
 assert.equal(limits.validCommandPayload('saveMetadata',{artwork:'A'.repeat(33*1024*1024)}),false);
 for(const value of [null,[],true,'image'])assert.equal(limits.validCommandPayload('saveMetadata',value),false);
});
