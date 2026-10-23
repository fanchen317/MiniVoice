import test from 'node:test';
import assert from 'node:assert/strict';
import identity from '../electron/build-identity.cjs';
test('debug has a separate name, Chromium profile and single-instance lock root',()=>{
 const release=identity.desktopIdentity('release','/tmp/AppSupport');
 const debug=identity.desktopIdentity('debug','/tmp/AppSupport');
 assert.equal(release.name,'MiniVoice');assert.equal(debug.name,'MiniVoice-debug');
 assert.equal(release.userData,'/tmp/AppSupport/minivoice-desktop');
 assert.equal(debug.userData,'/tmp/AppSupport/minivoice-desktop-debug');
 assert.notEqual(release.userData,debug.userData);
});
