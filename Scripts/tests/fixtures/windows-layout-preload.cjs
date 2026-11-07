const {contextBridge,ipcRenderer}=require('electron');let listener;
contextBridge.exposeInMainWorld('miniVoice',{platform:'windows',subscribe:callback=>{listener=callback;return()=>{};},command:(action,payload)=>ipcRenderer.invoke('fixture:command',{action,payload})});
ipcRenderer.on('fixture:state',(_,data)=>listener?.({event:'state',data}));

ipcRenderer.on('fixture:catalog',(_,data)=>listener?.({event:'catalog',data}));
