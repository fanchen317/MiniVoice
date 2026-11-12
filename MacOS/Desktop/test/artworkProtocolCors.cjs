// Run with Electron: uses the production protocol settings and response wrapper,
// and proves the renderer can read the cross-origin artwork's pixels.
const {app,BrowserWindow,protocol}=require('electron');
const http=require('node:http');
const {artworkScheme,artworkResponse}=require('../../../Shared/DesktopServices/artwork-protocol.cjs');
protocol.registerSchemesAsPrivileged([artworkScheme]);
let server,window;
const timeout=setTimeout(()=>{console.error('Artwork CORS test timed out');app.exit(1);},15000);
app.whenReady().then(async()=>{try{
 server=http.createServer((req,res)=>{res.setHeader('Content-Type','text/html');res.end('<!doctype html><title>Artwork CORS</title>');});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 protocol.handle('minivoice-art',()=>artworkResponse(new Response('<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"><rect width="4" height="4" fill="red"/></svg>',{headers:{'Content-Type':'image/svg+xml'}})));
 window=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false}});await window.loadURL(`http://127.0.0.1:${server.address().port}/`);
 const pixel=await window.webContents.executeJavaScript(`new Promise((resolve,reject)=>{const image=new Image();image.crossOrigin='anonymous';image.onerror=()=>reject(Error('load failed'));image.onload=()=>{try{const canvas=document.createElement('canvas');canvas.width=canvas.height=4;const ctx=canvas.getContext('2d');ctx.drawImage(image,0,0);resolve(Array.from(ctx.getImageData(0,0,1,1).data));}catch(error){reject(error)}};image.src='minivoice-art://detail/test';})`);
 if(pixel.join(',')!=='255,0,0,255')throw Error(`Unexpected artwork pixel: ${pixel}`);
 console.log('PASS production artwork protocol supports cross-origin canvas pixels');clearTimeout(timeout);server.close();app.exit(0);
 }catch(error){console.error(error);clearTimeout(timeout);server?.close();app.exit(1);}});
