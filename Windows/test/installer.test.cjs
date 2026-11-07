const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os');
test('uninstaller manifest deletes only packaged files, never recursive user directories',async()=>{const dir=await fs.mkdtemp(path.join(os.tmpdir(),'mv-install-'));try{await fs.mkdir(path.join(dir,'resources'));await fs.writeFile(path.join(dir,'resources','app.asar'),'synthetic');await fs.writeFile(path.join(dir,'MiniVoice.exe'),'synthetic');const {uninstallManifest}=await import('../generate-uninstall.mjs');const text=await uninstallManifest(dir);assert.match(text,/Delete "\$INSTDIR\\resources\\app.asar"/);assert.match(text,/RMDir "\$INSTDIR\\resources"/);assert.ok(!text.includes('/r'));}finally{await fs.rm(dir,{recursive:true,force:true});}});
test('cross packaging rejects Mac binaries and accepts only x64 PE resource executables',async()=>{const root=await fs.mkdtemp(path.join(os.tmpdir(),'mv-pe-'));try{const {validateResources}=await import('../prepare-cross-resources.mjs');await fs.mkdir(path.join(root,'LyricsAI','models'),{recursive:true});await fs.mkdir(path.join(root,'LyricsAI','LICENSES'));await fs.writeFile(path.join(root,'LICENSE.txt'),'synthetic');await fs.writeFile(path.join(root,'LyricsAI','models','small.pt'),'synthetic');const pe=Buffer.alloc(128);pe.write('MZ');pe.writeUInt32LE(64,60);pe.write('PE\0\0',64,'binary');pe.writeUInt16LE(0x8664,68);for(const name of ['minivoice-core.exe','ffmpeg.exe','ffprobe.exe','LyricsAI/python.exe'])await fs.writeFile(path.join(root,name),pe);await validateResources(root);const digest=require('node:crypto').createHash('sha256').update(pe).digest('hex');await fs.writeFile(path.join(root,'resource-manifest.json'),JSON.stringify({platform:'win32-x64',files:{'minivoice-core.exe':digest}}));await validateResources(root);await fs.writeFile(path.join(root,'minivoice-core.exe'),Buffer.concat([pe,Buffer.from('tampered')]));await assert.rejects(validateResources(root),/校验失败/);await fs.writeFile(path.join(root,'resource-manifest.json'),JSON.stringify({platform:'win32-x64',files:{'../outside':digest}}));await assert.rejects(validateResources(root),/越界/);await fs.rm(path.join(root,'resource-manifest.json'));await fs.writeFile(path.join(root,'minivoice-core.exe'),'not PE');await assert.rejects(validateResources(root),/Windows/);}finally{await fs.rm(root,{recursive:true,force:true});}});

test('resource staging replaces stale files and keeps prior output when preparation fails',async()=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'mv-stage-'));
 try{
  const source=path.join(dir,'source'),target=path.join(dir,'resources'),worker=path.join(dir,'worker.py');
  await fs.mkdir(source);await fs.mkdir(target);await fs.writeFile(path.join(target,'obsolete.lib'),'stale');await fs.writeFile(path.join(source,'new.exe'),'synthetic');await fs.writeFile(worker,'synthetic worker');
  const {stageResources}=await import('../prepare-cross-resources.mjs');await stageResources(source,target,worker);
  await assert.rejects(fs.access(path.join(target,'obsolete.lib')));assert.equal(await fs.readFile(path.join(target,'new.exe'),'utf8'),'synthetic');
  await assert.rejects(stageResources(source,target,path.join(dir,'missing-worker')));assert.equal(await fs.readFile(path.join(target,'new.exe'),'utf8'),'synthetic');
 }finally{await fs.rm(dir,{recursive:true,force:true});}
});

test('upgrade manifest hashes installed payload and excludes its own previous metadata',async()=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'mv-upgrade-manifest-'));
 try{
  await fs.mkdir(path.join(dir,'resources'));await fs.writeFile(path.join(dir,'resources','app.asar'),'synthetic app');await fs.writeFile(path.join(dir,'.minivoice-install-files.json'),'old metadata');
  const {installationManifest}=await import('../generate-uninstall.mjs');const manifest=await installationManifest(dir);
  assert.equal(manifest.schema,1);assert.deepEqual(Object.keys(manifest.files),['resources/app.asar']);assert.equal(manifest.files['resources/app.asar'],require('node:crypto').createHash('sha256').update('synthetic app').digest('hex'));
  const {uninstallManifest}=await import('../generate-uninstall.mjs');assert.match(await uninstallManifest(dir),/Delete "\$INSTDIR\\\.minivoice-install-files.json"/);
 }finally{await fs.rm(dir,{recursive:true,force:true});}
});
