const {contextBridge,ipcRenderer}=require('electron');let listener;
const platform=process.argv.find(value=>value.startsWith('--parity-platform='))?.split('=')[1]||'windows';
contextBridge.exposeInMainWorld('miniVoice',{platform,subscribe:callback=>{listener=callback;return()=>{};},command:(action,payload)=>ipcRenderer.invoke('parity:command',{action,payload})});
for(const event of ['catalog','state','clock'])ipcRenderer.on('parity:'+event,(_,data)=>listener?.({event,data}));
