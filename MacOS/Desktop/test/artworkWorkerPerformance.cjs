// Runs the bundled production detector using an intentionally slow worker, so
// responsiveness is checked without a machine-specific inference time limit.
const {app,BrowserWindow,protocol}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {artworkScheme,artworkResponse}=require('../../../Shared/DesktopServices/artwork-protocol.cjs');
protocol.registerSchemesAsPrivileged([artworkScheme]);
const timeout=setTimeout(()=>{console.error('Artwork worker test timed out');app.exit(1);},60000);
app.whenReady().then(async()=>{let window;try{
 const dir=path.resolve(process.argv[2]),assets=path.join(dir,'assets'),files=fs.readdirSync(assets);
 const entry=files.find(name=>/^artworkSubjectDetector-.*\.js$/.test(name));
 const worker=files.find(name=>/^artworkSubjectWorker-.*\.js$/.test(name));
 assert.ok(entry,'Detector entry was bundled');assert.ok(worker,'Dedicated worker was bundled');
 // Slow each request inside the worker, never in the renderer. Loading and
 // inference still use the real runtime/models and return real detection boxes.
 const workerPath=path.join(assets,worker),original=fs.readFileSync(workerPath,'utf8');
 fs.writeFileSync(workerPath,"self.addEventListener('message',()=>{const end=performance.now()+350;while(performance.now()<end){};});\n"+original);
 fs.writeFileSync(path.join(dir,'test.html'),`<!doctype html><meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; img-src 'self' minivoice-art: data:; connect-src 'self'; worker-src 'self'"><title>Artwork worker responsiveness</title>`);
 const svg='<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600"><rect width="800" height="600" fill="white"/><text x="45" y="300" font-family="sans-serif" font-size="128" font-weight="bold" fill="black">MUSIC</text></svg>';
 protocol.handle('minivoice-art',()=>artworkResponse(new Response(svg,{headers:{'Content-Type':'image/svg+xml'}})));
 window=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false}});
 await window.loadFile(path.join(dir,'test.html'));
 const outcome=await window.webContents.executeJavaScript(`(async()=>{
  const NativeWorker=globalThis.Worker;let workers=0,messages=0;
  globalThis.Worker=class extends NativeWorker{constructor(...args){super(...args);workers++;}postMessage(...args){messages++;return super.postMessage(...args);}};
  const tasks=[],observer=new PerformanceObserver(list=>tasks.push(...list.getEntries().map(x=>x.duration)));
  observer.observe({entryTypes:['longtask']});
  const detector=await import('./assets/${entry}');
  async function sample(){let frames=0,active=true;const tick=()=>{if(active){frames++;requestAnimationFrame(tick);}};requestAnimationFrame(tick);
   const start=performance.now(),boxes=await detector.analyzeArtworkSubjects('minivoice-art://detail/fixture');const elapsed=performance.now()-start;active=false;
   return {boxes,frames,elapsed};}
  const cold=await sample(),warm=await sample();observer.disconnect();
  return {cold,warm,workers,messages,tasks};
 })()`);
 assert.ok(outcome.workers>=1,'The detector must start a real Worker');
 assert.ok(outcome.messages>=2,'Cold and warm analyses must be sent to the Worker');
 for(const [name,run] of [['cold',outcome.cold],['warm',outcome.warm]]){
  assert.ok(run.boxes.some(box=>box.text),`${name}: synthetic text was detected`);
  assert.ok(run.frames>=3,`${name}: renderer kept painting during intentionally slow worker: ${JSON.stringify(run)}`);
 }
 const cold=outcome.cold.boxes.find(box=>box.text),warm=outcome.warm.boxes.find(box=>box.text);
 for(const key of ['x','y','width','height'])assert.ok(Math.abs(cold[key]-warm[key])<.005,`Cold/warm text geometry differs for ${key}`);
 console.log('PASS actual artwork worker handles cold and warm models without stopping renderer',JSON.stringify({workers:outcome.workers,messages:outcome.messages,coldMs:outcome.cold.elapsed,warmMs:outcome.warm.elapsed,coldFrames:outcome.cold.frames,warmFrames:outcome.warm.frames,longtasks:outcome.tasks}));
 clearTimeout(timeout);window.destroy();app.exit(0);
 }catch(error){console.error(error);clearTimeout(timeout);window?.destroy();app.exit(1);}});
