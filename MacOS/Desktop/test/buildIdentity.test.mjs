import test from 'node:test';
import assert from 'node:assert/strict';
import identity from '../electron/build-identity.cjs';
test('production keeps the established Chromium profile and name',()=>{assert.deepEqual(identity.desktopIdentity('/tmp/AppSupport'),{name:'MiniVoice',userData:'/tmp/AppSupport/minivoice-desktop'});});
