// Run against the actual bundled shared detector and production artwork protocol.
// The fixture is a locally generated image: no external assets or network access.
const {app,BrowserWindow,protocol}=require('electron');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {artworkScheme,artworkResponse}=require('../../../Shared/DesktopServices/artwork-protocol.cjs');
app.setPath('userData',path.join(path.resolve(process.argv[2]),'profile'));
protocol.registerSchemesAsPrivileged([artworkScheme]);
app.on('window-all-closed',()=>{});
const timeout=setTimeout(()=>{console.error('Artwork inference test timed out');app.exit(1);},60000);
app.whenReady().then(async()=>{let window;try{
 const dir=path.resolve(process.argv[2]),assets=path.join(dir,'assets');
 const entry=fs.readdirSync(assets).find(name=>/^artworkSubjectDetector-.*\.js$/.test(name));
 if(!entry)throw Error('Missing detector bundle');
 fs.writeFileSync(path.join(dir,'test.html'),`<!doctype html><meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; img-src 'self' minivoice-art: data:; connect-src 'self'"><title>Offline artwork test</title>`);
 const svg='<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600"><rect width="800" height="600" fill="white"/><text x="45" y="300" font-family="sans-serif" font-size="128" font-weight="bold" fill="black">MUSIC</text></svg>';
 protocol.handle('minivoice-art',()=>artworkResponse(new Response(svg,{headers:{'Content-Type':'image/svg+xml'}})));
 window=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true}});
 await window.loadFile(path.join(dir,'test.html'));
 const prepared=await window.webContents.executeJavaScript(`import('./assets/${entry}').then(async m=>{const source='minivoice-art://detail/fixture',identity='synthetic-cover-v1';const stored=await m.precomputeArtworkSubjects({source,identity});return {stored,boxes:await m.analyzeArtworkSubjects(source,{identity})};})`);
 if(!prepared.stored)throw Error('Background precomputation did not persist');const result=prepared.boxes;
 if(!Array.isArray(result)||!result.some(box=>box.text))throw Error('Synthetic title was not detected: '+JSON.stringify(result));
 window.destroy();window=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true}});await window.loadFile(path.join(dir,'test.html'));
 const cached=await window.webContents.executeJavaScript(`globalThis.Image=class{constructor(){throw Error('Unexpected image decode')}};globalThis.Worker=class{constructor(){throw Error('Unexpected model execution')}};import('./assets/${entry}').then(m=>m.analyzeArtworkSubjects('minivoice-art://detail/fixture',{identity:'synthetic-cover-v1'}))`);
 assert.deepEqual(cached,result,'Persistent result was not reused');
 const cleared=await window.webContents.executeJavaScript(`import('./assets/${entry}').then(async m=>{await m.clearArtworkAnalysis();try{await m.analyzeArtworkSubjects('minivoice-art://detail/fixture',{identity:'synthetic-cover-v1'});return false;}catch{return true;}})`);
 assert.equal(cleared,true,'Cleared cache must not return the old result');
 window.destroy();window=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true}});await window.loadFile(path.join(dir,'test.html'));
 const unavailable=await window.webContents.executeJavaScript(`Object.defineProperty(globalThis,'indexedDB',{value:undefined});import('./assets/${entry}').then(async m=>{const source='minivoice-art://detail/fixture',identity='no-storage';return {indexed:await m.precomputeArtworkSubjects({source,identity}),boxes:await m.analyzeArtworkSubjects(source,{identity})};})`);
 assert.equal(unavailable.indexed,false,'Background indexing must stop without durable storage');assert.ok(unavailable.boxes.some(box=>box.text),'Focused detection must still work without storage');
 console.log('PASS models, cross-window cache reuse, clear, and no-storage focused fallback');
 clearTimeout(timeout);app.exit(0);
 }catch(error){console.error(error);clearTimeout(timeout);app.exit(1);}});
